// ─────────────────────────────────────────────────────────────────────────────
// Task B4 e2e — ilm content API: course catalog, enrollment progress, quiz
// attempt history, the usrah question board (RLS-proven) and the live-quiz
// room token.
//
// House style: boot the real AppModule (OTP mock sign-in like rls.e2e.spec),
// drive the REAL routes with supertest, and for the privacy-critical board
// additionally query the DATABASE directly through RlsService with the
// acting user's context — no application filter, so the zero-row results
// prove PostgreSQL itself refuses cross-usrah reads/writes.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { verifyQuizToken } from "src/engagement/quiz-token";
import type { User } from "src/shared/domain";

const M_HEAD = "01000000003"; // মাওলানা ইউসুফ — head of উসরা আল-ফুরকান (M)
const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — daee, member of আল-ফুরকান
const F_HEAD = "01000000005"; // উম্মে হাবিবা — head of উসরা আয়েশা সিদ্দিকা (F)
const F_MEMBER = "01000000006"; // মারিয়াম হাসান — daee, member of আয়েশা সিদ্দিকা
const FULL_ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন (no usrah)

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

let adminToken: string;
let maleMemberId: string;
let femaleMemberId: string;
let maleUsrahId: string;
let femaleUsrahId: string; // eslint-disable-line @typescript-eslint/no-unused-vars

/** Full OTP sign-in → access token (mock SMS surfaces devCode). */
async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const verifyRes = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return verifyRes.body.accessToken as string;
}

/** Sign in AND return the domain user row (for direct RlsService contexts). */
async function signInUser(phone: string): Promise<User> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const verifyRes = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return verifyRes.body.user as User;
}

async function userIdByPhone(token: string, phone: string): Promise<string> {
  const res = await http().get(`/api/admin/users?q=${phone}`).set("Authorization", `Bearer ${token}`).expect(200);
  const hit = (res.body.users as { id: string; phone: string | null; usrahId: string | null }[]).find(
    (u) => u.phone === phone
  );
  expect(hit).toBeTruthy();
  return hit!.id;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer());
  rls = app.get(RlsService);

  adminToken = await signIn(FULL_ADMIN);
  maleMemberId = await userIdByPhone(adminToken, M_MEMBER);
  femaleMemberId = await userIdByPhone(adminToken, F_MEMBER);
  maleUsrahId = (await rls.system((tx) => tx.user.findUnique({ where: { id: maleMemberId } })))!.usrahId!;
  femaleUsrahId = (await rls.system((tx) => tx.user.findUnique({ where: { id: femaleMemberId } })))!.usrahId!;
});

afterAll(async () => {
  // Deterministic demo state: the questions this suite created are removed and
  // exactly ONE answered question stays on the male board (UI demo data).
  try {
    await rls.system((tx) =>
      tx.usrahQuestion.deleteMany({ where: { authorId: { in: [maleMemberId, femaleMemberId] } } })
    );
    const maleHeadId = (await rls.system((tx) => tx.user.findUnique({ where: { id: maleMemberId } })))!.referredById!;
    await rls.system((tx) =>
      tx.usrahQuestion.create({
        data: {
          usrahId: maleUsrahId,
          authorId: maleMemberId,
          category: "salah",
          question: "জামাতে দেরি হয়ে গেলে কি একা নামাজ পড়ে নেওয়া উত্তম, নাকি অপেক্ষা করা?",
          answer:
            "যদি জামাত হওয়ার আশা থাকে তবে অপেক্ষা করা উত্তম — হাদীসে ইমামের জন্য অপেক্ষার নির্দেশ এসেছে। তবে ওয়াক্ত শেষ হওয়ার আশঙ্কা থাকলে একাই পড়ে নেওয়া উচিত, যেন কাযা না হয়ে যায়।",
          answeredById: maleHeadId,
          answeredAt: new Date(),
        },
      })
    );
  } finally {
    await app.close();
  }
});

