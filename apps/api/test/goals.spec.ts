// ─────────────────────────────────────────────────────────────────────────────
// goals.spec.ts (Phase C/W4c) — the personal-goal lifecycle e2e:
//   • member proposes (status "proposed", max-14 OPEN cap)
//   • head approval queue GET /api/usrah/goals (RLS-scoped, member names)
//   • head approve → status approved + Reminder row for the member (kind
//     "goal", scheduled Fajr tomorrow member-tz) + AuditLog row; idempotent
//   • head reject {reason} → status rejected, member sees the reason; a
//     terminal goal is NOT deletable (history stays)
//   • a plain member cannot approve (403); a cross-gender head cannot
//     decide another usrah's goal (403)
//   • the weekly review summary carries the member's approved goals
//   • fajrOfNextDay (pure) — the reminder schedule lands tomorrow morning
//     in the user's zone
// Runs against the demo DB (SEED_DEMO) exactly like rls.e2e/config.spec.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { fajrOfNextDay } from "src/shared/amal";
import { weekStartOf } from "src/shared/reviews";

const M_HEAD = "01000000003"; // মাওলানা ইউসুফ — head of উসরা আল-ফুরকান (M)
const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — male member of আল-ফুরকান
const F_HEAD = "01000000005"; // উম্মে হাবিবা — head of উসরা আয়েশা সিদ্দিকা (F)

const OPEN = ["proposed", "approved"];
const MARK = "ই২ই লক্ষ্য"; // marks every goal this spec creates

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
let maleMemberId: string;
let maleHeadId: string;

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
  http = () => request(app.getHttpServer());
  maleMemberId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: M_MEMBER } })))!.id;
  maleHeadId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: M_HEAD } })))!.id;
});

afterAll(async () => {
  // leave the demo DB pristine: every goal/reminder this spec created is
  // hard-deleted (regardless of lifecycle status)
  if (maleMemberId) {
    await rls.system(async (tx) => {
      await tx.personalGoal.deleteMany({ where: { userId: maleMemberId, title: { contains: MARK } } });
      await tx.reminder.deleteMany({ where: { userId: maleMemberId, title: { contains: MARK } } });
      // the review-submit reminder carries the spec comment as its body
      await tx.reminder.deleteMany({
        where: { userId: maleMemberId, title: { contains: "সাপ্তাহিক রিভিউ" }, body: "e2e goal summary" },
      });
    });
  }
  await app.close();
});

describe("fajrOfNextDay (pure) — the approval-reminder schedule", () => {
  const USER = { lat: null, lng: null, calcMethod: "karachi" as const, madhhab: "hanafi" as const };

  it("lands within the next 48h, in tomorrow's Dhaka morning window", () => {
    const at = fajrOfNextDay(USER).getTime();
    const inMs = at - Date.now();
    expect(inMs).toBeGreaterThan(0);
    expect(inMs).toBeLessThan(48 * 3_600_000);
    // Dhaka wall clock of the scheduled instant: tomorrow ~04:00–06:30
    const wall = new Date(at + 6 * 3_600_000).toISOString();
    expect(wall.slice(11, 13)).toMatch(/^0[4-6]$/);
    if (wall.slice(11, 13) === "06") {
      expect(Number(wall.slice(14, 16))).toBeLessThanOrEqual(30);
    }
  });
});

