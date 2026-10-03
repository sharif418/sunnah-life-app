// Unit tests for the assessment rule engine: the paper's majority-সম্পূর্ণ pass rule
// and the score percentage (src/assessments/assessments.controller.ts).
// W4i adds the e2e lifecycle (below): submit → pending_confirmation + Fajr
// reminder → the ASSESSEE's own OTP confirm/decline → the level engine only
// counting CONFIRMED results.
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { assessmentPassed, scorePctOf } from "src/assessments/assessments.controller";
import { gatherLevelFacts, nextLevelFor } from "src/shared/levels";
import type { AssessmentTemplate } from "src/shared/domain";

const template: AssessmentTemplate = {
  key: "farze_ain_v1",
  version: 1,
  titleBn: "ফরযে আইন মূল্যায়ন",
  titleEn: "Farze Ain v1",
  sections: [
    {
      key: "iman",
      titleBn: "ঈমান",
      criteria: [
        { key: "i1", titleBn: "১" },
        { key: "i2", titleBn: "২" },
        { key: "i3", titleBn: "৩" },
      ],
    },
    {
      key: "akhlaq",
      titleBn: "আখলাক",
      criteria: [
        { key: "a1", titleBn: "১" },
        { key: "a2", titleBn: "২" },
      ],
    },
  ],
};

describe("assessmentPassed — the paper rule: a strict majority of ALL criteria scored সম্পূর্ণ (2)", () => {
  it("all 2s → passed", () => {
    const scores = { i1: { score: 2 }, i2: { score: 2 }, i3: { score: 2 }, a1: { score: 2 }, a2: { score: 2 } };
    expect(assessmentPassed(template, scores)).toBe(true);
  });

  it("আংশিক (1) never counts — all 1s fail (the old ≥1 rule passed this)", () => {
    const scores = { i1: { score: 1 }, i2: { score: 1 }, i3: { score: 1 }, a1: { score: 1 }, a2: { score: 1 } };
    expect(assessmentPassed(template, scores)).toBe(false);
  });

  it("3 of 5 সম্পূর্ণ → passed even with one section at 0 (no per-section gate)", () => {
    const scores = { i1: { score: 2 }, i2: { score: 2 }, i3: { score: 2 }, a1: { score: 0 }, a2: { score: 0 } };
    expect(assessmentPassed(template, scores)).toBe(true);
  });

  it("exactly half is not a majority", () => {
    const four: AssessmentTemplate = {
      ...template,
      sections: [{ key: "x", titleBn: "x", criteria: [{ key: "x1", titleBn: "1" }, { key: "x2", titleBn: "2" }, { key: "x3", titleBn: "3" }, { key: "x4", titleBn: "4" }] }],
    };
    expect(assessmentPassed(four, { x1: { score: 2 }, x2: { score: 2 }, x3: { score: 1 }, x4: { score: 1 } })).toBe(false);
  });

  it("missing scores count as 0", () => {
    const scores = { i1: { score: 2 }, i2: { score: 2 } }; // 2 of 5
    expect(assessmentPassed(template, scores)).toBe(false);
  });

  it("a form with no criteria never passes", () => {
    const empty: AssessmentTemplate = { ...template, sections: [{ key: "x", titleBn: "x", criteria: [] }] };
    expect(assessmentPassed(empty, {})).toBe(false);
  });
});

describe("scorePctOf", () => {
  it("maps the sum of scores onto 0–100 of the doubled maximum", () => {
    expect(scorePctOf({ a: { score: 2 }, b: { score: 2 }, c: { score: 2 } })).toBe(100);
    expect(scorePctOf({ a: { score: 1 }, b: { score: 2 }, c: { score: 0 } })).toBe(50);
    expect(scorePctOf({})).toBeNull();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// W4i e2e — the assessee-acknowledgment lifecycle (demo DB, the goals.spec
// pattern). Phones: the M invigilator (assessor) + 01000000009 (মেহেদী —
// daee at muhibbus_sunnah with NO passed assessment, so the farze_ain_1
// assessment rule is genuinely unmet). The mock SMS provider exposes devCode
// exactly like test/auth-otp.spec.ts relies on; মেহেদী's phone gets exactly
// three OTP sends (signIn + one wrong-code probe + the confirm) — the DB's
// 3-per-10-min window allows exactly that.
// ─────────────────────────────────────────────────────────────────────────────
const INVIGILATOR = "01000000002"; // হাফেজ যাকারিয়া — invigilator of আল-ফুরকান (M)
const MEMBER = "01000000009"; // মেহেদী হাসান — daee, muhibbus_sunnah, no passed assessment

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
let memberId: string;
let invigilatorId: string;

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

/** All-2s scores for every criterion of the ACTIVE template → passed. */
async function passingScores(): Promise<{ templateKey: string; scores: Record<string, { score: 2 }> }> {
  const tpl = await http().get("/api/assessments/templates").expect(200);
  const active = tpl.body.templates[0] as AssessmentTemplate;
  const scores: Record<string, { score: 2 }> = {};
  for (const s of active.sections) for (const c of s.criteria) scores[c.key] = { score: 2 };
  return { templateKey: active.key, scores };
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());
  memberId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: MEMBER } })))!.id;
  invigilatorId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: INVIGILATOR } })))!.id;
});

