import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";
import { computeRequirements, monthsInLevelOf, nextLevelOf } from "@/lib/server/levels";
import type { AssessmentSummary, DownlineNode, Gender, Level } from "@/types/domain";

/** GET /api/dawah — the da'ee's own dawah dashboard (daee and above). */
export async function GET() {
  try {
    const user = await requireUser();
    if (!["daee", "usrah_head", "invigilator", "full_admin"].includes(user.role)) {
      throw new ApiError(403, "এই অংশটি দায়ী ও তত্ত্বাবধায়কদের জন্য");
    }

    const memberCode = user.memberCode ?? "";
    const invitedCount = await db.user.count({ where: { referredById: user.id } });

    // downline (depth 1..3) via referral closure — ReferralClosure has no FK
    // relation to User, so we join manually.
    const closures = await db.referralClosure.findMany({
      where: { ancestorId: user.id, depth: { gte: 1, lte: 3 } },
    });
    const descendantIds = [...new Set(closures.map((c) => c.descendantId))];
    const downlineUsers = descendantIds.length
      ? await db.user.findMany({ where: { id: { in: descendantIds } } })
      : [];
    const byId = new Map(downlineUsers.map((u) => [u.id, u]));
    const downline: DownlineNode[] = [];
    for (const c of closures) {
      const u = byId.get(c.descendantId);
      if (!u) continue;
      downline.push({
        id: u.id,
        name: u.name,
        gender: u.gender as Gender,
        level: u.level as Level,
        memberCode: u.memberCode,
        depth: c.depth,
        lastActiveAt: u.lastActiveAt.toISOString(),
        joinedAt: u.createdAt.toISOString(),
      });
    }
    downline.sort((a, b) => a.depth - b.depth || a.name.localeCompare(b.name, "bn"));

    const requirements = await computeRequirements(user);

    // assessment summaries with score %
    const assessmentRows = await db.assessment.findMany({
      where: { assesseeId: user.id },
      orderBy: { createdAt: "desc" },
    });
    const assessments: AssessmentSummary[] = assessmentRows.map((a) => {
      let scores: Record<string, { score?: number }> = {};
      try {
        scores = JSON.parse(a.scoresJson);
      } catch {
        scores = {};
      }
      const vals = Object.values(scores);
      const sum = vals.reduce((s, v) => s + (v?.score ?? 0), 0);
      const scorePct = vals.length ? Math.round((100 * sum) / (2 * vals.length)) : null;
      return {
        id: a.id,
        templateKey: a.templateKey,
        result: a.result as AssessmentSummary["result"],
        createdAt: a.createdAt.toISOString(),
        assessorSignedAt: a.assessorSignedAt?.toISOString() ?? null,
        assesseeSignedAt: a.assesseeSignedAt?.toISOString() ?? null,
        participantCategory: a.participantCategory,
        scorePct,
      };
    });

    return json({
      memberCode,
      referralLink: memberCode ? `https://sunnahlife.app/?join=${memberCode}` : "",
      invitedCount,
      downline,
      level: user.level,
      levelStartedAt: user.levelStartedAt,
      monthsInLevel: monthsInLevelOf(user),
      requirements,
      nextLevel: nextLevelOf(user.level),
      assessments,
    });
  } catch (e) {
    return errorResponse(e);
  }
}