describe("goal lifecycle (e2e)", () => {
  let memberToken: string;
  let headToken: string;
  let fHeadToken: string;
  let proposedId: string; // the goal that gets APPROVED
  let rejectId: string; // the goal that gets REJECTED

  it("member proposes → status proposed with the new fields", async () => {
    memberToken = await signIn(M_MEMBER);
    const res = await http()
      .post("/api/goals")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ amalKey: "tahajjud", title: `${MARK} — অনুমোদনের জন্য`, target: "প্রতিদিন", startDate: "2025-06-01" })
      .expect(201);
    expect(res.body.goal.status).toBe("proposed");
    expect(res.body.goal.userId).toBe(maleMemberId);
    expect(res.body.goal.active).toBe(true);
    expect(res.body.goal.decidedById).toBeNull();
    expect(res.body.goal.decidedAt).toBeNull();
    expect(res.body.goal.reason).toBeNull();
    proposedId = res.body.goal.id;
  });

  it("GET /api/goals lists every status (seeded demo goals included)", async () => {
    const res = await http().get("/api/goals").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const keys = (res.body.goals as { amalKey: string; status: string }[]).map((g) => g.amalKey);
    // the two seeded demo goals of this member ride along
    expect(keys).toEqual(expect.arrayContaining(["tahajjud", "dua_private_10min"]));
    for (const g of res.body.goals as { status: string }[]) {
      expect(["proposed", "approved", "rejected", "completed", "withdrawn"]).toContain(g.status);
    }
  });

  it("head's approval queue carries the member's proposed goals (names, RLS-scoped)", async () => {
    headToken = await signIn(M_HEAD);
    const res = await http().get("/api/usrah/goals").set("Authorization", `Bearer ${headToken}`).expect(200);
    const queue = res.body.queue as { id: string; userId: string; userName: string; status: string }[];
    expect(queue.length).toBeGreaterThan(0);
    const mine = queue.find((q) => q.id === proposedId)!;
    expect(mine).toBeDefined();
    expect(mine.userId).toBe(maleMemberId);
    expect(mine.userName).toBe("রাফিউল ইসলাম");
    expect(mine.status).toBe("proposed");
    // every queue row is a proposed goal of a member the head can see
    for (const q of queue) expect(q.status).toBe("proposed");
  });

  it("the cross-usrah F head's queue never contains male members' goals (RLS scoping)", async () => {
    fHeadToken = await signIn(F_HEAD);
    const res = await http().get("/api/usrah/goals").set("Authorization", `Bearer ${fHeadToken}`).expect(200);
    const queue = res.body.queue as { userId: string }[];
    expect(queue.length).toBeGreaterThan(0); // her own (F) members' goals
    for (const q of queue) expect(q.userId).not.toBe(maleMemberId);
  });

  it("a plain member cannot approve (403 — role floor)", async () => {
    const res = await http()
      .post(`/api/goals/${proposedId}/approve`)
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(403);
    expect(res.body.error).toBeTruthy();
  });

  it("a cross-gender head cannot decide the goal (403)", async () => {
    await http()
      .post(`/api/goals/${proposedId}/approve`)
      .set("Authorization", `Bearer ${fHeadToken}`)
      .expect(403);
  });

  it("head approves → approved + member reminder (kind goal, tomorrow Fajr) + audit row", async () => {
    const res = await http()
      .post(`/api/goals/${proposedId}/approve`)
      .set("Authorization", `Bearer ${headToken}`)
      .expect(200);
    expect(res.body.goal.status).toBe("approved");
    expect(res.body.goal.decidedById).toBe(maleHeadId);
    expect(res.body.goal.decidedAt).toBeTruthy();
    expect(res.body.goal.active).toBe(true);

    // the REMINDER surfaced through the reminders sheet (kind "goal")
    const reminders = (await rls.system((tx) =>
      tx.reminder.findMany({ where: { userId: maleMemberId, kind: "goal" } })
    )) as unknown as { title: string; link: string | null; scheduledAt: Date | null }[];
    const mine = reminders.filter((r) => r.title.includes(MARK));
    expect(mine.length).toBe(1);
    expect(mine[0].title).toContain("লক্ষ্য অনুমোদিত");
    expect(mine[0].link).toBe("amal");
    expect(mine[0].scheduledAt).toBeTruthy();
    const at = mine[0].scheduledAt!.getTime();
    expect(at).toBeGreaterThan(Date.now()); // tomorrow morning — not in the past
    expect(at).toBeLessThan(Date.now() + 48 * 3_600_000);

    // and the mentor action is AUDITED (unlock_day pattern)
    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "approve_goal", targetId: proposedId } })
    );
    expect(audit).toBeTruthy();
    expect((audit!.metaJson as { userId: string }).userId).toBe(maleMemberId);
  });

  it("re-approve is idempotent — no second reminder, same status", async () => {
    const res = await http()
      .post(`/api/goals/${proposedId}/approve`)
      .set("Authorization", `Bearer ${headToken}`)
      .expect(200);
    expect(res.body.goal.status).toBe("approved");
    const count = await rls.system((tx) =>
      tx.reminder.count({ where: { userId: maleMemberId, kind: "goal", title: { contains: MARK } } })
    );
    expect(count).toBe(1);
  });

  it("approve after a terminal decision → 400 (nothing pending)", async () => {
    // reject a second goal first
    const created = await http()
      .post("/api/goals")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ amalKey: "durood_100", title: `${MARK} — বাতিলের জন্য`, startDate: "2025-06-01" })
      .expect(201);
    rejectId = created.body.goal.id;
    await http()
      .post(`/api/goals/${rejectId}/reject`)
      .set("Authorization", `Bearer ${headToken}`)
      .send({ reason: "আগে ফজরের জামাতে যাওয়া শুরু করুন" })
      .expect(200);

    // approving the now-rejected goal is refused
    await http()
      .post(`/api/goals/${rejectId}/approve`)
      .set("Authorization", `Bearer ${headToken}`)
      .expect(400);
  });

  it("member sees the rejection + reason; a terminal goal stays for history (DELETE 400)", async () => {
    const res = await http().get("/api/goals").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const rejected = (res.body.goals as { id: string; status: string; reason: string | null; active: boolean }[]).find(
      (g) => g.id === rejectId
    )!;
    expect(rejected.status).toBe("rejected");
    expect(rejected.reason).toBe("আগে ফজরের জামাতে যাওয়া শুরু করুন");
    expect(rejected.active).toBe(false);

    // history is not deletable by the member
    await http()
      .delete("/api/goals")
      .query({ id: rejectId })
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(400);
  });

  it("the weekly review summary carries the member's approved goals", async () => {
    // the member proposes + the head approves one goal with known entries
    const created = await http()
      .post("/api/goals")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ amalKey: "tahajjud", title: `${MARK} — রিভিউ সারসংক্ষেপ`, target: "প্রতিদিন", startDate: "2025-06-01" })
      .expect(201);
    const goalId = created.body.goal.id;
    await http().post(`/api/goals/${goalId}/approve`).set("Authorization", `Bearer ${headToken}`).expect(200);

    const weekStart = weekStartOf("Asia/Dhaka");
    const res = await http()
      .post("/api/reviews")
      .set("Authorization", `Bearer ${headToken}`)
      .send({ userId: maleMemberId, weekStart, rating: 4, comment: "e2e goal summary" })
      .expect(201);

    const goals = (res.body.review.summary as { goals?: { amalKey: string; title: string; weekPoints: number; weekDays: number }[] }).goals;
    expect(Array.isArray(goals)).toBe(true);
    const mine = goals!.find((g) => g.title.includes(MARK));
    expect(mine).toBeDefined();
    expect(mine!.amalKey).toBe("tahajjud");
    expect(mine!.weekDays).toBeGreaterThanOrEqual(1);
    expect(mine!.weekDays).toBeLessThanOrEqual(7);
    // the member's seeded diary has tahajjud history — points are 0..weekDays
    expect(mine!.weekPoints).toBeGreaterThanOrEqual(0);
    expect(mine!.weekPoints).toBeLessThanOrEqual(mine!.weekDays);
  });

  it("proposed/approved goals stay deletable; the max-14 OPEN cap is enforced", async () => {
    // delete the approved one (allowed — non-terminal)
    await http()
      .delete("/api/goals")
      .query({ id: proposedId })
      .set("Authorization", `Bearer ${memberToken}`)
      .expect(200);

    const res = await http().get("/api/goals").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const openCount = (res.body.goals as { status: string }[]).filter((g) => OPEN.includes(g.status)).length;

    // top the member up to exactly 14 open goals
    for (let i = openCount; i < 14; i++) {
      await http()
        .post("/api/goals")
        .set("Authorization", `Bearer ${memberToken}`)
        .send({ amalKey: "miswak_5", title: `${MARK} ${i}`, startDate: "2025-06-01" })
        .expect(201);
    }
    // the 15th open goal is refused
    const full = await http()
      .post("/api/goals")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ amalKey: "miswak_5", title: `${MARK} overflow`, startDate: "2025-06-01" })
      .expect(400);
    expect(full.body.error).toBe("সর্বোচ্চ ১৪টি লক্ষ্য");

    // a rejected goal does NOT count toward the cap (terminal by design)
    const after = await http().get("/api/goals").set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect((after.body.goals as { status: string }[]).filter((g) => OPEN.includes(g.status)).length).toBe(14);
  });
});
