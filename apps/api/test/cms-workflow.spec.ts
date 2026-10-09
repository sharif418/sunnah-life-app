// ─────────────────────────────────────────────────────────────────────────────
// cms-workflow.spec.ts (2026-10-09) — content goes draft → scholar review →
// publish; nothing reaches the apps unreviewed.
//   • who: content roles are set by full_admin only; a plain member without
//     one is refused; an editor drafts but cannot approve; a reviewer
//     approves — never their own draft
//   • the old direct write (PUT /api/admin/content/:pack) is gone
//   • validation: a dua without its source cannot be submitted (the issue is
//     listed next to the item)
//   • publish: the public GET /api/content/:pack serves the new version; the
//     first edit kept the original as version 1 — rollback restores it
// Runs against TEMP CONTENT_DIR / STORAGE_DIR (the repo packs stay untouched).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { promises as fs, readFileSync } from "fs";
import os from "os";
import path from "path";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { contentDir } from "src/shared/levels";
import { invalidatePackCache } from "src/shared/quran";

const ADMIN = "01000000001"; // full_admin
const INVIGILATOR = "01000000002"; // will be the reviewer (আলেম)
const MEMBER = "01000000008"; // plain user — will be the editor
const OTHER = "01000000010"; // plain user, no content role

const ORIGINAL_CONTENT_DIR = contentDir();
const origEnvContentDir = process.env.CONTENT_DIR;
const origEnvStorageDir = process.env.STORAGE_DIR;
let tmpDir: string;
let tmpStorage: string;
let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http().post("/api/auth/otp/verify").send({ phone, code: otpRes.body.devCode }).expect(200);
  return res.body.accessToken as string;
}
const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

async function idOf(phone: string): Promise<string> {
  const u = await rls.system((tx) => tx.user.findUnique({ where: { phone } }));
  return u!.id;
}

let admin: string;
let editor: string;
let reviewer: string;
let other: string;

beforeAll(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "sl-cms-wf-"));
  for (const f of ["names99.json", "duas.json"]) {
    await fs.copyFile(path.join(ORIGINAL_CONTENT_DIR, f), path.join(tmpDir, f));
  }
  process.env.CONTENT_DIR = tmpDir;
  tmpStorage = await fs.mkdtemp(path.join(os.tmpdir(), "sl-cms-storage-"));
  process.env.STORAGE_DIR = tmpStorage;
  invalidatePackCache();

  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());

  // a clean slate for the packs this spec edits
  await rls.system((tx) => tx.contentRevision.deleteMany({ where: { pack: { in: ["names99", "duas"] } } }));
  await rls.system((tx) =>
    tx.user.updateMany({ where: { phone: { in: [MEMBER, INVIGILATOR, OTHER] } }, data: { contentRole: null } })
  );
  admin = await signIn(ADMIN);
  editor = await signIn(MEMBER);
  reviewer = await signIn(INVIGILATOR);
  other = await signIn(OTHER);
});

afterAll(async () => {
  await rls.system((tx) => tx.contentRevision.deleteMany({ where: { pack: { in: ["names99", "duas"] } } }));
  await rls.system((tx) =>
    tx.user.updateMany({ where: { phone: { in: [MEMBER, INVIGILATOR, OTHER] } }, data: { contentRole: null } })
  );
  await app.close();
  if (origEnvContentDir === undefined) delete process.env.CONTENT_DIR;
  else process.env.CONTENT_DIR = origEnvContentDir;
  if (origEnvStorageDir === undefined) delete process.env.STORAGE_DIR;
  else process.env.STORAGE_DIR = origEnvStorageDir;
  invalidatePackCache();
  await fs.rm(tmpDir, { recursive: true, force: true });
  await fs.rm(tmpStorage, { recursive: true, force: true });
});

