// ─────────────────────────────────────────────────────────────────────────────
// Member register import — the pure normalisers (Excel quirks, Bengali
// labels and digits) and the real route: dryRun writes nothing, commit
// creates / fills-empty / skips / reports, the usrah gender rule holds, an
// existing account is never re-gendered.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import {
  normalizeCategory,
  normalizeGender,
  normalizeMemberCode,
  normalizePhone,
  normalizeRole,
  pickField,
} from "src/admin/member-import";

describe("member import — normalisers", () => {
  it("phones: Excel-dropped leading 0, Bengali digits, junk", () => {
    expect(normalizePhone("1712345678")).toBe("01712345678");
    expect(normalizePhone("০১৭১২-৩৪৫৬৭৮")).toBe("01712345678");
    expect(normalizePhone("+8801712345678")).toBe("+8801712345678");
    expect(normalizePhone("12345")).toBeNull();
  });

  it("gender / role / category accept Bengali labels", () => {
    expect(normalizeGender("ভাই")).toBe("M");
    expect(normalizeGender("বোন")).toBe("F");
    expect(normalizeGender("")).toBeNull();
    expect(normalizeRole("")).toBe("user");
    expect(normalizeRole("দাঈ")).toBe("daee");
    expect(normalizeRole("usrah_head")).toBeNull(); // appointed in the console
    expect(normalizeCategory("হাফেজ")).toBe("hafez");
    expect(normalizeCategory("x")).toBeNull();
  });

  it("legacy DS codes normalise; malformed is null, absent is undefined", () => {
    expect(normalizeMemberCode("ds-123")).toBe("DS-000123");
    expect(normalizeMemberCode("DS১২৩")).toBe("DS-000123");
    expect(normalizeMemberCode("")).toBeUndefined();
    expect(normalizeMemberCode("ABC")).toBeNull();
  });

  it("headers match in Bengali or English, any case", () => {
    expect(pickField({ "মোবাইল": " 017 " }, "phone")).toBe("017");
    expect(pickField({ Name: "ক" }, "name")).toBe("ক");
  });
});

describe("POST /api/admin/users/import", () => {
  let app: INestApplication;
  let rls: RlsService; // User has FORCE RLS — raw Prisma reads see nothing
  let adminToken: string;
  const NEW_M = "01799990011";
  const NEW_F = "01799990012";
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
    await app.init();
    rls = app.get(RlsService);
    const otp = await http().post("/api/auth/otp/request").send({ phone: "01000000001" }).expect(200);
    const v = await http().post("/api/auth/otp/verify").send({ phone: "01000000001", code: otp.body.devCode }).expect(200);
    adminToken = v.body.accessToken;
  });

  afterAll(async () => {
    await rls.system((tx) => tx.user.deleteMany({ where: { phone: { in: [NEW_M, NEW_F] } } }));
    await app.close();
  });

  const rows = [
    { "নাম": "আমদানি ভাই", "মোবাইল": NEW_M.slice(1), "লিঙ্গ": "ভাই", "ভূমিকা": "দাঈ", "উসরা": "উসরা আল-ফুরকান", "সদস্য কোড": "DS-9001", "জেলা": "ঢাকা" },
    { "নাম": "আমদানি বোন", "মোবাইল": NEW_F, "লিঙ্গ": "বোন", "উসরা": "উসরা আল-ফুরকান" }, // wrong-gender usrah
    { "নাম": "ডুপ্লিকেট", "মোবাইল": NEW_M }, // same phone again in the file
    { "নাম": "নামহীন নম্বর", "মোবাইল": "123" },
  ];

  it("dryRun previews and writes nothing", async () => {
    const res = await http()
      .post("/api/admin/users/import")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ rows, dryRun: true })
      .expect(200);
    expect(res.body.dryRun).toBe(true);
    expect(res.body.results.map((r: { action: string }) => r.action)).toEqual(["create", "error", "skip", "error"]);
    expect(res.body.results[1].message).toContain("এক-লিঙ্গ");
    expect(await rls.system((tx) => tx.user.count({ where: { phone: NEW_M } }))).toBe(0);
  });

  it("commit creates the valid row (legacy code kept); a re-import only fills empty fields", async () => {
    const res = await http()
      .post("/api/admin/users/import")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ rows, dryRun: false, offset: 0 })
      .expect(200);
    expect(res.body.totals).toEqual({ create: 1, update: 0, skip: 1, error: 2 });
    const u = await rls.system((tx) => tx.user.findUnique({ where: { phone: NEW_M } }));
    expect(u).toMatchObject({ name: "আমদানি ভাই", gender: "M", role: "daee", memberCode: "DS-009001", district: "ঢাকা" });

    // the same phone again: never re-gendered; only the empty workplace fills
    const again = await http()
      .post("/api/admin/users/import")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ rows: [{ name: "x", phone: NEW_M, gender: "F", workplace: "আস-সুন্নাহ" }], dryRun: false, offset: 10 })
      .expect(200);
    expect(again.body.results[0]).toMatchObject({ row: 12, action: "update" });
    const after = await rls.system((tx) => tx.user.findUnique({ where: { phone: NEW_M } }));
    expect(after).toMatchObject({ gender: "M", name: "আমদানি ভাই", workplace: "আস-সুন্নাহ" });
  });

  it("only full_admin may import", async () => {
    const otp = await http().post("/api/auth/otp/request").send({ phone: "01000000003" }).expect(200);
    const v = await http().post("/api/auth/otp/verify").send({ phone: "01000000003", code: otp.body.devCode }).expect(200);
    await http()
      .post("/api/admin/users/import")
      .set("Authorization", `Bearer ${v.body.accessToken}`)
      .send({ rows, dryRun: true })
      .expect(403);
  });
});
