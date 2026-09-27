import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, audit, requireUser, toDomainUser } from "@/lib/server/auth";
import { assertFullAdmin, errorResponse, json } from "@/lib/server/guard";
import { computeRequirements } from "@/lib/server/levels";
import { LEVEL_LABELS_BN } from "@/types/domain";
import type { Level } from "@/types/domain";

const LEVELS: Level[] = ["none", "muhibbus_sunnah", "farze_ain_1", "farze_ain_2"];

/**
 * POST /api/admin/promote — full_admin promotes a user one level up. For the
 * muhibbus-sunnah promotion the tarbiyah requirements are validated; anything
 * unmet → 422 with the missing requirements in Bengali. Writes a
 * LevelTransition, an audit entry and a reminder for the user.
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    await assertFullAdmin(viewer);

    const body = (await req.json().catch(() => null)) as { userId?: string; toLevel?: string } | null;
    const userId = body?.userId;
    const toLevel = body?.toLevel as Level | undefined;
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!toLevel || !LEVELS.includes(toLevel)) throw new ApiError(400, "স্তর ঠিক নয়");

    const target = await db.user.findUnique({ where: { id: userId } });
    if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
    if (target.level === toLevel) throw new ApiError(400, "ব্যবহারকারী ইতিমধ্যেই এই স্তরে আছেন");

    const fromLevel = target.level;
    const domainUser = toDomainUser(target);

    // requirement validation applies to the muhibbus-sunnah promotion
    if (toLevel === "muhibbus_sunnah") {
      const requirements = await computeRequirements(domainUser);
      const missing = requirements.filter((r) => !r.done);
      if (missing.length) {
        throw new ApiError(422, `চাহিদা পূরণ হয়নি: ${missing.map((r) => r.label).join("; ")}`);
      }
    }

    const now = new Date();
    const updated = await db.user.update({
      where: { id: target.id },
      data: { level: toLevel, levelStartedAt: now },
    });

    await db.levelTransition.create({
      data: {
        userId: target.id,
        fromLevel,
        toLevel,
        evidenceJson: JSON.stringify({
          requirements: (await computeRequirements(toDomainUser(updated))).map((r) => ({ key: r.key, done: r.done })),
          promotedBy: viewer.id,
        }),
      },
    });

    await audit(viewer.id, "promote_level", "user", target.id, { userId: target.id, fromLevel, toLevel });

    await db.reminder.create({
      data: {
        userId: target.id,
        kind: "review",
        title: "আপনি নতুন স্তরে উন্নীত হয়েছেন",
        body: `অভিনন্দন! আপনি এখন ${LEVEL_LABELS_BN[toLevel]} স্তরে আছেন।`,
      },
    });

    return json({ user: toDomainUser(updated) });
  } catch (e) {
    return errorResponse(e);
  }
}