describe("B4 — course catalog + detail (public)", () => {
  it("lists both courses with lesson counts + engagement stats (no auth)", async () => {
    const res = await http().get("/api/courses").expect(200);
    const courses = res.body.courses as {
      id: string;
      lessonCount: number;
      totalMinutes: number;
      enrolledCount: number;
    }[];
    expect(courses).toHaveLength(2);
    expect(courses.map((c) => c.id).sort()).toEqual(["course-aqeedah-basics", "course-salah-fiqh"]);
    for (const c of courses) {
      expect(c.lessonCount).toBe(5);
      expect(c.totalMinutes).toBeGreaterThan(0);
      expect(c.enrolledCount).toBeGreaterThanOrEqual(0);
    }
  });

  it("returns the lesson bodies in the detail route + my progress after enrolling", async () => {
    const token = await signIn(M_MEMBER);
    const detail = await http().get("/api/courses/course-salah-fiqh").expect(200);
    const course = detail.body.course as { lessons: { id: string; titleBn: string; bodyBn: string; minutes: number }[] };
    expect(course.lessons).toHaveLength(5);
    expect(course.lessons[0].bodyBn.length).toBeGreaterThan(120);

    await http().post("/api/enroll").set("Authorization", `Bearer ${token}`).send({ courseId: "course-salah-fiqh" }).expect(201);
    const progress = JSON.stringify({ done: [course.lessons[0].id] });
    await http().patch("/api/enroll").set("Authorization", `Bearer ${token}`).send({ courseId: "course-salah-fiqh", progressJson: progress }).expect(200);

    const withProgress = await http().get("/api/courses/course-salah-fiqh").set("Authorization", `Bearer ${token}`).expect(200);
    expect(withProgress.body.myEnrollment.progress.done).toEqual([course.lessons[0].id]);

    const mine = await http().get("/api/enrollments").set("Authorization", `Bearer ${token}`).expect(200);
    const row = (mine.body.enrollments as { courseId: string; progress: { done: string[] } }[]).find(
      (e) => e.courseId === "course-salah-fiqh"
    );
    expect(row?.progress.done).toEqual([course.lessons[0].id]);
  });

  it("unknown course → Bengali 404", async () => {
    const res = await http().get("/api/courses/nope").expect(404);
    expect(res.body.error).toBe("কোর্স পাওয়া যায়নি");
  });
});

describe("B4 — quiz attempt history", () => {
  it("guest GET → 401", async () => {
    await http().get("/api/quiz-attempts").expect(401);
  });

  it("records an attempt and lists it back (newest first)", async () => {
    const token = await signIn(M_MEMBER);
    await http().post("/api/quiz-attempt").set("Authorization", `Bearer ${token}`).send({ quizId: "quiz-salah", score: 8, total: 10 }).expect(201);
    await http().post("/api/quiz-attempt").set("Authorization", `Bearer ${token}`).send({ quizId: "quiz-salah", score: 10, total: 10 }).expect(201);
    const res = await http().get("/api/quiz-attempts").set("Authorization", `Bearer ${token}`).expect(200);
    const mine = res.body.attempts as { quizId: string; score: number; total: number }[];
    expect(mine.length).toBeGreaterThanOrEqual(2);
    expect(mine[0].score).toBe(10); // newest first
    expect(mine.every((a) => a.quizId === "quiz-salah" || mine.indexOf(a) > 0)).toBe(true);
  });
});

describe("usrah quiz results — the head sees members' scores (RLS read-only)", () => {
  it("a plain member is refused", async () => {
    const token = await signIn(M_MEMBER);
    await http().get("/api/usrah/quiz-results").set("Authorization", `Bearer ${token}`).expect(403);
  });

  it("the male head sees his member's best score; the female head never does", async () => {
    const memberToken = await signIn(M_MEMBER);
    await http().post("/api/quiz-attempt").set("Authorization", `Bearer ${memberToken}`).send({ quizId: "quiz-aqeedah", score: 4, total: 10 }).expect(201);
    await http().post("/api/quiz-attempt").set("Authorization", `Bearer ${memberToken}`).send({ quizId: "quiz-aqeedah", score: 9, total: 10 }).expect(201);

    const headToken = await signIn(M_HEAD);
    const res = await http().get("/api/usrah/quiz-results").set("Authorization", `Bearer ${headToken}`).expect(200);
    expect((res.body.quizzes as { id: string }[]).map((q) => q.id)).toContain("quiz-aqeedah");
    const member = (res.body.members as { id: string; results: { quizId: string; best: number; attempts: number }[] }[]).find(
      (m) => m.id === maleMemberId
    );
    expect(member).toBeTruthy();
    const aqeedah = member!.results.find((r) => r.quizId === "quiz-aqeedah")!;
    expect(aqeedah.best).toBe(9);
    expect(aqeedah.attempts).toBeGreaterThanOrEqual(2);

    const femaleHead = await signIn(F_HEAD);
    const fres = await http().get("/api/usrah/quiz-results").set("Authorization", `Bearer ${femaleHead}`).expect(200);
    expect((fres.body.members as { id: string }[]).some((m) => m.id === maleMemberId)).toBe(false);

    // the database itself refuses: the female head's context reads zero rows
    // of the male member's attempts, and a head cannot write one for him
    const fUser = await signInUser(F_HEAD);
    const leaked = await rls.run(fUser, (tx) => tx.quizAttempt.count({ where: { userId: maleMemberId } }));
    expect(leaked).toBe(0);
    const mHead = await signInUser(M_HEAD);
    await expect(
      rls.run(mHead, (tx) => tx.quizAttempt.create({ data: { userId: maleMemberId, quizId: "quiz-salah", score: 10, total: 10 } }))
    ).rejects.toThrow();
  });
});