describe("who may do what", () => {
  it("unauthenticated 401; a member without a content role 403", async () => {
    await http().get("/api/admin/cms").expect(401);
    await http().get("/api/admin/cms").set(auth(other)).expect(403);
  });

  it("only full_admin sets content roles", async () => {
    const memberId = await idOf(MEMBER);
    await http().patch(`/api/admin/cms/editors/${memberId}`).set(auth(other)).send({ contentRole: "editor" }).expect(403);
    await http().patch(`/api/admin/cms/editors/${memberId}`).set(auth(admin)).send({ contentRole: "editor" }).expect(200);
    const invId = await idOf(INVIGILATOR);
    await http().patch(`/api/admin/cms/editors/${invId}`).set(auth(admin)).send({ contentRole: "reviewer" }).expect(200);
    // tokens carry no role — the next request reads it fresh
    const res = await http().get("/api/admin/cms").set(auth(editor)).expect(200);
    expect(res.body.canReview).toBe(false);
    expect(res.body.packs.map((p: { pack: string }) => p.pack)).toEqual(expect.arrayContaining(["adhkar", "names99"]));
  });

  it("a member cannot grant themself a content role (DB column guard)", async () => {
    const memberId = await idOf(MEMBER);
    await expect(
      rls.run({ id: memberId, role: "user", gender: "M", usrahId: null } as never, (tx) =>
        tx.user.update({ where: { id: memberId }, data: { contentRole: "reviewer" } })
      )
    ).rejects.toThrow();
  });

  it("the old direct write is gone", async () => {
    await http().put("/api/admin/content/faq").set(auth(admin)).send({ items: [{ q: "x", a: "y" }] }).expect(404);
  });
});

describe("draft → review → publish", () => {
  let original: { names: { id: number; meaningBn: string }[] };

  it("the editor saves a draft; the original is kept as version 1", async () => {
    original = (await http().get("/api/content/names99").expect(200)).body.data;
    const edited = JSON.parse(JSON.stringify(original));
    edited.names[0].meaningBn = "পরীক্ষার অর্থ — সম্পাদিত";
    const res = await http().put("/api/admin/cms/names99/draft").set(auth(editor)).send({ data: edited, note: "অর্থ ঠিক করা" }).expect(200);
    expect(res.body.issues).toEqual([]);
    expect(res.body.version).toBe(2);
    const pack = (await http().get("/api/admin/cms/names99").set(auth(editor)).expect(200)).body;
    expect(pack.history[0]).toMatchObject({ version: 1, status: "published" });
    expect(pack.working).toMatchObject({ version: 2, status: "draft" });
    // not live yet
    const live = (await http().get("/api/content/names99").expect(200)).body.data;
    expect(live.names[0].meaningBn).toBe(original.names[0].meaningBn);
  });

  it("submitted: locked for editing, the editor cannot approve", async () => {
    await http().post("/api/admin/cms/names99/submit").set(auth(editor)).expect(201);
    await http().put("/api/admin/cms/names99/draft").set(auth(editor)).send({ data: original }).expect(409);
    await http().post("/api/admin/cms/names99/review").set(auth(editor)).send({ decision: "approve" }).expect(403);
  });

  it("a rejection needs a reason, and returns the draft to the editor", async () => {
    await http().post("/api/admin/cms/names99/review").set(auth(reviewer)).send({ decision: "reject" }).expect(400);
    await http()
      .post("/api/admin/cms/names99/review")
      .set(auth(reviewer))
      .send({ decision: "reject", note: "অর্থটি আরও স্পষ্ট করুন" })
      .expect(201);
    const pack = (await http().get("/api/admin/cms/names99").set(auth(editor)).expect(200)).body;
    expect(pack.working).toMatchObject({ status: "rejected", reviewNote: "অর্থটি আরও স্পষ্ট করুন" });
    // the editor fixes it (autosaves without a note): the change note and the
    // scholar's note both survive
    await http().put("/api/admin/cms/names99/draft").set(auth(editor)).send({ data: pack.working.data }).expect(200);
    await http().put("/api/admin/cms/names99/draft").set(auth(editor)).send({ data: pack.working.data }).expect(200);
    const again = (await http().get("/api/admin/cms/names99").set(auth(editor)).expect(200)).body;
    expect(again.working).toMatchObject({ status: "draft", note: "অর্থ ঠিক করা", reviewNote: "অর্থটি আরও স্পষ্ট করুন" });
  });

  it("the reviewer approves → the apps get it", async () => {
    await http().post("/api/admin/cms/names99/submit").set(auth(editor)).expect(201);
    await http().post("/api/admin/cms/names99/review").set(auth(reviewer)).send({ decision: "approve" }).expect(201);
    invalidatePackCache();
    const live = (await http().get("/api/content/names99").expect(200)).body.data;
    expect(live.names[0].meaningBn).toBe("পরীক্ষার অর্থ — সম্পাদিত");
    const file = path.join(tmpStorage, "content-overrides", "names99.json");
    expect(JSON.parse(await fs.readFile(file, "utf8")).names[0].meaningBn).toBe("পরীক্ষার অর্থ — সম্পাদিত");
  });

  it("nobody approves their own draft — not even full_admin", async () => {
    const edited = JSON.parse(JSON.stringify(original));
    edited.names[1].meaningBn = "অ্যাডমিনের সম্পাদনা";
    await http().put("/api/admin/cms/names99/draft").set(auth(admin)).send({ data: edited }).expect(200);
    await http().post("/api/admin/cms/names99/submit").set(auth(admin)).expect(201);
    await http().post("/api/admin/cms/names99/review").set(auth(admin)).send({ decision: "approve" }).expect(403);
    await http().post("/api/admin/cms/names99/withdraw").set(auth(admin)).expect(201);
    await http().delete("/api/admin/cms/names99/draft").set(auth(admin)).expect(200);
  });

  it("rollback restores the original (version 1)", async () => {
    const pack = (await http().get("/api/admin/cms/names99").set(auth(reviewer)).expect(200)).body;
    const v1 = pack.history.find((h: { version: number }) => h.version === 1);
    await http().post("/api/admin/cms/names99/rollback").set(auth(editor)).send({ revisionId: v1.id }).expect(403);
    await http().post("/api/admin/cms/names99/rollback").set(auth(reviewer)).send({ revisionId: v1.id }).expect(201);
    invalidatePackCache();
    const live = (await http().get("/api/content/names99").expect(200)).body.data;
    expect(live.names[0].meaningBn).toBe(original.names[0].meaningBn);
  });
});

