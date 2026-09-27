import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, isSupervisor, json } from "@/lib/server/guard";
import { addDays } from "@/lib/calendars";
import { bdToday, completion7dForUsers } from "@/lib/server/amal";
import type { AuditEntry, Gender, Role, UsrahHealth } from "@/types/domain";

const INACTIVE_DAYS = 3;
const REVIEW_WINDOW_DAYS = 27; // last 4 Saturday-started weeks

/**
 * GET /api/admin/overview — role-scoped dashboard:
 * usrah_head → own usrahs; invigilator → own-gender usrahs; full_admin → all.
 */
export async function GET() {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "অ্যাডমিন প্যানেল দেখার অনুমতি নেই");

    const usrahRows =
      viewer.role === "full_admin"
        ? await db.usrah.findMany({ include: { members: true }, orderBy: { name: "asc" } })
        : viewer.role === "invigilator"
          ? await db.usrah.findMany({ where: { gender: viewer.gender }, include: { members: true }, orderBy: { name: "asc" } })
          : await db.usrah.findMany({
              where: { OR: [{ headUserId: viewer.id }, ...(viewer.usrahId ? [{ id: viewer.usrahId }] : [])] },
              include: { members: true },
              orderBy: { name: "asc" },
            });

    const scopedUserIds = [...new Set(usrahRows.flatMap((u) => u.members.map((m) => m.id)))];
    const completions = await completion7dForUsers(usrahRows.flatMap((u) => u.members));

    const now = Date.now();
    const inactiveBefore = new Date(now - INACTIVE_DAYS * 86_400_000);
    const weekStartCutoff = addDays(bdToday(), -REVIEW_WINDOW_DAYS);

    const usrahs: UsrahHealth[] = [];
    for (const u of usrahRows) {
      const members = u.members;
      const memberIds = members.map((m) => m.id);
      const doneReviews = memberIds.length
        ? await db.weeklyReview.count({
            where: { userId: { in: memberIds }, status: "done", weekStart: { gte: weekStartCutoff } },
          })
        : 0;
      const expected = members.length * 4;
      const reviewPct = expected > 0 ? Math.min(100, Math.round((100 * doneReviews) / expected)) : 0;
      const avgCompletion = members.length
        ? Math.round(members.reduce((s, m) => s + (completions.get(m.id) ?? 0), 0) / members.length)
        : 0;
      const inactiveCount = members.filter((m) => m.lastActiveAt < inactiveBefore).length;

      usrahs.push({
        id: u.id,
        name: u.name,
        gender: u.gender as Gender,
        district: u.district,
        members: members.length,
        reviewPct,
        avgCompletion,
        inactiveCount,
      });
    }

    const totals = {
      users: scopedUserIds.length,
      daees: await db.user.count({
        where: scopedUserIds.length ? { id: { in: scopedUserIds }, role: "daee" } : { id: "__none__" },
      }),
      usrahs: usrahRows.length,
      pendingReviews: scopedUserIds.length
        ? await db.weeklyReview.count({ where: { userId: { in: scopedUserIds }, status: "pending" } })
        : 0,
    };

    const auditRows = await db.auditLog.findMany({
      where: viewer.role === "full_admin" ? undefined : { actorId: viewer.id },
      orderBy: { createdAt: "desc" },
      take: 15,
    });
    const actorIds = [...new Set(auditRows.map((a) => a.actorId).filter((x): x is string => !!x))];
    const actors = actorIds.length
      ? await db.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true } })
      : [];
    const actorNames = new Map(actors.map((a) => [a.id, a.name]));

    const recentAudit: AuditEntry[] = auditRows.map((a) => {
      let meta: Record<string, unknown> | null = null;
      if (a.metaJson) {
        try {
          meta = JSON.parse(a.metaJson);
        } catch {
          meta = null;
        }
      }
      return {
        id: a.id,
        actorId: a.actorId,
        actorName: a.actorId ? actorNames.get(a.actorId) ?? null : null,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        meta,
        createdAt: a.createdAt.toISOString(),
      };
    });

    return json({ role: viewer.role as Role, totals, usrahs, recentAudit });
  } catch (e) {
    return errorResponse(e);
  }
}
