import { Body, Controller, Get, Param, Post, Query, Req } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { IsIn, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { loadPack } from "../shared/quran";
import { ROLE_RANK } from "../shared/domain";
import type { User } from "../shared/domain";
import { QUIZ_TOKEN_TTL_MS, mintQuizToken } from "./quiz-token";

// ─────────────────────────────────────────────────────────────────────────────
// Task B4 — Ilm content API: course catalog + enrollment progress, quiz
// attempt history, the usrah question board (RLS) and the live-quiz room
// token. Content bodies come from the packages/content packs (same files the
// /api/content/:pack route serves); engagement rows live in Postgres.
// ─────────────────────────────────────────────────────────────────────────────

// ── pack shapes (packages/content/courses.json) ─────────────────────────────

interface CoursePackLesson {
  id: string;
  titleBn: string;
  bodyBn: string;
  minutes: number;
  order?: number;
}
interface CoursePackCourse {
  id: string;
  titleBn: string;
  descBn: string;
  level: string;
  lessons: CoursePackLesson[];
}

async function loadCoursePack(): Promise<CoursePackCourse[]> {
  const data = (await loadPack("courses")) as { courses?: CoursePackCourse[] } | null;
  return Array.isArray(data?.courses) ? data!.courses : [];
}

// ── DTOs ────────────────────────────────────────────────────────────────────

export class AskUsrahQuestionDto {
  @ApiProperty({ example: "তাকদীরের বিশ্বাস কি আমলের ইচ্ছাশক্তি নষ্ট করে?" })
  @IsString({ message: "প্রশ্নটি লিখুন" })
  @IsNotEmpty({ message: "প্রশ্নটি লিখুন" })
  @MinLength(8, { message: "প্রশ্নটি আরেকটু বিস্তারিত লিখুন" })
  @MaxLength(4000)
  question!: string;

  @ApiProperty({ required: false, example: "aqeedah", enum: ["general", "aqeedah", "salah", "quran", "muamalah", "tarbiyah"] })
  @IsOptional()
  @IsIn(["general", "aqeedah", "salah", "quran", "muamalah", "tarbiyah"], { message: "বিষয় ঠিক নয়" })
  category?: string;
}

export class AnswerUsrahQuestionDto {
  @ApiProperty({ example: "না — তাকদীরে বিশ্বাস আমলের উদ্দেশ্য দৃঢ় করে…" })
  @IsString({ message: "উত্তরটি লিখুন" })
  @IsNotEmpty({ message: "উত্তরটি লিখুন" })
  @MaxLength(8000)
  answer!: string;
}

// ── row shapes ──────────────────────────────────────────────────────────────

type EnrollmentRow = { courseId: string; progressJson: unknown; updatedAt: Date };
type QuizAttemptRow = { id: string; quizId: string; score: number; total: number; createdAt: Date };
type UsrahQuestionRow = {
  id: string;
  usrahId: string;
  authorId: string;
  author: { name: string } | null;
  category: string;
  question: string;
  answer: string | null;
  answeredById: string | null;
  answeredBy: { name: string } | null;
  answeredAt: Date | null;
  createdAt: Date;
};

const USRAH_QUESTION_CATEGORIES = ["general", "aqeedah", "salah", "quran", "muamalah", "tarbiyah"] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Courses — public catalog (lesson counts + platform-wide enrollment stats)
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class CoursesService {
  constructor(private readonly rls: RlsService) {}

  /** GET /api/courses — public list (lesson counts + aggregate engagement). */
  async list() {
    const pack = await loadCoursePack();
    // aggregate platform stats only (no PII): counts per course/quiz
    const [enrollCounts, attemptCounts] = await this.rls.system(async (tx) => {
      const enrollments = await tx.enrollment.groupBy({ by: ["courseId"], _count: { _all: true } });
      const attempts = await tx.quizAttempt.groupBy({ by: ["quizId"], _count: { _all: true } });
      return [enrollments, attempts] as const;
    });
    const enrolledBy = new Map(enrollCounts.map((g) => [g.courseId, g._count._all]));
    const attemptsBy = new Map(attemptCounts.map((g) => [g.quizId, g._count._all]));

    return {
      courses: pack.map((c) => {
        const lessons = [...c.lessons].sort((a, b) => (a.order ?? 0) - (b.order ?? 0) || a.id.localeCompare(b.id));
        return {
          id: c.id,
          titleBn: c.titleBn,
          descBn: c.descBn,
          level: c.level,
          lessonCount: lessons.length,
          totalMinutes: lessons.reduce((s, l) => s + l.minutes, 0),
          enrolledCount: enrolledBy.get(c.id) ?? 0,
          attemptedCount: attemptsBy.get(c.id) ?? 0,
        };
      }),
    };
  }

  /** GET /api/courses/:id — course with lesson bodies (public) + my progress. */
  async detail(viewer: User | null, id: string) {
    const pack = await loadCoursePack();
    const c = pack.find((x) => x.id === id);
    if (!c) throw new ApiError(404, "কোর্স পাওয়া যায়নি");

    const lessons = [...c.lessons]
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0) || a.id.localeCompare(b.id))
      .map((l) => ({ id: l.id, titleBn: l.titleBn, bodyBn: l.bodyBn, minutes: l.minutes, order: l.order ?? 0 }));

    let myEnrollment: { progress: unknown; updatedAt: string } | null = null;
    if (viewer && viewer.usrahId !== undefined) {
      // signed-in → own enrollment row (RLS: Enrollment is app_self-scoped)
      const row = (await this.rls.run(viewer, (tx) =>
        tx.enrollment.findUnique({ where: { userId_courseId: { userId: viewer.id, courseId: id } } })
      )) as unknown as EnrollmentRow | null;
      if (row) {
        myEnrollment = { progress: row.progressJson, updatedAt: row.updatedAt.toISOString() };
      }
    }

    const enrolledCount = await this.rls.system((tx) =>
      tx.enrollment.count({ where: { courseId: id } })
    );

    return {
      course: {
        id: c.id,
        titleBn: c.titleBn,
        descBn: c.descBn,
        level: c.level,
        lessonCount: lessons.length,
        totalMinutes: lessons.reduce((s, l) => s + l.minutes, 0),
        lessons,
      },
      enrolledCount,
      myEnrollment,
    };
  }
}

