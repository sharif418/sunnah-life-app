import { Req, Body, Controller, Delete, Get, Post, Query } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { isValidDateKey } from "../shared/amal";

/** Mapped PersonalGoal (no domain type in the web contract — this is it). */
export interface GoalItem {
  id: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string;
  active: boolean;
  createdAt: string;
}

type GoalRow = Omit<GoalItem, "createdAt"> & { createdAt: Date };

function mapGoal(row: GoalRow): GoalItem {
  return { ...row, createdAt: row.createdAt.toISOString() };
}

export class GoalCreateDto {
  @ApiProperty({ example: "tahajjud" })
  @IsString({ message: "আমল নির্বাচন করুন" })
  @IsNotEmpty({ message: "আমল নির্বাচন করুন" })
  amalKey!: string;

  @ApiProperty({ example: "তাহাজ্জুদ নিয়মিত করা" })
  @IsString({ message: "লক্ষ্যের নাম লিখুন" })
  @MaxLength(200)
  title!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  note?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  target?: string;

  @ApiProperty({ example: "2025-06-01" })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: "শুরুর তারিখ ঠিকভাবে দিন (YYYY-MM-DD)" })
  startDate!: string;
}

const MAX_ACTIVE_GOALS = 14;

@ApiTags("amal")
@Controller("goals")
export class GoalsController {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/goals — own active personal goals. */
  @Get()
  @ApiOperation({ summary: "Own active personal goals" })
  async list(@Req() req: AuthedRequest) {
    const user = this.guard.requireUser(currentUser(req));
    const rows = (await this.rls.run(user, (tx) =>
      tx.personalGoal.findMany({ where: { userId: user.id, active: true }, orderBy: { createdAt: "desc" } })
    )) as unknown as GoalRow[];
    return { goals: rows.map(mapGoal) };
  }

  /** POST /api/goals — create (max 14 active). */
  @Post()
  @ApiOperation({ summary: "Create a personal goal (max 14 active)" })
  async create(@Body() dto: GoalCreateDto, @Req() req: AuthedRequest) {
    const user = this.guard.requireUser(currentUser(req));
    const amalKey = (dto.amalKey ?? "").trim();
    const title = (dto.title ?? "").trim().slice(0, 200);
    if (!amalKey) throw new ApiError(400, "আমল নির্বাচন করুন");
    if (!title) throw new ApiError(400, "লক্ষ্যের নাম লিখুন");
    if (!isValidDateKey(dto.startDate)) throw new ApiError(400, "শুরুর তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");

    const activeCount = await this.rls.run(user, (tx) =>
      tx.personalGoal.count({ where: { userId: user.id, active: true } })
    );
    if (activeCount >= MAX_ACTIVE_GOALS) throw new ApiError(400, "সর্বোচ্চ ১৪টি লক্ষ্য");

    const row = (await this.rls.run(user, (tx) =>
      tx.personalGoal.create({
        data: {
          userId: user.id,
          amalKey,
          title,
          note: dto.note?.trim().slice(0, 1000) || null,
          target: dto.target?.toString().trim().slice(0, 200) || null,
          startDate: dto.startDate,
        },
      })
    )) as unknown as GoalRow;
    return { goal: mapGoal(row) };
  }

  /** DELETE /api/goals?id= — remove one of my goals. */
  @Delete()
  @ApiOperation({ summary: "Delete one of my goals" })
  async remove(@Query("id") id: string | undefined, @Req() req: AuthedRequest) {
    const user = this.guard.requireUser(currentUser(req));
    if (!id) throw new ApiError(400, "আইডি দেওয়া হয়নি");
    await this.rls.run(user, (tx) => tx.personalGoal.deleteMany({ where: { id, userId: user.id } }));
    return { ok: true };
  }
}