describe("validation", () => {
  it("a dua without its source cannot go to review", async () => {
    const duas = (await http().get("/api/content/duas").expect(200)).body.data;
    duas.items[2].reference = "";
    const saved = await http().put("/api/admin/cms/duas/draft").set(auth(editor)).send({ data: duas }).expect(200);
    expect(saved.body.issues).toEqual([expect.objectContaining({ path: "items[2].reference" })]);
    const res = await http().post("/api/admin/cms/duas/submit").set(auth(editor)).expect(400);
    expect(res.body.issues).toEqual([expect.objectContaining({ path: "items[2].reference" })]);
    await http().delete("/api/admin/cms/duas/draft").set(auth(editor)).expect(200);
  });

  it("the admin's live copy of the rules matches the API's", async () => {
    const body = (f: string) => {
      const s = readFileSync(f, "utf8");
      return s.slice(s.indexOf("export interface PackIssue {")).replace(/\r\n/g, "\n");
    };
    const api = body(path.join(__dirname, "..", "src", "cms", "cms.validation.ts"));
    const admin = body(path.join(__dirname, "..", "..", "admin", "lib", "content-validation.ts"));
    expect(admin).toBe(api);
  });

  it("every bundled pack passes as it is", async () => {
    const { validatePack } = await import("src/cms/cms.validation");
    const { PACK_KEYS, loadPack } = await import("src/shared/quran");
    process.env.CONTENT_DIR = ORIGINAL_CONTENT_DIR;
    invalidatePackCache();
    for (const key of PACK_KEYS) {
      const data = await loadPack(key);
      expect({ key, issues: validatePack(key, data) }).toEqual({ key, issues: [] });
    }
    process.env.CONTENT_DIR = tmpDir;
    invalidatePackCache();
  });
});
