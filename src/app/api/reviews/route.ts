import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { assertCanAccess, errorResponse, isSupervisor, json } from "@/lib/server/guard";
import { addDays } from "@/lib/calendars";
import { bdToday, completion7dForUsers, isValidDateKey, ownUsrahIds } from "@/lib/server/amal";
import { computeWeekSummary, mapReview, weekStartOf } from "@/lib/server/reviews";
import type { Gender, Level, UserCategory, UsrahMember, WeeklyReview } from "@/types/domain";

/**
 * GET /api/reviews — self: own reviews (newest first).
 * GET /api/reviews?scope=queue — usrah_head+: review queue for scope targets;
 * lazily creates this week's (Saturday-start) pending reviews and marks older
 * pending ones overdue.
 */
export async function GET(req: NextRequest) {
  try {
    const viewer = await requireUser();
    const scope = req.nextUrl.searchParams.get("scope");

    if (scope !== "queue") {
      const rows = await db.weeklyReview.findMany({
        where: { userId: viewer.id },
        orderBy: { createdAt: "desc" },
        take: 60,
        include: { reviewer: { select: { name: true } } },
      });
      return json({ reviews: rows.map((r) => mapReview(r, r.reviewer?.name ?? null)) });
    }

    if (!isSupervisor(viewer)) throw new ApiError(403, "রিভিউ সারণি দেখার অনুমতি নেই");

    // scope targets
    let targetUsers: { id: string; name: string; gender: string; level: string; memberCode: string | null; category: string; lastActiveAt: Date }[];
    if (viewer.role === "full_admin") {
      targetUsers = await db.user.findMany({
        where: { role: { in: ["daee", "usrah_head"] }, id: { not: viewer.id } },
      });
    } else if (viewer.role === "invigilator") {
      targetUsers = await db.user.findMany({ where: { gender: viewer.gender, id: { not: viewer.id } } });
    } else {
      const usrahIds = await ownUsrahIds(viewer);
      targetUsers = usrahIds.length
        ? await db.user.findMany({ where: { usrahId: { in: usrahIds }, id: { not: viewer.id } } })
        : [];
    }

    if (!targetUsers.length) return json({ queue: [] });
    const targetIds = targetUsers.map((t) => t.id);

    const ws = weekStartOf(new Date());
    const today = bdToday();
    const cutoff = addDays(today, -7);

    // lazily create this week's pending reviews
    const existing = await db.weeklyReview.findMany({
      where: { weekStart: ws, userId: { in: targetIds } },
      select: { userId: true },
    });
    const have = new Set(existing.map((e) => e.userId));
    const missing = targetUsers.filter((t) => !have.has(t.id));
    if (missing.length) {
      // NOTE: SQLite Prisma has no skipDuplicates — a rare concurrent double
      // create would violate the unique key, which we tolerate here.
      await db.weeklyReview
        .createMany({
          data: missing.map((t) => ({ userId: t.id, reviewerId: viewer.id, weekStart: ws, status: "pending" })),
        })
        .catch(() => undefined);
    }

    // older pending reviews (weekStart more than 7 days ago) → overdue
    await db.weeklyReview.updateMany({
      where: { userId: { in: targetIds }, status: "pending", weekStart: { lt: cutoff } },
      data: { status: "overdue" },
    });

    // actionable queue: current week + anything not done
    const rows = await db.weeklyReview.findMany({
      where: { userId: { in: targetIds }, OR: [{ weekStart: ws }, { status: { not: "done" } }] },
      orderBy: [{ weekStart: "desc" }, { createdAt: "desc" }],
      take: 200,
    });

    const completions = await completion7dForUsers(targetUsers);
    const userById = new Map(targetUsers.map((t) => [t.id, t]));
    const reviewerIds = [...new Set(rows.map((r) => r.reviewerId))];
    const reviewers = reviewerIds.length
      ? await db.user.findMany({ where: { id: { in: reviewerIds } }, select: { id: true, name: true } })
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

    return json({ queue });
  } catch (e) {
    return errorResponse(e);
  }
}

/**
 * POST /api/reviews — usrah_head+ completes a weekly review for a member of
 * their scope. Auto-summary computed server-side; the member is notified.
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "রিভিউ জমা দেওয়ার অনুমতি নেই");

    const body = (await req.json().catch(() => null)) as {
      userId?: string;
      weekStart?: string;
      comment?: string;
      rating?: number;
      nextGoals?: string;
    } | null;

    const userId = body?.userId;
    const weekStart = body?.weekStart ?? "";
    const rating = Number(body?.rating);
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!isValidDateKey(weekStart)) {
      throw new ApiError(400, "সপ্তাহের তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new ApiError(400, "রেটিং ১ থেকে ৫ এর মধ্যে হতে হবে");
    }

    const target = await assertCanAccess(viewer, userId);
    const comment = (body?.comment ?? "").toString().trim().slice(0, 4000) || null;
    const nextGoals = (body?.nextGoals ?? "").toString().trim().slice(0, 2000) || null;

    const summary = await computeWeekSummary(target.id, weekStart);

    const row = await db.weeklyReview.upsert({
      where: { userId_weekStart: { userId: target.id, weekStart } },
      create: {
        userId: target.id,
        reviewerId: viewer.id,
        weekStart,
        summaryJson: JSON.stringify(summary),
        comment,
        rating,
        nextGoals,
        status: "done",
        completedAt: new Date(),
      },
      update: {
        reviewerId: viewer.id,
        summaryJson: JSON.stringify(summary),
        comment,
        rating,
        nextGoals,
        status: "done",
        completedAt: new Date(),
      },
    });

    await db.reminder.create({
      data: {
        userId: target.id,
        kind: "review",
        title: "সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে",
        body: comment ? comment.slice(0, 100) : null,
      },
    });

    return json({ review: mapReview(row, viewer.name, target.name) });
  } catch (e) {
    return errorResponse(e);
  }
}