describe("B4 — usrah question board (RLS)", () => {
  let maleQuestionId: string;
  let femaleQuestionId: string;

  it("a member asks inside their own usrah (201, author echoed)", async () => {
    const token = await signIn(M_MEMBER);
    const res = await http()
      .post("/api/usrah-questions")
      .set("Authorization", `Bearer ${token}`)
      .send({ question: "তাকদীরের বিশ্বাস কি আমলের ইচ্ছাশক্তি নষ্ট করে দেয়?", category: "aqeedah" })
      .expect(201);
    maleQuestionId = res.body.question.id;
    expect(res.body.question.authorName).toBe("রাফিউল ইসলাম");
    expect(res.body.question.answer).toBeNull();
  });

  it("asks in the F usrah too (for the mirror cases)", async () => {
    const token = await signIn(F_MEMBER);
    const res = await http()
      .post("/api/usrah-questions")
      .set("Authorization", `Bearer ${token}`)
      .send({ question: "মাসিক অবস্থায় ছুটে যাওয়া নামাজের কাযা কীভাবে আদায় করব?", category: "salah" })
      .expect(201);
    femaleQuestionId = res.body.question.id;
  });

  it("the board lists only own-usrah questions", async () => {
    const mToken = await signIn(M_MEMBER);
    const fToken = await signIn(F_HEAD);
    const mRes = await http().get("/api/usrah-questions").set("Authorization", `Bearer ${mToken}`).expect(200);
    const fRes = await http().get("/api/usrah-questions").set("Authorization", `Bearer ${fToken}`).expect(200);
    const mIds = (mRes.body.questions as { id: string }[]).map((q) => q.id);
    const fIds = (fRes.body.questions as { id: string }[]).map((q) => q.id);
    expect(mIds).toContain(maleQuestionId);
    expect(mIds).not.toContain(femaleQuestionId);
    expect(fIds).toContain(femaleQuestionId);
    expect(fIds).not.toContain(maleQuestionId);
  });

  it("DB-level refusal — the F head's context cannot SELECT the male question by primary key", async () => {
    const fHead = await signInUser(F_HEAD);
    const rows = await rls.run(fHead, (tx) =>
      tx.usrahQuestion.findMany({ where: { id: maleQuestionId } })
    );
    expect(rows).toHaveLength(0);
  });

  it("DB-level refusal — a member cannot INSERT into another usrah (RLS WITH CHECK)", async () => {
    const fMember = await signInUser(F_MEMBER);
    await expect(
      rls.run(fMember, (tx) =>
        tx.usrahQuestion.create({
          data: { usrahId: maleUsrahId, authorId: fMember.id, question: "ভেদাবেদ করে ঢোকা যায়?" },
        })
      )
    ).rejects.toThrow();
  });

  it("DB-level refusal — the male MEMBER cannot UPDATE (answer) even his own question", async () => {
    const mMember = await signInUser(M_MEMBER);
    await expect(
      rls.run(mMember, (tx) =>
        tx.usrahQuestion.update({
          where: { id: maleQuestionId },
          data: { answer: "নিজেই লিখে দিলাম", answeredById: mMember.id, answeredAt: new Date() },
        })
      )
    ).rejects.toThrow();
  });

  it("the opposite-gender head cannot answer (404 — the row is invisible to her)", async () => {
    const fToken = await signIn(F_HEAD);
    const res = await http()
      .post(`/api/usrah-questions/${maleQuestionId}/answers`)
      .set("Authorization", `Bearer ${fToken}`)
      .send({ answer: "উত্তর" })
      .expect(404);
    expect(res.body.error).toBe("প্রশ্ন পাওয়া যায়নি");
  });

  it("a plain member cannot answer (403 role floor)", async () => {
    const mToken = await signIn(M_MEMBER);
    const res = await http()
      .post(`/api/usrah-questions/${maleQuestionId}/answers`)
      .set("Authorization", `Bearer ${mToken}`)
      .send({ answer: "আমিই তো জানি" })
      .expect(403);
    expect(res.body.error).toBe("শুধুমাত্র উসরা প্রধান উত্তর দিতে পারবেন");
  });

  it("the OWN usrah head answers (200) and the member sees the answer", async () => {
    const headToken = await signIn(M_HEAD);
    const res = await http()
      .post(`/api/usrah-questions/${maleQuestionId}/answers`)
      .set("Authorization", `Bearer ${headToken}`)
      .send({ answer: "না — তাকদীর জানা আমলের উদ্দেশ্যকে দৃঢ় করে; মানুষ স্বেচ্ছায় বেছে নেয় ও দাযী থাকে।" })
      .expect(201);
    expect(res.body.question.answeredByName).toBe("মাওলানা ইউসুফ");
    expect(res.body.question.answeredAt).toBeTruthy();

    const mToken = await signIn(M_MEMBER);
    const board = await http().get("/api/usrah-questions").set("Authorization", `Bearer ${mToken}`).expect(200);
    const q = (board.body.questions as { id: string; answer: string | null }[]).find((x) => x.id === maleQuestionId);
    expect(q?.answer).toContain("তাকদীর");
  });

  it("short questions and guests are rejected", async () => {
    await http().get("/api/usrah-questions").expect(401);
    const token = await signIn(M_MEMBER);
    await http()
      .post("/api/usrah-questions")
      .set("Authorization", `Bearer ${token}`)
      .send({ question: "ছোট" })
      .expect(400);
  });
});