afterAll(async () => {
  // leave the demo DB pristine: every assessment/reminder this spec created
  // is hard-deleted (audit rows stay — the goals.spec pattern). মেহেদী's
  // level facts therefore return to their honest unpassed state.
  if (memberId) {
    await rls.system(async (tx) => {
      await tx.assessment.deleteMany({
        where: { assesseeId: memberId, assessorId: invigilatorId, createdAt: { gte: SPEC_STARTED_AT } },
      });
      await tx.reminder.deleteMany({ where: { userId: memberId, title: "মূল্যায়নের ফলাফল প্রস্তুত" } });
      await tx.reminder.deleteMany({ where: { userId: invigilatorId, title: "মূল্যায়ন বাতিল করা হয়েছে" } });
    });
  }
  await app.close();
});

const SPEC_STARTED_AT = new Date();

describe("assessment acknowledgment lifecycle (W4i e2e)", () => {
  let invigilatorToken: string;
  let memberToken: string;
  let confirmableId: string; // the assessment that gets CONFIRMED
  let declineId: string; // the assessment that gets DECLINED

  it("invigilator submits → status pending_confirmation + Fajr-scheduled reminder (link assessment)", async () => {
    invigilatorToken = await signIn(INVIGILATOR);
    const { templateKey, scores } = await passingScores();
    const res = await http()
      .post("/api/assessments")
      .set("Authorization", `Bearer ${invigilatorToken}`)
      .send({ assesseeId: memberId, templateKey, participantCategory: 1, scores })
      .expect(201);
    expect(res.body.assessment.result).toBe("passed");
    expect(res.body.assessment.status).toBe("pending_confirmation");
    expect(res.body.assessment.assesseeSignedAt).toBeNull();
    confirmableId = res.body.assessment.id;

    // the member's reminder — kind assessment, link assessment, tomorrow's
    // Fajr in their own tz (the goal-approval pattern)
    const reminders = (await rls.system((tx) =>
      tx.reminder.findMany({ where: { userId: memberId, kind: "assessment", title: "মূল্যায়নের ফলাফল প্রস্তুত" } })
    )) as unknown as { body: string | null; link: string | null; scheduledAt: Date | null }[];
    expect(reminders.length).toBeGreaterThanOrEqual(1);
    const mine = reminders[reminders.length - 1];
    expect(mine.link).toBe("assessment");
    expect(mine.body).toContain("OTP দিয়ে নিশ্চিত করুন");
    const at = mine.scheduledAt!.getTime();
    expect(at).toBeGreaterThan(Date.now());
    expect(at).toBeLessThan(Date.now() + 48 * 3_600_000);
  });

  it("GET /api/assessments/me — the ASSESSEE view (status + scores), never the assessor's", async () => {
    memberToken = await signIn(MEMBER);
    const res = await http().get("/api/assessments/me").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const rows = res.body.assessments as { id: string; status: string; scores: Record<string, unknown> }[];
    const mine = rows.find((r) => r.id === confirmableId)!;
    expect(mine).toBeDefined();
    expect(mine.status).toBe("pending_confirmation");
    expect(Object.keys(mine.scores).length).toBeGreaterThan(0); // the member SEES the scores
    expect(rows.every((r) => r.id !== undefined)).toBe(true);

    // /me is the assessee view: the invigilator (the row's own ASSESSOR) does
    // not see it there — RLS the net + the assesseeId scoping.
    const assessorView = await http()
      .get("/api/assessments/me")
      .set("Authorization", `Bearer ${invigilatorToken}`)
      .expect(200);
    for (const r of assessorView.body.assessments as { id: string }[]) {
      expect(r.id).not.toBe(confirmableId);
    }

    // unauthenticated → 401
    await http().get("/api/assessments/me").expect(401);
  });

  it("the assessor (or anyone else) cannot request the confirm OTP — 403 (the decision is the assessee's alone)", async () => {
    await http()
      .post(`/api/assessments/${confirmableId}/confirm-request`)
      .set("Authorization", `Bearer ${invigilatorToken}`)
      .expect(403);
    await http().post(`/api/assessments/${confirmableId}/confirm-request`).expect(401);
  });

  it("the level engine does NOT count the pending result (requirements unmet)", async () => {
    const res = await http().get("/api/dawah/requirements").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const row = (res.body.requirements as { key: string; met: boolean; detailBn: string }[]).find(
      (r) => r.key === "assessment_passed"
    );
    expect(row).toBeDefined(); // farze_ain_1 rules require the assessment
    expect(row!.met).toBe(false); // passed but NOT confirmed → not final
    expect(row!.detailBn).toContain("এখনো উত্তীর্ণ হননি");
  });

  it("confirm-request issues the OTP to the ASSESSEE's own phone (mock SMS → devCode); a wrong code 400s", async () => {
    const res = await http()
      .post(`/api/assessments/${confirmableId}/confirm-request`)
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(201);
    expect(res.body.ok).toBe(true);
    expect(res.body.devCode).toMatch(/^\d{6}$/); // the auth-otp.spec affordance

    const wrong = res.body.devCode === "000000" ? "111111" : "000000";
    const bad = await http()
      .post(`/api/assessments/${confirmableId}/confirm`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ code: wrong })
      .expect(400);
    expect(bad.body.error).toContain("ভুল কোড");
  });

  it("confirm → status confirmed + signature + audit row; the level rule now counts it", async () => {
    const otpRes = await http()
      .post(`/api/assessments/${confirmableId}/confirm-request`)
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(201);
    const res = await http()
      .post(`/api/assessments/${confirmableId}/confirm`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ code: otpRes.body.devCode })
      .expect(201);
    expect(res.body.assessment.status).toBe("confirmed");
    expect(res.body.assessment.assesseeSignedAt).toBeTruthy(); // the OTP-confirmed signature
    expect(res.body.assessment.confirmedAt).toBeTruthy();

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "assessment_confirm", targetId: confirmableId } })
    );
    expect(audit).toBeTruthy();
    expect((audit!.metaJson as { assesseeId: string }).assesseeId).toBe(memberId);

    // the consumed code can never replay (atomic consume — same rule as sign-in)
    await http()
      .post(`/api/assessments/${confirmableId}/confirm`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ code: otpRes.body.devCode })
      .expect(400);

    // re-confirm on a confirmed row → 400
    const again = await http()
      .post(`/api/assessments/${confirmableId}/confirm-request`)
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(400);
    expect(again.body.error).toContain("অপেক্ষমাণ");

    // THE LEVEL GATE: the now-final passed assessment satisfies the rule
    const req = await http().get("/api/dawah/requirements").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const row = (req.body.requirements as { key: string; met: boolean }[]).find(
      (r) => r.key === "assessment_passed"
    );
    expect(row!.met).toBe(true);
  });

  it("Farze Ain categories are alternative tracks: a category-1 pass does not satisfy category 2", async () => {
    const member = await rls.system((tx) => tx.user.findUniqueOrThrow({ where: { id: memberId } }));
    const domainMember = { ...member, levelStartedAt: member.levelStartedAt?.toISOString() ?? null, createdAt: member.createdAt.toISOString() } as never;
    const [cat1, cat2, next] = await rls.system(async (tx) => [
      await gatherLevelFacts(tx, domainMember, 1),
      await gatherLevelFacts(tx, domainMember, 2),
      await nextLevelFor(tx, member as never),
    ]);
    expect((cat1 as { assessmentPassed: boolean }).assessmentPassed).toBe(true);
    expect((cat2 as { assessmentPassed: boolean }).assessmentPassed).toBe(false);
    // the track follows the member's latest assessment (category 1 here)
    expect(next).toBe("farze_ain_1");
  });

  it("decline → status declined + reason + Fajr reminder to the invigilator + audit", async () => {
    const { templateKey, scores } = await passingScores();
    const created = await http()
      .post("/api/assessments")
      .set("Authorization", `Bearer ${invigilatorToken}`)
      .send({ assesseeId: memberId, templateKey, participantCategory: 1, scores })
      .expect(201);
    declineId = created.body.assessment.id;

    const res = await http()
      .post(`/api/assessments/${declineId}/decline`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ reason: "স্কোরে ভুল আছে — আবার মূল্যায়ন হোক" })
      .expect(201);
    expect(res.body.assessment.status).toBe("declined");
    expect(res.body.assessment.decisionNote).toBe("স্কোরে ভুল আছে — আবার মূল্যায়ন হোক");
    expect(res.body.assessment.assesseeSignedAt).toBeNull(); // never signed

    // the invigilator is notified (their own tz, Fajr tomorrow — goal pattern)
    const reminders = (await rls.system((tx) =>
      tx.reminder.findMany({ where: { userId: invigilatorId, title: "মূল্যায়ন বাতিল করা হয়েছে" } })
    )) as unknown as { body: string | null; link: string | null; scheduledAt: Date | null }[];
    expect(reminders.length).toBeGreaterThanOrEqual(1);
    const mine = reminders[reminders.length - 1];
    expect(mine.body).toContain("স্কোরে ভুল আছে");
    expect(mine.body).toContain("মেহেদী হাসান");
    expect(mine.link).toBe("assessment");
    expect(mine.scheduledAt!.getTime()).toBeGreaterThan(Date.now());

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "assessment_decline", targetId: declineId } })
    );
    expect(audit).toBeTruthy();
    expect((audit!.metaJson as { reason: string | null }).reason).toBe("স্কোরে ভুল আছে — আবার মূল্যায়ন হোক");

    // a declined row can never be confirmed afterwards
    await http()
      .post(`/api/assessments/${declineId}/confirm-request`)
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(400);

    // and the member's /me shows the honest declined state
    const me = await http().get("/api/assessments/me").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const declined = (me.body.assessments as { id: string; status: string }[]).find((r) => r.id === declineId)!;
    expect(declined.status).toBe("declined");
  });
});
