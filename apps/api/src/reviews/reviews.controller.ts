import { Req, Body, Controller, Get, Post, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import type { Prisma } from "../common/prisma-client";
import { addDays } from "../shared/calendars";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { bdToday, completion7dForUsers, isValidDateKey, ownUsrahIds } from "../shared/amal";
import { computeWeekSummary, mapReview, weekStartOf, type ReviewRow } from "../shared/reviews";
import { ReviewSubmitDto } from "../auth/dto/auth.dto";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type { Gender, Level, User, UserCategory, UsrahMember, WeeklyReview } from "../shared/domain";

@Injectable()
export class ReviewsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /**
   * GET /api/reviews — self: own reviews (newest first).
   * GET /api/reviews?scope=queue — usrah_head+: review queue for scope targets;
   * lazily creates this week's (Saturday-start) pending reviews and marks
   * older pending ones overdue.
   */
  async list(viewer: User | null, scope?: string) {
    const user = this.guard.requireUser(viewer);

    if (scope !== "queue") {
      const rows = (await this.rls.run(user, (tx) =>
        tx.weeklyReview.findMany({
          where: { userId: user.id },
          orderBy: { createdAt: "desc" },
          take: 60,
          include: { reviewer: { select: { name: true } } },
        })
      )) as unknown as (ReviewRow & { reviewer?: { name: string } })[];
      return { reviews: rows.map((r) => mapReview(r, r.reviewer?.name ?? null)) };
    }

    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "রিভিউ সারণি দেখার অনুমতি নেই");

    return this.rls.run(user, async (tx) => {
      // scope targets (RLS keeps the user list gender/usrah-scoped too)
      let targetUsers: {
        id: string; name: string; gender: string; level: string; memberCode: string | null;
        category: string; lastActiveAt: Date;
      }[];
      if (user.role === "full_admin") {
        targetUsers = await tx.user.findMany({
          where: { role: { in: ["daee", "usrah_head"] }, id: { not: user.id } },
        });
      } else if (user.role === "invigilator") {
        targetUsers = await tx.user.findMany({ where: { gender: user.gender, id: { not: user.id } } });
      } else {
        const usrahIds = await ownUsrahIds(tx, user);
        targetUsers = usrahIds.length
          ? await tx.user.findMany({ where: { usrahId: { in: usrahIds }, id: { not: user.id } } })
          : [];
      }

      if (!targetUsers.length) return { queue: [] };
      const targetIds = targetUsers.map((t) => t.id);

      const ws = weekStartOf(new Date());
      const today = bdToday();
      const cutoff = addDays(today, -7);

      // lazily create this week's pending reviews (PG: skipDuplicates is safe)
      const existing = await tx.weeklyReview.findMany({
        where: { weekStart: ws, userId: { in: targetIds } },
        select: { userId: true },
      });
      const have = new Set(existing.map((e) => e.userId));
      const missing = targetUsers.filter((t) => !have.has(t.id));
      if (missing.length) {
        await tx.weeklyReview
          .createMany({
            data: missing.map((t) => ({ userId: t.id, reviewerId: user.id, weekStart: ws, status: "pending" })),
            skipDuplicates: true,
          })
          .catch(() => undefined);
      }

      // older pending reviews (weekStart more than 7 days ago) → overdue
      await tx.weeklyReview.updateMany({
        where: { userId: { in: targetIds }, status: "pending", weekStart: { lt: cutoff } },
        data: { status: "overdue" },
      });

      // actionable queue: current week + anything not done
      const rows = (await tx.weeklyReview.findMany({
        where: { userId: { in: targetIds }, OR: [{ weekStart: ws }, { status: { not: "done" } }] },
        orderBy: [{ weekStart: "desc" }, { createdAt: "desc" }],
        take: 200,
      })) as unknown as ReviewRow[];

      const completions = await completion7dForUsers(
        tx,
        targetUsers.map((t) => ({ id: t.id, category: t.category }))
      );
      const userById = new Map(targetUsers.map((t) => [t.id, t]));
      const reviewerIds = [...new Set(rows.map((r) => r.reviewerId))];
      const reviewers = reviewerIds.length
        ? await tx.user.findMany({ where: { id: { in: reviewerIds } }, select: { id: true, name: true } })
        : [];
      const reviewerNames = new Map(reviewers.map((r) => [r.id, r.name]));

      const queue: (WeeklyReview & { user: UsrahMember })[] = rows.map((r) => {
        const u = userById.get(r.userId);
        const member: UsrahMember = {
          id: r.userId,
          name: u?.name ?? "ব্যবহারকারী",
          gender: (u?.gender ?? "M") as Gender,
          level: (u?.level ?? "none") as Level,
          memberCode: u?.memberCode ?? null,
          category: (u?.category ?? "general") as UserCategory,
          lastActiveAt: (u?.lastActiveAt ?? new Date()).toISOString(),
          completion7d: completions.get(r.userId) ?? 0,
        };
        return { ...mapReview(r, reviewerNames.get(r.reviewerId) ?? null, u?.name ?? null), user: member };
      });

      return { queue };
    });
  }

  /**
   * POST /api/reviews — usrah_head+ completes a weekly review for a member of
   * their scope. Auto-summary computed server-side; the member is notified.
   */
  async submit(viewer: User | null, dto: ReviewSubmitDto) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "রিভিউ জমা দেওয়ার অনুমতি নেই");

    const userId = dto.userId;
    const weekStart = dto.weekStart ?? "";
    const rating = Number(dto.rating);
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!isValidDateKey(weekStart)) {
      throw new ApiError(400, "সপ্তাহের তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new ApiError(400, "রেটিং ১ থেকে ৫ এর মধ্যে হতে হবে");
    }

    const target = await this.guard.assertCanAccess(user, userId);
    const comment = (dto.comment ?? "").toString().trim().slice(0, 4000) || null;
    const nextGoals = (dto.nextGoals ?? "").toString().trim().slice(0, 2000) || null;

    return this.rls.run(user, async (tx: Prisma.TransactionClient) => {
      const summary = await computeWeekSummary(tx, target.id, weekStart);

      const row = (await tx.weeklyReview.upsert({
        where: { userId_weekStart: { userId: target.id, weekStart } },
        create: {
          userId: target.id,
          reviewerId: user.id,
          weekStart,
          summaryJson: summary as never,
          comment,
          rating,
          nextGoals,
          status: "done",
          completedAt: new Date(),
        },
        update: {
          reviewerId: user.id,
          summaryJson: summary as never,
          comment,
          rating,
          nextGoals,
          status: "done",
          completedAt: new Date(),
        },
      })) as unknown as ReviewRow;

      await tx.reminder.create({
        data: {
          userId: target.id,
          kind: "review",
          title: "সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে",
          body: comment ? comment.slice(0, 100) : null,
        },
      });

      return { review: mapReview(row, user.name, target.name) };
    });
  }
}

@ApiTags("reviews")
@Controller("reviews")
@UseGuards(RolesGuard)
export class ReviewsController {
  constructor(private readonly service: ReviewsService) {}

  @Get()
  @ApiOperation({ summary: "Own reviews, or ?scope=queue (supervisor)" })
  list(@Query("scope") scope: string | undefined, @Req() req: AuthedRequest) {
    return this.service.list(currentUser(req), scope);
  }

  @Post()
  @ApiOperation({ summary: "Submit a weekly review (auto-summary server-side)" })
  @Roles("usrah_head") // usrah_head and above (heads, invigilators, admin)
  submit(@Body() dto: ReviewSubmitDto, @Req() req: AuthedRequest) {
    return this.service.submit(currentUser(req), dto);
  }
}
