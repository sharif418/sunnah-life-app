import { Req, Body, Controller, Delete, Get, HttpCode, HttpStatus, Injectable, Param, Post, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { fajrOfNextDay, isValidDateKey, type LockUser } from "../shared/amal";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type { User } from "../shared/domain";

/** Mapped PersonalGoal (no domain type in the web contract — this is it). */
export interface GoalItem {
  id: string;
  userId: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string;
  active: boolean;
  /** Phase C/W4c lifecycle: proposed | approved | rejected | completed | withdrawn. */
  status: string;
  decidedById: string | null;
  decidedAt: string | null;
  reason: string | null;
  createdAt: string;
}

type GoalRow = Omit<GoalItem, "createdAt" | "decidedAt"> & { createdAt: Date; decidedAt: Date | null };

function mapGoal(row: GoalRow): GoalItem {
  return {
    ...row,
    decidedAt: row.decidedAt ? row.decidedAt.toISOString() : null,
    createdAt: row.createdAt.toISOString(),
  };
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

export class GoalRejectDto {
  @ApiProperty({ required: false, example: "আগে ফজরের জামাতে যাওয়া শুরু করুন" })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

const MAX_ACTIVE_GOALS = 14;
/** Non-terminal statuses — the ones that count toward the max-14 cap. */
const OPEN_STATUSES = ["proposed", "approved"];
/** Terminal statuses — the row stays for history (not deletable by the member). */
const TERMINAL_STATUSES = ["rejected", "completed", "withdrawn"];

@Injectable()
export class GoalsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/goals — own goals, every lifecycle status (newest first). */
  async list(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const rows = (await this.rls.run(user, (tx) =>
      tx.personalGoal.findMany({ where: { userId: user.id }, orderBy: { createdAt: "desc" } })
    )) as unknown as GoalRow[];
    return { goals: rows.map(mapGoal) };
  }

  /** POST /api/goals — propose (max 14 non-terminal goals). */
  async create(viewer: User | null, dto: GoalCreateDto) {
    const user = this.guard.requireUser(viewer);
    const amalKey = (dto.amalKey ?? "").trim();
    const title = (dto.title ?? "").trim().slice(0, 200);
    if (!amalKey) throw new ApiError(400, "আমল নির্বাচন করুন");
    if (!title) throw new ApiError(400, "লক্ষ্যের নাম লিখুন");
    if (!isValidDateKey(dto.startDate)) throw new ApiError(400, "শুরুর তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");

    const openCount = await this.rls.run(user, (tx) =>
      tx.personalGoal.count({ where: { userId: user.id, status: { in: OPEN_STATUSES } } })
    );
    if (openCount >= MAX_ACTIVE_GOALS) throw new ApiError(400, "সর্বোচ্চ ১৪টি লক্ষ্য");

    const row = (await this.rls.run(user, (tx) =>
      tx.personalGoal.create({
        data: {
          userId: user.id,
          amalKey,
          title,
          note: dto.note?.trim().slice(0, 1000) || null,
          target: dto.target?.toString().trim().slice(0, 200) || null,
          startDate: dto.startDate,
          status: "proposed",
        },
      })
    )) as unknown as GoalRow;
    return { goal: mapGoal(row) };
  }

  /** DELETE /api/goals?id= — remove one of my non-terminal goals. */
  async remove(viewer: User | null, id: string | undefined) {
    const user = this.guard.requireUser(viewer);
    if (!id) throw new ApiError(400, "আইডি দেওয়া হয়নি");
    const row = (await this.rls.run(user, (tx) =>
      tx.personalGoal.findFirst({ where: { id, userId: user.id } })
    )) as unknown as GoalRow | null;
    if (!row) throw new ApiError(404, "লক্ষ্যটি পাওয়া যায়নি");
    // Terminal rows are history (the mentor's decision trail) — they stay.
    if (TERMINAL_STATUSES.includes(row.status)) {
      throw new ApiError(400, "সিদ্ধান্ত নেওয়া লক্ষ্য ইতিহাসের জন্য সংরক্ষিত — মুছা যাবে না");
    }
    await this.rls.run(user, (tx) => tx.personalGoal.deleteMany({ where: { id, userId: user.id } }));
    return { ok: true };
  }

  /**
   * Shared pre-checks for the mentor decision endpoints: metadata-only
   * existence read (assertCanAccess's own pattern) + the gender/usrah guard,
   * so a cross-scope caller gets the correct 403/404 BEFORE any write. The
   * mutation itself still runs in the caller's own RLS context — PostgreSQL
   * remains the net.
   */
  private async loadForDecision(viewer: User, id: string): Promise<GoalRow> {
    const row = (await this.rls.system((tx) =>
      tx.personalGoal.findUnique({ where: { id } })
    )) as unknown as GoalRow | null;
    if (!row) throw new ApiError(404, "লক্ষ্যটি পাওয়া যায়নি");
    // a head's own goal goes to their own supervisor, like anyone's
    if (row.userId === viewer.id) throw new ApiError(403, "নিজের লক্ষ্যে নিজে সিদ্ধান্ত দেওয়া যায় না");
    await this.guard.assertCanAccess(viewer, row.userId);
    return row;
  }

  /**
   * POST /api/goals/:id/approve — usrah_head+ approves a member's proposed
   * goal. Side effect (the "remind" step of the lifecycle): a Reminder row is
   * created for the member — the title carries the goal, scheduled for Fajr
   * tomorrow morning in the MEMBER's zone — so the existing reminder panel +
   * push infra surface it. Idempotent: re-approving an approved goal is a
   * no-op that never duplicates the reminder.
   */
  async approve(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "লক্ষ্য অনুমোদনের অনুমতি নেই");

    const row = await this.loadForDecision(user, id);
    if (row.status === "approved") return { goal: mapGoal(row) }; // idempotent re-approve
    if (row.status !== "proposed") throw new ApiError(400, "লক্ষ্যটি আর অপেক্ষমাণ নয়");

    const result = await this.rls.run(user, async (tx) => {
      // status guard: another head may have decided between the read above
      // and this write — updateMany only fires on a still-proposed row.
      const res = await tx.personalGoal.updateMany({
        where: { id, status: "proposed" },
        data: { status: "approved", decidedById: user.id, decidedAt: new Date() },
      });
      if (res.count === 0) {
        const cur = (await tx.personalGoal.findUnique({ where: { id } })) as unknown as GoalRow | null;
        if (cur?.status === "approved") return { goal: mapGoal(cur) };
        throw new ApiError(400, "লক্ষ্যটি আর অপেক্ষমাণ নয়");
      }
      const updated = (await tx.personalGoal.findUnique({ where: { id } })) as unknown as GoalRow;

      // The member's reminder — the "remind" step of "set → approve → remind".
      // The caller's RLS context is fine: Reminder's WITH CHECK is
      // sl_visible_user, the same gate reviews.submit passes when it notifies
      // a reviewee.
      const member = await tx.user.findUnique({
        where: { id: row.userId },
        select: { tz: true, lat: true, lng: true, calcMethod: true, madhhab: true },
      });
      await tx.reminder.create({
        data: {
          userId: row.userId,
          kind: "goal",
          title: `লক্ষ্য অনুমোদিত: ${row.title}`.slice(0, 200),
          body: "আপনার উসরা প্রধান লক্ষ্যটি অনুমোদন করেছেন — আজ থেকে শুরু করুন।",
          link: "amal",
          scheduledAt: member
            ? fajrOfNextDay(member as unknown as LockUser)
            : new Date(Date.now() + 24 * 3_600_000),
        },
      });

      return { goal: mapGoal(updated) };
    });

    // Audit the mentor action (unlock_day / create_assessment pattern).
    await this.guard.audit(user.id, "approve_goal", "goal", id, {
      userId: result.goal.userId,
      amalKey: result.goal.amalKey,
    });
    return result;
  }

  /** POST /api/goals/:id/reject — usrah_head+ rejects with an optional note. */
  async reject(viewer: User | null, id: string, dto: GoalRejectDto) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "লক্ষ্য বাতিলের অনুমতি নেই");
    const reason = (dto?.reason ?? "").toString().trim().slice(0, 500) || null;

    const row = await this.loadForDecision(user, id);
    if (row.status === "rejected") return { goal: mapGoal(row) }; // idempotent re-reject
    if (row.status !== "proposed") throw new ApiError(400, "লক্ষ্যটি আর অপেক্ষমাণ নয়");

    const result = await this.rls.run(user, async (tx) => {
      const res = await tx.personalGoal.updateMany({
        where: { id, status: "proposed" },
        data: { status: "rejected", decidedById: user.id, decidedAt: new Date(), reason, active: false },
      });
      if (res.count === 0) {
        const cur = (await tx.personalGoal.findUnique({ where: { id } })) as unknown as GoalRow | null;
        if (cur?.status === "rejected") return { goal: mapGoal(cur) };
        throw new ApiError(400, "লক্ষ্যটি আর অপেক্ষমাণ নয়");
      }
      const updated = (await tx.personalGoal.findUnique({ where: { id } })) as unknown as GoalRow;
      return { goal: mapGoal(updated) };
    });

    // Audit the mentor action (unlock_day / create_assessment pattern).
    await this.guard.audit(user.id, "reject_goal", "goal", id, {
      userId: result.goal.userId,
      amalKey: result.goal.amalKey,
      reason,
    });
    return result;
  }

  /**
   * GET /api/usrah/goals — the approval queue: proposed goals of MY scope
   * (own-usrah members for a head; same-gender for an invigilator; everyone
   * for full_admin). RLS scopes the rows; the queue shows the member's name.
   */
  async queue(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "লক্ষ্য সারণি দেখার অনুমতি নেই");

    const rows = (await this.rls.run(user, (tx) =>
      tx.personalGoal.findMany({
        // own goals go to the viewer's own supervisor, not this queue
        where: { status: "proposed", userId: { not: user.id } },
        orderBy: { createdAt: "asc" },
        take: 200,
        include: { user: { select: { name: true } } },
      })
    )) as unknown as (GoalRow & { user?: { name: string } })[];

    return {
      queue: rows.map((r) => ({ ...mapGoal(r), userName: r.user?.name ?? "ব্যবহারকারী" })),
    };
  }
}

