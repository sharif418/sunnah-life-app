// ─────────────────────────────────────────────────────────────────────────────
// invigilator-health.spec.ts (W4h) — GET /api/admin/invigilator-health:
//   • roles: unauth 401; plain member 403; usrah_head 403 (guard passes the
//     rank floor, the service refuses); invigilator self-view; full_admin list
//   • scope: self view is EXACTLY the caller (the F invigilator never appears
//     for the M one); full_admin sees both demo invigilators with their
//     gender-scoped usrah lists + member counts
//   • formula consistency: score == round(0.35·reviewPct + 0.35·amalPct +
//     0.20·activePct + 0.10·onTimePct) with onTimePct derivable from the
//     payload (overdue ÷ members)
//   • overdue counting: one synthetic overdue review for a scoped member
//     bumps overdueCount and the on-time component (cleaned up after)
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin (M)
const INVIGILATOR_M = "01000000002"; // হাফেজ যাকারিয়া — invigilator (M)
const INVIGILATOR_F = "01000000015"; // উস্তায়া সালেহা আক্তার — invigilator (F)
const HEAD = "01000000003"; // মাওলানা ইউসুফ — usrah_head (M)
const MEMBER = "01000000007"; // তানভীর হোসেন — member of উসরা আল-ফুরকান (M)
const USER = "01000000008"; // সাইফুল ইসলাম — plain user (M)

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

interface HealthRow {
  id: string;
  name: string;
  gender: string;
  usrahNames: string[];
  memberCount: number;
  reviewPct: number | null;
  amalPct: number | null;
  activePct: number | null;
  overdueCount: number;
  assessments30d: number;
  unsignedAssessments: number;
  score: number | null;
}

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

function expectFormula(row: HealthRow) {
  expect(row.score).not.toBeNull();
  expect([row.reviewPct, row.amalPct, row.activePct]).toEqual(
    expect.arrayContaining([expect.any(Number)])
  );
  const onTimePct = Math.max(0, Math.round(100 * (1 - row.overdueCount / row.memberCount)));
  const expected = Math.round(
    0.35 * (row.reviewPct ?? 0) + 0.35 * (row.amalPct ?? 0) + 0.2 * (row.activePct ?? 0) + 0.1 * onTimePct
  );
  expect(row.score).toBe(expected);
  expect(row.score).toBeGreaterThanOrEqual(0);
  expect(row.score).toBeLessThanOrEqual(100);
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  // remove the synthetic overdue review (if any was created) + close
  await rls.system((tx) =>
    tx.weeklyReview.deleteMany({ where: { userId: MEMBER, weekStart: "2020-01-04" } })
  );
  await app.close();
});

describe("GET /api/admin/invigilator-health (roles + scope)", () => {
  it("unauthenticated → 401", async () => {
    await http().get("/api/admin/invigilator-health").expect(401);
  });

  it("a plain member → 403", async () => {
    const token = await signIn(USER);
    await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
  });

  it("usrah_head → 403 (the service refuses the role)", async () => {
    const token = await signIn(HEAD);
    await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
  });

  it("invigilator self-view: EXACTLY one row — self, gender-scoped usrahs", async () => {
    const token = await signIn(INVIGILATOR_M);
    const res = await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    const rows = res.body.invigilators as HealthRow[];
    expect(rows).toHaveLength(1);
    expect(rows[0].name).toBe("হাফেজ যাকারিয়া");
    expect(rows[0].gender).toBe("M");
    expect(rows[0].usrahNames).toContain("উসরা আল-ফুরকান");
    expect(rows[0].usrahNames).not.toContain("উসরা আয়েশা সিদ্দিকা");
    expect(rows[0].memberCount).toBeGreaterThanOrEqual(6); // 03 04 07 08 09 10
    expectFormula(rows[0]);
  });

  it("the F invigilator's self-view scopes to the F usrah only", async () => {
    const token = await signIn(INVIGILATOR_F);
    const res = await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    const rows = res.body.invigilators as HealthRow[];
    expect(rows).toHaveLength(1);
    expect(rows[0].name).toBe("উস্তায়া সালেহা আক্তার");
    expect(rows[0].usrahNames).toContain("উসরা আয়েশা সিদ্দিকা");
    expect(rows[0].usrahNames).not.toContain("উসরা আল-ফুরকান");
  });

  it("full_admin sees BOTH invigilators with the formula satisfied", async () => {
    const token = await signIn(ADMIN);
    const res = await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    const rows = res.body.invigilators as HealthRow[];
    expect(rows.length).toBeGreaterThanOrEqual(2);
    const names = rows.map((r) => r.name);
    expect(names).toContain("হাফেজ যাকারিয়া");
    expect(names).toContain("উস্তায়া সালেহা আক্তার");
    for (const row of rows) expectFormula(row);
  });
});

describe("overdue counting (the red-flag component)", () => {
  it("a synthetic overdue review for a scoped member bumps overdueCount", async () => {
    const before = await signIn(INVIGILATOR_M).then((token) =>
      http()
        .get("/api/admin/invigilator-health")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .then((res) => (res.body.invigilators as HealthRow[])[0])
    );

    const member = (await rls.system((tx) => tx.user.findUnique({ where: { phone: MEMBER } })))!;
    await rls.system((tx) =>
      tx.weeklyReview.create({
        data: { userId: member.id, reviewerId: member.id, weekStart: "2020-01-04", status: "overdue" },
      })
    );

    const token = await signIn(INVIGILATOR_M);
    const res = await http()
      .get("/api/admin/invigilator-health")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    const after = (res.body.invigilators as HealthRow[])[0];
    expect(after.overdueCount).toBe(before.overdueCount + 1);
    expectFormula(after); // score still internally consistent

    await rls.system((tx) =>
      tx.weeklyReview.deleteMany({ where: { userId: member.id, weekStart: "2020-01-04" } })
    );
  });
});
