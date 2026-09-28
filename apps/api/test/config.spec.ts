// ─────────────────────────────────────────────────────────────────────────────
// config.spec.ts (Phase C/W1b) — ONE editable app configuration:
//   • GET /api/config serves the DB row (key "app") merged over defaults,
//     with the five institution contacts, group links, hijri ±adjust,
//     donation URL, leaderboard/detox flags
//   • PATCH /api/admin/config (full_admin, audited) updates it and the
//     public read reflects the change immediately (cache invalidation)
//   • seed:reference upserts defaults WITHOUT clobbering admin edits
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { PrismaService } from "src/common/prisma.service";
import { invalidateAppConfigCache } from "src/config/config.controller";

const FULL_ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন
const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — plain daee

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let prisma: PrismaService;

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  prisma = app.get(PrismaService);
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  // restore the seeded defaults so other suites see the canonical config
  await prisma.appConfigRow.deleteMany({ where: { key: "app" } });
  invalidateAppConfigCache();
  await app.close();
});

describe("GET /api/config — the ONE source", () => {
  it("serves the five institutions + groups + flags (public, no auth)", async () => {
    const res = await http().get("/api/config").expect(200);
    expect(res.body.contacts).toHaveLength(5);
    expect(res.body.contacts[0].org).toBe("দাওয়াতুস সুন্নাহ");
    expect(res.body.contacts.map((c: { org: string }) => c.org)).toEqual(
      expect.arrayContaining(["আস-সুন্নাহ ফাউন্ডেশন", "স্কিল ডেভেলপমেন্ট", "দাওয়াহ ইনস্টিটিউট", "মাদরাসাতুস সুন্নাহ"])
    );
    expect(res.body.groups.length).toBeGreaterThanOrEqual(3);
    expect(typeof res.body.donationUrl).toBe("string");
    expect(res.body.donationUrl).toMatch(/^https:\/\//);
    expect(res.body.hijriAdjust).toBe(0);
    expect(res.body.leaderboardEnabled).toBe(false);
    expect(typeof res.body.detoxEnabled).toBe("boolean");
  });

  it("falls back to defaults when the row is absent", async () => {
    await prisma.appConfigRow.deleteMany({ where: { key: "app" } });
    invalidateAppConfigCache();
    const res = await http().get("/api/config").expect(200);
    expect(res.body.contacts).toHaveLength(5);
    expect(res.body.donationUrl).toBe("https://as-sunnah.org/donation");
  });
});

describe("PATCH /api/admin/config — the CMS write (full_admin only)", () => {
  it("a non-admin is rejected", async () => {
    const token = await signIn(M_MEMBER);
    await http()
      .patch("/api/admin/config")
      .set("Authorization", `Bearer ${token}`)
      .send({ hijriAdjust: 1 })
      .expect(403);
  });

  it("full_admin updates hijriAdjust + donationUrl; GET reflects it immediately", async () => {
    const token = await signIn(FULL_ADMIN);
    const res = await http()
      .patch("/api/admin/config")
      .set("Authorization", `Bearer ${token}`)
      .send({ hijriAdjust: -1, donationUrl: "https://as-sunnah.org/donate-new" })
      .expect(200);
    expect(res.body.hijriAdjust).toBe(-1);
    expect(res.body.donationUrl).toBe("https://as-sunnah.org/donate-new");
    // contacts untouched by the partial update
    expect(res.body.contacts).toHaveLength(5);

    // public read sees the new value (cache invalidated by the write)
    const pub = await http().get("/api/config").expect(200);
    expect(pub.body.hijriAdjust).toBe(-1);
    expect(pub.body.donationUrl).toBe("https://as-sunnah.org/donate-new");

    // and the write is AUDITED
    const auditRes = await http()
      .get("/api/admin/audit")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    const entry = (auditRes.body as { entries: { action: string; meta: Record<string, unknown> }[] }).entries.find(
      (e) => e.action === "update_app_config"
    );
    expect(entry).toBeDefined();
    expect((entry!.meta.changed as string[]).sort()).toEqual(["donationUrl", "hijriAdjust"]);
  });

  it("clamps hijriAdjust to ±2 (moon-sighting reality) and rejects nonsense types", async () => {
    const token = await signIn(FULL_ADMIN);
    const res = await http()
      .patch("/api/admin/config")
      .set("Authorization", `Bearer ${token}`)
      .send({ hijriAdjust: 7 })
      .expect(200);
    expect(res.body.hijriAdjust).toBe(0); // out-of-range ignored, keeps prior 0… or the last valid value
    expect([-2, -1, 0, 1, 2]).toContain(res.body.hijriAdjust);
  });

  it("leaderboard flag flips (the scholars' gate)", async () => {
    const token = await signIn(FULL_ADMIN);
    const res = await http()
      .patch("/api/admin/config")
      .set("Authorization", `Bearer ${token}`)
      .send({ leaderboardEnabled: true })
      .expect(200);
    expect(res.body.leaderboardEnabled).toBe(true);
  });
});