@ApiTags("amal")
@Controller("goals")
@UseGuards(RolesGuard)
export class GoalsController {
  constructor(private readonly service: GoalsService) {}

  /** GET /api/goals — own personal goals (all lifecycle statuses). */
  @Get()
  @ApiOperation({ summary: "Own personal goals (all statuses)" })
  list(@Req() req: AuthedRequest) {
    return this.service.list(currentUser(req));
  }

  /** POST /api/goals — propose a goal for mentor approval (max 14 open). */
  @Post()
  @ApiOperation({ summary: "Propose a personal goal (max 14 open)" })
  create(@Body() dto: GoalCreateDto, @Req() req: AuthedRequest) {
    return this.service.create(currentUser(req), dto);
  }

  /** DELETE /api/goals?id= — remove one of my open goals. */
  @Delete()
  @ApiOperation({ summary: "Delete one of my open goals" })
  remove(@Query("id") id: string | undefined, @Req() req: AuthedRequest) {
    return this.service.remove(currentUser(req), id);
  }

  /** POST /api/goals/:id/approve — usrah_head+ (fires the member reminder). */
  @Post(":id/approve")
  @HttpCode(HttpStatus.OK) // decision action, not a resource creation
  @Roles("usrah_head") // usrah_head and above (heads, invigilators, admin)
  @ApiOperation({ summary: "Approve a proposed goal (usrah_head+)" })
  approve(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.approve(currentUser(req), id);
  }

  /** POST /api/goals/:id/reject — usrah_head+ (optional reason). */
  @Post(":id/reject")
  @HttpCode(HttpStatus.OK) // decision action, not a resource creation
  @Roles("usrah_head") // usrah_head and above
  @ApiOperation({ summary: "Reject a proposed goal (usrah_head+)" })
  reject(@Param("id") id: string, @Body() dto: GoalRejectDto, @Req() req: AuthedRequest) {
    return this.service.reject(currentUser(req), id, dto);
  }
}

@ApiTags("usrah")
@Controller("usrah/goals")
@UseGuards(RolesGuard)
export class UsrahGoalsController {
  constructor(private readonly service: GoalsService) {}

  /** GET /api/usrah/goals — approval queue for the head/invigilator. */
  @Get()
  @Roles("usrah_head") // usrah_head and above; RLS scopes whose goals show up
  @ApiOperation({ summary: "Goal approval queue (usrah_head+)" })
  queue(@Req() req: AuthedRequest) {
    return this.service.queue(currentUser(req));
  }
}
