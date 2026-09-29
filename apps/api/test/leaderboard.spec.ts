// ─────────────────────────────────────────────────────────────────────────────
// leaderboard.spec.ts (Phase C/W4c) — gender-scoped percentile-band leaderboard:
//   • the config gate: leaderboardEnabled=false → 404 + the Bengali message
//   • pure percentile → band maths (boundaries, ties, solo cohort)
//   • genderTotals: the aggregate covers EXACTLY the gender's user ids
//     (males' totals never include female ids and vice versa — the precise
//     no-cross-gender-leak assertion)
//   • e2e with a fully controlled cohort: five pre-onboarding
//     ("unspecified" gender) users with exact 30-day point totals
//     [40, 30, 20, 10, 0] → deterministic bands top10 / top75 / bottom,
//     and myPoints matches the amalPoints rule exactly
// Runs against the demo DB exactly like rls.e2e/config.spec.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { PrismaService } from "src/common/prisma.service";
import { invalidateAppConfigCache } from "src/config/config.controller";
import { lastNDayKeys } from "src/shared/amal";
import {
  bandOfPercentile,
  LeaderboardService,
  percentileOf,
} from "src/leaderboard/leaderboard.controller";

const FULL_ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন
const OFF_MSG = "লিডারবোর্ড সাময়িকভাবে বন্ধ";

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
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
  rls = app.get(RlsService);
  prisma = app.get(PrismaService);
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  // drop the synthetic cohort (entries cascade) + restore the seeded config
  await rls.system((tx) => tx.user.deleteMany({ where: { phone: { startsWith: "0177900" } } }));
  await prisma.appConfigRow.deleteMany({ where: { key: "app" } });
  invalidateAppConfigCache();
  await app.close();
});

describe("percentile → band maths (pure)", () => {
  it("percentileOf: share of the cohort at-or-below me, ties split evenly", () => {
    expect(percentileOf(100, [90, 80, 70])).toBe(100);
    expect(percentileOf(0, [10, 20, 30])).toBe(0);
    expect(percentileOf(50, [50, 50, 100])).toBeCloseTo((0 + 1) / 3 * 100, 5);
    expect(percentileOf(5, [])).toBe(50); // solo cohort → the median
  });

  it("bandOfPercentile: the five bands with their boundaries", () => {
    expect(bandOfPercentile(100)).toBe("top10");
    expect(bandOfPercentile(90)).toBe("top10"); // boundary in
    expect(bandOfPercentile(89.99)).toBe("top25");
    expect(bandOfPercentile(75)).toBe("top25");
    expect(bandOfPercentile(74.99)).toBe("top50");
    expect(bandOfPercentile(50)).toBe("top50");
    expect(bandOfPercentile(49.99)).toBe("top75");
    expect(bandOfPercentile(25)).toBe("top75");
    expect(bandOfPercentile(24.99)).toBe("bottom");
    expect(bandOfPercentile(0)).toBe("bottom");
  });

  it("cohort [0,10,20,30,40]: top → top10, 30 → top25, 20 → top50, 10 → top75, 0 → bottom", () => {
    const others = (mine: number) => [0, 10, 20, 30, 40].filter((v) => v !== mine);
    expect(bandOfPercentile(percentileOf(40, others(40)))).toBe("top10");
    expect(bandOfPercentile(percentileOf(30, others(30)))).toBe("top25");
    expect(bandOfPercentile(percentileOf(20, others(20)))).toBe("top50");
    expect(bandOfPercentile(percentileOf(10, others(10)))).toBe("top75");
    expect(bandOfPercentile(percentileOf(0, others(0)))).toBe("bottom");
  });
});

describe("genderTotals — the aggregate is exactly gender-scoped", () => {
  let service: LeaderboardService;
  let maleIds: Set<string>;
  let femaleIds: Set<string>;

  beforeAll(async () => {
    service = app.get(LeaderboardService);
    [maleIds, femaleIds] = await rls.system(async (tx) => {
      const rows = (await tx.user.findMany({
        where: { gender: { in: ["M", "F"] } },
        select: { id: true, gender: true },
      })) as unknown as { id: string; gender: string }[];
      return [
        new Set(rows.filter((r) => r.gender === "M").map((r) => r.id)),
        new Set(rows.filter((r) => r.gender === "F").map((r) => r.id)),
      ];
    });
  });

  it("males' totals cover exactly the male ids — never a female id (no cross-gender leak)", async () => {
    const mTotals = await service.genderTotals("M");
    expect(mTotals.size).toBe(maleIds.size); // every male user has a total (0 included)
    for (const id of mTotals.keys()) expect(maleIds.has(id)).toBe(true);
    for (const id of femaleIds) expect(mTotals.has(id)).toBe(false);
  });

  it("females' totals cover exactly the female ids — never a male id (mirror)", async () => {
    const fTotals = await service.genderTotals("F");
    expect(fTotals.size).toBe(femaleIds.size);
    for (const id of fTotals.keys()) expect(femaleIds.has(id)).toBe(true);
    for (const id of maleIds) expect(fTotals.has(id)).toBe(false);
  });
});

