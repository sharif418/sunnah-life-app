import { Body, Controller, Get, Patch, Post, Req } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { IsInt, IsNotEmpty, IsOptional, IsString, Min, MaxLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import type { ReminderItem, User } from "../shared/domain";

// ── DTOs ────────────────────────────────────────────────────────────────────

export class MasalaDto {
  @ApiProperty({ example: "তানভীর হোসেন" })
  @IsString({ message: "আপনার নাম লিখুন" })
  @IsNotEmpty({ message: "আপনার নাম লিখুন" })
  @MaxLength(120)
  name!: string;

  @ApiProperty({ required: false, example: "01000000007" })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiProperty({ example: "মাসনূন আযকার কি সব একসাথে পড়া যায়?" })
  @IsString({ message: "প্রশ্নটি লিখুন" })
  @IsNotEmpty({ message: "প্রশ্নটি লিখুন" })
  @MaxLength(4000)
  question!: string;
}

export class FeedbackDto {
  @ApiProperty()
  @IsString({ message: "আপনার মতামত লিখুন" })
  @IsNotEmpty({ message: "আপনার মতামত লিখুন" })
  @MaxLength(4000)
  message!: string;
}

export class EnrollDto {
  @ApiProperty({ example: "course-tawheed-101" })
  @IsString({ message: "কোর্স নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "কোর্স নির্বাচন করা হয়নি" })
  courseId!: string;
}

export class EnrollProgressDto extends EnrollDto {
  @ApiProperty({ example: "{\"lessonIndex\":2,\"completed\":[1,2]}" })
  @IsString({ message: "প্রোগ্রেস ডেটা ঠিক নয়" })
  progressJson!: string;
}

export class QuizAttemptDto {
  @ApiProperty({ example: "quiz-fiqh-basics" })
  @IsString({ message: "কুইজ নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "কুইজ নির্বাচন করা হয়নি" })
  quizId!: string;

  @ApiProperty({ minimum: 0 })
  @IsInt({ message: "স্কোর ঠিক নয়" })
  @Min(0)
  score!: number;

  @ApiProperty({ minimum: 1 })
  @IsInt({ message: "স্কোর ঠিক নয়" })
  @Min(1)
  total!: number;
}

export class ReadReminderDto {
  @ApiProperty()
  @IsString({ message: "আইডি দেওয়া হয়নি" })
  @IsNotEmpty({ message: "আইডি দেওয়া হয়নি" })
  id!: string;
}

// ── Service ─────────────────────────────────────────────────────────────────

type ReminderRow = {
  id: string; kind: string; title: string; body: string | null; link: string | null;
  scheduledAt: Date | null; read: boolean; createdAt: Date;
};

function toDomain(r: ReminderRow): ReminderItem {
  return {
    ...r,
    scheduledAt: r.scheduledAt?.toISOString() ?? null,
    createdAt: r.createdAt.toISOString(),
  };
}

@Injectable()
export class EngagementService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** POST /api/masala — fiqh question (guests allowed). */
  async masala(viewer: User | null, dto: MasalaDto) {
    const name = (dto.name ?? "").toString().trim().slice(0, 120);
    const question = (dto.question ?? "").toString().trim().slice(0, 4000);
    const phone = (dto.phone ?? "").toString().replace(/[^\d+]/g, "").slice(0, 20) || null;
    if (!name) throw new ApiError(400, "আপনার নাম লিখুন");
    if (!question) throw new ApiError(400, "প্রশ্নটি লিখুন");
    await this.rls.run(viewer ?? null, (tx) =>
      tx.masalaQuestion.create({ data: { userId: viewer?.id ?? null, name, phone, question } })
    );
    return { ok: true };
  }

  /** POST /api/feedback — app feedback (guests allowed). */
  async feedback(viewer: User | null, dto: FeedbackDto) {
    const message = (dto.message ?? "").toString().trim().slice(0, 4000);
    if (!message) throw new ApiError(400, "আপনার মতামত লিখুন");
    await this.rls.run(viewer ?? null, (tx) =>
      tx.feedback.create({ data: { userId: viewer?.id ?? null, message } })
    );
    return { ok: true };
  }

  /** POST /api/enroll — enroll in a course (idempotent). */
  async enroll(viewer: User | null, dto: EnrollDto) {
    const user = this.guard.requireUser(viewer);
    const courseId = (dto.courseId ?? "").trim();
    if (!courseId) throw new ApiError(400, "কোর্স নির্বাচন করা হয়নি");
    await this.rls.run(user, (tx) =>
      tx.enrollment.upsert({
        where: { userId_courseId: { userId: user.id, courseId } },
        create: { userId: user.id, courseId },
        update: {},
      })
    );
    return { ok: true };
  }

  /** PATCH /api/enroll — persist lesson progress. */
  async saveProgress(viewer: User | null, dto: EnrollProgressDto) {
    const user = this.guard.requireUser(viewer);
    const courseId = (dto.courseId ?? "").trim();
    if (!courseId) throw new ApiError(400, "কোর্স নির্বাচন করা হয়নি");
    if (typeof dto.progressJson !== "string" || !dto.progressJson) {
      throw new ApiError(400, "প্রোগ্রেস ডেটা ঠিক নয়");
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(dto.progressJson);
    } catch {
      throw new ApiError(400, "প্রোগ্রেস ডেটা ঠিক নয়");
    }
    await this.rls.run(user, (tx) =>
      tx.enrollment.upsert({
        where: { userId_courseId: { userId: user.id, courseId } },
        create: { userId: user.id, courseId, progressJson: parsed as never },
        update: { progressJson: parsed as never, updatedAt: new Date() },
      })
    );
    return { ok: true };
  }

  /** POST /api/quiz-attempt — guests get 401 (client stores locally). */
  async quizAttempt(viewer: User | null, dto: QuizAttemptDto) {
    const user = this.guard.requireUser(viewer);
    const quizId = (dto.quizId ?? "").trim();
    const score = Number(dto.score);
    const total = Number(dto.total);
    if (!quizId) throw new ApiError(400, "কুইজ নির্বাচন করা হয়নি");
    if (!Number.isInteger(score) || !Number.isInteger(total) || total <= 0 || score < 0 || score > total) {
      throw new ApiError(400, "স্কোর ঠিক নয়");
    }
    await this.rls.run(user, (tx) =>
      tx.quizAttempt.create({ data: { userId: user.id, quizId, score, total } })
    );
    return { ok: true };
  }

  /** GET /api/reminders — own reminders (newest first, 50). */
  async reminders(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const rows = (await this.rls.run(user, (tx) =>
      tx.reminder.findMany({ where: { userId: user.id }, orderBy: { createdAt: "desc" }, take: 50 })
    )) as unknown as ReminderRow[];
    return { reminders: rows.map(toDomain) };
  }

  /** PATCH /api/reminders — mark one read. */
  async readReminder(viewer: User | null, dto: ReadReminderDto) {
    const user = this.guard.requireUser(viewer);
    if (!dto.id) throw new ApiError(400, "আইডি দেওয়া হয়নি");
    await this.rls.run(user, (tx) =>
      tx.reminder.updateMany({ where: { id: dto.id, userId: user.id }, data: { read: true } })
    );
    return { ok: true };
  }
}

// ── Controllers (one REST path each, mirrored from the web API routes) ──────

@ApiTags("masala")
@Controller("masala")
export class MasalaController {
  constructor(private readonly service: EngagementService) {}
  @Post()
  @ApiOperation({ summary: "Ask a fiqh question (guests allowed)" })
  masala(@Body() dto: MasalaDto, @Req() req: AuthedRequest) {
    return this.service.masala(currentUser(req), dto);
  }
}

@ApiTags("feedback")
@Controller("feedback")
export class FeedbackController {
  constructor(private readonly service: EngagementService) {}
  @Post()
  @ApiOperation({ summary: "Send app feedback (guests allowed)" })
  feedback(@Body() dto: FeedbackDto, @Req() req: AuthedRequest) {
    return this.service.feedback(currentUser(req), dto);
  }
}

@ApiTags("enroll")
@Controller("enroll")
export class EnrollController {
  constructor(private readonly service: EngagementService) {}
  @Post()
  @ApiOperation({ summary: "Enroll in a course (idempotent)" })
  enroll(@Body() dto: EnrollDto, @Req() req: AuthedRequest) {
    return this.service.enroll(currentUser(req), dto);
  }
  @Patch()
  @ApiOperation({ summary: "Save course progress JSON" })
  progress(@Body() dto: EnrollProgressDto, @Req() req: AuthedRequest) {
    return this.service.saveProgress(currentUser(req), dto);
  }
}

@ApiTags("quiz-attempt")
@Controller("quiz-attempt")
export class QuizAttemptController {
  constructor(private readonly service: EngagementService) {}
  @Post()
  @ApiOperation({ summary: "Record a quiz attempt (login)" })
  attempt(@Body() dto: QuizAttemptDto, @Req() req: AuthedRequest) {
    return this.service.quizAttempt(currentUser(req), dto);
  }
}

@ApiTags("reminders")
@Controller("reminders")
export class RemindersController {
  constructor(private readonly service: EngagementService) {}
  @Get()
  @ApiOperation({ summary: "Own reminders" })
  list(@Req() req: AuthedRequest) {
    return this.service.reminders(currentUser(req));
  }
  @Patch()
  @ApiOperation({ summary: "Mark a reminder read" })
  read(@Body() dto: ReadReminderDto, @Req() req: AuthedRequest) {
    return this.service.readReminder(currentUser(req), dto);
  }
}