describe("B4 — live-quiz room token", () => {
  it("guest → 401; admin without usrah → 400", async () => {
    await http().get("/api/quiz/live-token?quizId=quiz-salah").expect(401);
    const admin = await signIn(FULL_ADMIN);
    const res = await http().get("/api/quiz/live-token?quizId=quiz-salah").set("Authorization", `Bearer ${admin}`).expect(400);
    expect(res.body.error).toContain("উসরায় যুক্ত নন");
  });

  it("a member gets a player token that verifies against the same secret", async () => {
    const token = await signIn(M_MEMBER);
    const res = await http()
      .get("/api/quiz/live-token?quizId=quiz-quran-sunnah")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.role).toBe("player");
    expect(res.body.room).toBe(maleUsrahId);

    const payload = verifyQuizToken(res.body.token as string);
    expect(payload).not.toBeNull();
    expect(payload!.u).toBe(maleMemberId);
    expect(payload!.s).toBe(maleUsrahId);
    expect(payload!.r).toBe("player");
    expect(payload!.g).toBe("M");
    expect(payload!.n).toBe("রাফিউল"); // first name only
    expect(payload!.m).toBe("DS-000004");
    expect(payload!.q).toBe("quiz-quran-sunnah");
  });

  it("the usrah head gets the host role; tampered tokens fail verification", async () => {
    const headToken = await signIn(M_HEAD);
    const res = await http().get("/api/quiz/live-token?quizId=quiz-salah").set("Authorization", `Bearer ${headToken}`).expect(200);
    expect(res.body.role).toBe("host");
    expect(verifyQuizToken(`${res.body.token}x`)).toBeNull();
    expect(verifyQuizToken("garbage")).toBeNull();
  });
});

describe("AMOL-17 — a live program can be a scheduled quiz", () => {
  it("admin schedules a quiz program; /api/live carries quizId; an unknown quiz is a 400", async () => {
    const startsAt = new Date(Date.now() + 5 * 86400_000).toISOString();
    const created = await http()
      .post("/api/admin/live")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ titleBn: "পরীক্ষামূলক লাইভ কুইজ", startsAt, quizId: "quiz-aqeedah" })
      .expect(201);
    expect(created.body.program.quizId).toBe("quiz-aqeedah");

    const list = await http().get("/api/live").expect(200);
    const mine = (list.body.programs as { id: string; quizId: string | null }[]).find((p) => p.id === created.body.program.id);
    expect(mine?.quizId).toBe("quiz-aqeedah");

    await http()
      .post("/api/admin/live")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ titleBn: "ভুল কুইজ", startsAt, quizId: "quiz-nope" })
      .expect(400);

    // un-scheduling the quiz keeps the program
    const patched = await http()
      .patch(`/api/admin/live/${created.body.program.id}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ titleBn: "পরীক্ষামূলক লাইভ কুইজ", startsAt, quizId: null }) // the admin form sends the whole program
      .expect(200);
    expect(patched.body.program.quizId).toBeNull();
    await http().delete(`/api/admin/live/${created.body.program.id}`).set("Authorization", `Bearer ${adminToken}`).expect(200);
  });
});