describe("GET /api/leaderboard/me — config gate + controlled cohort (e2e)", () => {
  // Five pre-onboarding ("unspecified" gender) users with EXACT 30-day point
  // totals — their gender value is their own cohort, so no demo user can
  // perturb the distribution. Points come from boolean amals (true = 1pt).
  const PHONES = {
    top: "01779000001", // 40 points (2 amals × 30d + 1 × 10d)
    high: "01779000002", // 30 points
    mid: "01779000003", // 20 points
    low: "01779000004", // 10 points
    zero: "01779000005", // 0 points
  } as const;

  beforeAll(async () => {
    // clean slate for the cohort, then create users + exact totals
    await rls.system(async (tx) => {
      await tx.user.deleteMany({ where: { phone: { in: Object.values(PHONES) } } });
      const days = lastNDayKeys(30);
      for (const [name, phone] of Object.entries(PHONES)) {
        const u = await tx.user.create({
          data: { phone, name: `লিডারবোর্ড ${name}`, gender: "unspecified", category: "general" },
        });
        // points: top=40, high=30, mid=20, low=10, zero=0
        const plan: Record<string, { key: string; days: number }[]> = {
          top: [
            { key: "salat_witr", days: 30 },
            { key: "tahajjud", days: 10 },
          ],
          high: [{ key: "salat_witr", days: 30 }],
          mid: [{ key: "salat_witr", days: 20 }],
          low: [{ key: "salat_witr", days: 10 }],
          zero: [],
        };
        const rows = plan[name].flatMap((p) =>
          days.slice(0, p.days).map((date) => ({
            userId: u.id,
            amalKey: p.key,
            date,
            valueJson: true as never,
            source: "manual",
            clientUpdatedAt: new Date(),
          }))
        );
        if (rows.length) await tx.amalEntry.createMany({ data: rows });
      }
    });

    // enable the leaderboard through the real admin CMS route (audited,
    // cache-invalidating) — the same write the scholars' gate uses
    const adminToken = await signIn(FULL_ADMIN);
    await http()
      .patch("/api/admin/config")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ leaderboardEnabled: true })
      .expect(200);
  });

  it("disabled → 404 with the Bengali message (the scholars' gate)", async () => {
    // flip OFF directly + drop the read cache — then back on for the tests below
    await prisma.appConfigRow.upsert({
      where: { key: "app" },
      create: { key: "app", valueJson: { leaderboardEnabled: false } },
      update: { valueJson: { leaderboardEnabled: false } },
    });
    invalidateAppConfigCache();
    const token = await signIn(PHONES.mid);
    const res = await http().get("/api/leaderboard/me").set("Authorization", `Bearer ${token}`).expect(404);
    expect(res.body.error).toBe(OFF_MSG);
  });

  it("enabled: the top of the controlled cohort → top10 + exact myPoints", async () => {
    await prisma.appConfigRow.upsert({
      where: { key: "app" },
      create: { key: "app", valueJson: { leaderboardEnabled: true } },
      update: { valueJson: { leaderboardEnabled: true } },
    });
    invalidateAppConfigCache();

    const token = await signIn(PHONES.top);
    const res = await http().get("/api/leaderboard/me").set("Authorization", `Bearer ${token}`).expect(200);
    expect(res.body).toEqual({ band: "top10", myPoints: 40, windowDays: 30 });
    // privacy: NO lists, no other user's data in the payload
    expect(Object.keys(res.body).sort()).toEqual(["band", "myPoints", "windowDays"]);
  });

  it("mid of the cohort → top75 band (10 of [0,10,20,30,40]… this is the 10-point user)", async () => {
    const token = await signIn(PHONES.low);
    const res = await http().get("/api/leaderboard/me").set("Authorization", `Bearer ${token}`).expect(200);
    // others = [40,30,20,0] → below=1 → 25th percentile → top75
    expect(res.body).toEqual({ band: "top75", myPoints: 10, windowDays: 30 });
  });

  it("bottom of the cohort → bottom band + 0 points", async () => {
    const token = await signIn(PHONES.zero);
    const res = await http().get("/api/leaderboard/me").set("Authorization", `Bearer ${token}`).expect(200);
    expect(res.body).toEqual({ band: "bottom", myPoints: 0, windowDays: 30 });
  });

  it("unauthenticated callers get 401 (member-only surface)", async () => {
    await http().get("/api/leaderboard/me").expect(401);
  });
});