@ApiTags("courses")
@Controller("courses")
export class CoursesController {
  constructor(private readonly service: CoursesService) {}

  @Get()
  @ApiOperation({ summary: "Course catalog with lesson counts + enrollment stats (public)" })
  list() {
    return this.service.list();
  }

  @Get(":id")
  @ApiOperation({ summary: "Course detail with lessons + my progress" })
  detail(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.detail(currentUser(req), id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enrollments + quiz attempts — my history (auth, RLS app_self)
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class EngagementHistoryService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/enrollments — my enrollments with progress. */
  async myEnrollments(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const rows = (await this.rls.run(user, (tx) =>
      tx.enrollment.findMany({ where: { userId: user.id }, orderBy: { updatedAt: "desc" }, take: 100 })
    )) as unknown as EnrollmentRow[];
    return {
      enrollments: rows.map((r) => ({
        courseId: r.courseId,
        progress: r.progressJson,
        updatedAt: r.updatedAt.toISOString(),
      })),
    };
  }

  /** GET /api/quiz-attempts — my attempt history (newest first). */
  async myAttempts(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const rows = (await this.rls.run(user, (tx) =>
      tx.quizAttempt.findMany({ where: { userId: user.id }, orderBy: { createdAt: "desc" }, take: 100 })
    )) as unknown as QuizAttemptRow[];
    return {
      attempts: rows.map((r) => ({
        id: r.id,
        quizId: r.quizId,
        score: r.score,
        total: r.total,
        createdAt: r.createdAt.toISOString(),
      })),
    };
  }
}

@ApiTags("enrollments")
@Controller("enrollments")
export class EnrollmentsController {
  constructor(private readonly service: EngagementHistoryService) {}

  @Get()
  @ApiOperation({ summary: "My course enrollments with progress (login)" })
  list(@Req() req: AuthedRequest) {
    return this.service.myEnrollments(currentUser(req));
  }
}

@ApiTags("quiz-attempts")
@Controller("quiz-attempts")
export class QuizAttemptsController {
  constructor(private readonly service: EngagementHistoryService) {}

  @Get()
  @ApiOperation({ summary: "My quiz attempt history (login)" })
  list(@Req() req: AuthedRequest) {
    return this.service.myAttempts(currentUser(req));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Usrah question board (RLS): members ask, the usrah head answers.
// ─────────────────────────────────────────────────────────────────────────────

function toQuestionDto(r: UsrahQuestionRow) {
  return {
    id: r.id,
    usrahId: r.usrahId,
    authorId: r.authorId,
    authorName: r.author?.name ?? null,
    category: USRAH_QUESTION_CATEGORIES.includes(r.category as (typeof USRAH_QUESTION_CATEGORIES)[number])
      ? r.category
      : "general",
    question: r.question,
    answer: r.answer,
    answeredByName: r.answeredBy?.name ?? null,
    answeredAt: r.answeredAt?.toISOString() ?? null,
    createdAt: r.createdAt.toISOString(),
  };
}

@Injectable()
export class UsrahQuestionsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/usrah-questions — own usrah's board (newest first, 50). */
  async list(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const usrahId = user.usrahId;
    if (!usrahId) return { questions: [] };
    const rows = (await this.rls.run(user, (tx) =>
      tx.usrahQuestion.findMany({
        where: { usrahId },
        orderBy: { createdAt: "desc" },
        take: 50,
        include: { author: { select: { name: true } }, answeredBy: { select: { name: true } } },
      })
    )) as unknown as UsrahQuestionRow[];
    return { questions: rows.map(toQuestionDto) };
  }

  /** POST /api/usrah-questions — a member asks inside their own usrah. */
  async ask(viewer: User | null, dto: AskUsrahQuestionDto) {
    const user = this.guard.requireUser(viewer);
    const usrahId = user.usrahId;
    if (!usrahId) throw new ApiError(400, "উসরায় যুক্ত হয়ে প্রশ্ন করতে পারবেন");
    const question = (dto.question ?? "").toString().trim().slice(0, 4000);
    if (question.length < 8) throw new ApiError(400, "প্রশ্নটি আরেকটু বিস্তারিত লিখুন");

    const row = (await this.rls.run(user, (tx) =>
      tx.usrahQuestion.create({
        data: {
          usrahId,
          authorId: user.id,
          category: dto.category ?? "general",
          question,
        },
        include: { author: { select: { name: true } }, answeredBy: { select: { name: true } } },
      })
    )) as unknown as UsrahQuestionRow;
    return { question: toQuestionDto(row) };
  }

  /** POST /api/usrah-questions/:id/answers — the usrah head answers. */
  async answer(viewer: User | null, id: string, dto: AnswerUsrahQuestionDto) {
    const user = this.guard.requireUser(viewer);
    if (ROLE_RANK[user.role] < ROLE_RANK["usrah_head"]) {
      throw new ApiError(403, "শুধুমাত্র উসরা প্রধান উত্তর দিতে পারবেন");
    }
    const answer = (dto.answer ?? "").toString().trim().slice(0, 8000);
    if (!answer) throw new ApiError(400, "উত্তরটি লিখুন");

    // visibility + head-check in the caller's own RLS context (defense in
    // depth on top of the DB's app_head_answer UPDATE policy)
    const existing = (await this.rls.run(user, (tx) =>
      tx.usrahQuestion.findFirst({ where: { id }, include: { author: { select: { name: true } }, answeredBy: { select: { name: true } } } })
    )) as unknown as UsrahQuestionRow | null;
    if (!existing) throw new ApiError(404, "প্রশ্ন পাওয়া যায়নি");

    const usrah = await this.rls.run(user, (tx) => tx.usrah.findUnique({ where: { id: existing.usrahId } }));
    if (!usrah || (usrah.headUserId !== user.id && user.role !== "full_admin")) {
      throw new ApiError(403, "শুধুমাত্র উসরা প্রধান উত্তর দিতে পারবেন");
    }

    const row = (await this.rls.run(user, (tx) =>
      tx.usrahQuestion.update({
        where: { id },
        data: { answer, answeredById: user.id, answeredAt: new Date(), updatedAt: new Date() },
        include: { author: { select: { name: true } }, answeredBy: { select: { name: true } } },
      })
    )) as unknown as UsrahQuestionRow;
    return { question: toQuestionDto(row) };
  }
}

@ApiTags("usrah-questions")
@Controller("usrah-questions")
export class UsrahQuestionsController {
  constructor(private readonly service: UsrahQuestionsService) {}

  @Get()
  @ApiOperation({ summary: "Own usrah's question board (RLS)" })
  list(@Req() req: AuthedRequest) {
    return this.service.list(currentUser(req));
  }

  @Post()
  @ApiOperation({ summary: "Ask a question inside own usrah (login)" })
  ask(@Body() dto: AskUsrahQuestionDto, @Req() req: AuthedRequest) {
    return this.service.ask(currentUser(req), dto);
  }

  @Post(":id/answers")
  @ApiOperation({ summary: "Answer a question (usrah head, RLS)" })
  answer(@Param("id") id: string, @Body() dto: AnswerUsrahQuestionDto, @Req() req: AuthedRequest) {
    return this.service.answer(currentUser(req), id, dto);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live-quiz room token — HMAC minted for the socket.io mini-service.
// The host is the head of the user's own usrah (usrahs are single-gender, so
// rooms can never mix genders); every member of the usrah joins as player.
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class QuizLiveService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/quiz/live-token?quizId=… — join (or host) an usrah quiz room. */
  async liveToken(viewer: User | null, quizId: string) {
    const user = this.guard.requireUser(viewer);
    // Gender-scoped leaderboards need a real gender — social-created accounts
    // that have not completed the one-time onboarding step must do that first.
    if (user.gender !== "M" && user.gender !== "F") {
      throw new ApiError(400, "আগে প্রোফাইল সম্পূর্ণ করুন (লিঙ্গ নির্বাচন করুন)");
    }
    if (!user.usrahId) throw new ApiError(400, "উসরায় যুক্ত নন — লাইভ কুইজ উসরাভিত্তিক");

    const usrah = await this.rls.run(user, (tx) => tx.usrah.findUnique({ where: { id: user.usrahId! } }));
    if (!usrah) throw new ApiError(400, "উসরা পাওয়া যায়নি");

    const role: "host" | "player" =
      usrah.headUserId === user.id || user.role === "full_admin" ? "host" : "player";

    const firstName = user.name.trim().split(/\s+/)[0] || user.name;
    const exp = Date.now() + QUIZ_TOKEN_TTL_MS;
    const token = mintQuizToken({
      u: user.id,
      s: usrah.id,
      r: role,
      g: user.gender,
      n: firstName,
      m: user.memberCode,
      q: quizId || "",
      e: exp,
    });

    return { token, room: usrah.id, role, quizId: quizId || null, exp };
  }
}

@ApiTags("quiz")
@Controller("quiz")
export class QuizLiveController {
  constructor(private readonly service: QuizLiveService) {}

  @Get("live-token")
  @ApiOperation({ summary: "Live-quiz room token (HMAC, 15 min) for the socket mini-service" })
  token(@Query("quizId") quizId: string | undefined, @Req() req: AuthedRequest) {
    return this.service.liveToken(currentUser(req), (quizId ?? "").toString().slice(0, 80));
  }
}
