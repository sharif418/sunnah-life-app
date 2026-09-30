// ─────────────────────────────────────────────────────────────────────────────
// content-pack-admin.spec.ts (W4h) — PUT /api/admin/content/:pack (full_admin):
//   • roles: unauth 401; plain member + usrah_head + invigilator → 403
//   • the narrow allowlist: non-CMS packs (adhkar/quran packs) → 404
//   • validation: array body → 400; object without a non-empty array → 400;
//     over the size cap → 400
//   • a valid write: atomic tmp+rename (no .admin-tmp residue), audit row
//     content_pack_update with bytes + itemCount, and the PUBLIC read
//     (GET /api/content/faq) serves the edited pack immediately (cache bust)
// The spec runs against a TEMP CONTENT_DIR (copies of the real packs) and
// restores process.env.CONTENT_DIR in afterAll — the repo packs are untouched
// (the byte-identical mobile-asset test in content-packs.spec depends on them).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { promises as fs } from "fs";
import os from "os";
import path from "path";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { contentDir } from "src/shared/levels";
import { invalidatePackCache } from "src/shared/quran";

const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin
const HEAD = "01000000003"; // মাওলানা ইউসুফ — usrah_head
const INVIGILATOR = "01000000002"; // হাফেজ যাকারিয়া — invigilator
const MEMBER = "01000000008"; // সাইফুল ইসলাম — plain user

const ORIGINAL_CONTENT_DIR = contentDir();
const origEnvContentDir = process.env.CONTENT_DIR;
let tmpDir: string;

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

beforeAll(async () => {
  // temp content dir seeded with copies of the real CMS packs
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "sl-cms-"));
  await fs.copyFile(
    path.join(ORIGINAL_CONTENT_DIR, "faq.json"),
    path.join(tmpDir, "faq.json")
  );
  process.env.CONTENT_DIR = tmpDir;

  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  await app.close();
  if (origEnvContentDir === undefined) delete process.env.CONTENT_DIR;
  else process.env.CONTENT_DIR = origEnvContentDir;
  invalidatePackCache();
  await fs.rm(tmpDir, { recursive: true, force: true });
});

describe("roles + allowlist", () => {
  it("unauthenticated → 401", async () => {
    await http().put("/api/admin/content/faq").send({ items: [] }).expect(401);
  });

  it.each([
    ["plain member", MEMBER],
    ["usrah_head", HEAD],
    ["invigilator", INVIGILATOR],
  ])("%s → 403", async (_name, phone) => {
    const token = await signIn(phone);
    await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${token}`)
      .send({ items: [] })
      .expect(403);
  });

  it("non-CMS packs are refused (404) — the write list is narrow", async () => {
    const token = await signIn(ADMIN);
    await http()
      .put("/api/admin/content/adhkar")
      .set("Authorization", `Bearer ${token}`)
      .send({ items: [{ x: 1 }] })
      .expect(404);
    await http()
      .put("/api/admin/content/quran-uthmani")
      .set("Authorization", `Bearer ${token}`)
      .send({ items: [{ x: 1 }] })
      .expect(404);
  });
});

describe("validation", () => {
  let adminToken: string;

  it("array body → 400 (packs are objects)", async () => {
    adminToken = await signIn(ADMIN);
    await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${adminToken}`)
      .send([{ q: "x" }])
      .expect(400);
  });

  it("object without a non-empty array → 400", async () => {
    await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ items: [] })
      .expect(400);
    await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ title: "শুধু লেখা" })
      .expect(400);
  });

  it("over the size cap → 400 (the cap sits below the express body limit)", async () => {
    const huge = { items: [{ q: "বড়", a: "x".repeat(92_000) }] };
    await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${adminToken}`)
      .send(huge)
      .expect(400);
  });
});

describe("a valid write", () => {
  let adminToken: string;

  it("replaces the pack atomically + audited + served immediately", async () => {
    adminToken = await signIn(ADMIN);

    const before = await http().get("/api/content/faq").expect(200);
    const doc = before.body.data as { items: { q: string; a: string }[] };
    const edited = {
      items: [...doc.items, { q: "ই২ই প্রশ্ন?", a: "ই২ই উত্তর।" }],
    };

    const res = await http()
      .put("/api/admin/content/faq")
      .set("Authorization", `Bearer ${adminToken}`)
      .send(edited)
      .expect(200);
    expect(res.body.pack).toBe("faq");
    expect(res.body.itemCount).toBe(edited.items.length);

    // public read reflects the edit IMMEDIATELY (cache busted by the write)
    const after = await http().get("/api/content/faq").expect(200);
    expect((after.body.data as { items: unknown[] }).items).toHaveLength(edited.items.length);
    expect(JSON.stringify(after.body.data)).toContain("ই২ই প্রশ্ন?");

    // the file on disk is the serialized document; no tmp residue (atomic rename)
    const onDisk = await fs.readFile(path.join(tmpDir, "faq.json"), "utf8");
    expect(JSON.parse(onDisk)).toEqual(edited);
    const files = await fs.readdir(tmpDir);
    expect(files.some((f) => f.endsWith(".admin-tmp"))).toBe(false);

    // audit row
    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({
        where: { action: "content_pack_update", targetType: "content_pack" },
        orderBy: { createdAt: "desc" },
      })
    );
    expect(audit).not.toBeNull();
    expect((audit!.metaJson as Record<string, unknown>).pack).toBe("faq");
    expect((audit!.metaJson as Record<string, unknown>).itemCount).toBe(edited.items.length);
  });
});
