import { Injectable } from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { ApiError } from "../common/api-error";
import {
  buildLevelChecklist,
  gatherLevelFacts,
  loadLevelRules,
  nextLevelOf,
  type LevelChecklist,
  type LevelRules,
} from "../shared/levels";
import { LEVEL_LABELS_BN } from "../shared/domain";
import type { Level, User } from "../shared/domain";

/** The live-checklist payload of GET /api/dawah/requirements. */
export interface LevelRequirementsPayload {
  level: Level;
  nextLevel: Level;
  /** Whether the rules define machine-checkable promotion for this step. */
  rulesApply: boolean;
  /** All machine-checkable rules met (admin promote gate). */
  allMet: boolean;
  /** Nightly auto-promotion will fire (autoPromote enabled + allMet). */
  autoEligible: boolean;
  requirements: LevelChecklist["rows"];
}

/** Bengali justification validator (admin promote / gender change). */
export function requireBengaliReason(reason: unknown): string {
  const text = typeof reason === "string" ? reason.trim() : "";
  if (!text) throw new ApiError(400, "কারণ লিখুন");
  if (text.length < 3) throw new ApiError(400, "কারণ আরও বিস্তারিত লিখুন");
  // at least one Bengali letter — the justification must be readable by members
  if (!/[\u0980-\u09FF]/.test(text)) {
    throw new ApiError(400, "কারণ বাংলায় লিখুন");
  }
  return text.slice(0, 500);
}

/**
 * LevelsService (B6) — the single evaluation + promotion engine shared by:
 *   • GET /api/dawah/requirements (member's live checklist)
 *   • POST /api/admin/promote (manual override, reason required)
 *   • the nightly "levels" BullMQ job (auto-promotion, method "auto")
 *
 * Rule evaluation is factored into the PURE buildLevelChecklist()
 * (src/shared/levels.ts) so the web checklist, the admin validation and the
 * worker can never drift apart.
 */
@Injectable()
export class LevelsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** Evaluate the promotion rules for a user (inside an RLS transaction). */
  async evaluate(
    tx: Prisma.TransactionClient,
    user: User
  ): Promise<{ rules: LevelRules; checklist: LevelChecklist; nextLevel: Level }> {
    const [rules, facts] = await Promise.all([loadLevelRules(), gatherLevelFacts(tx, user)]);
    return { rules, checklist: buildLevelChecklist(rules, facts), nextLevel: nextLevelOf(user.level) };
  }

  /**
   * GET /api/dawah/requirements — the signed-in member's live checklist for
   * their NEXT level (progress chips + auto-promotion hint for the web app).
   */
  async requirementsFor(viewer: User | null): Promise<LevelRequirementsPayload> {
    const user = this.guard.requireUser(viewer);
    return this.rls.run(user, async (tx) => {
      const { checklist, nextLevel } = await this.evaluate(tx, user);
      // rules only gate the none → muhibbus_sunnah step today (pack scope)
      const rulesApply = user.level === "none";
      return {
        level: user.level,
        nextLevel,
        rulesApply,
        allMet: checklist.allMet,
        autoEligible: rulesApply && checklist.autoEligible,
        requirements: checklist.rows,
      };
    });
  }

  /**
   * The one promotion writer (admin override AND nightly auto): idempotent —
   * a user never transitions twice out of the same fromLevel. Writes the
   * LevelTransition (method/reason/actor), resets levelStartedAt and returns
   * the updated domain user. Callers own audit/reminder/push so each flow can
   * batch them appropriately.
   */
  async promoteInTx(
    tx: Prisma.TransactionClient,
    target: User,
    opts: { toLevel: Level; method: "auto" | "admin"; reason?: string | null; actorId?: string | null; evidence?: Record<string, unknown> }
  ): Promise<{ user: User; fromLevel: Level; skipped: false } | { skipped: true }> {
    const existing = await tx.levelTransition.findFirst({
      where: { userId: target.id, fromLevel: target.level },
      select: { id: true },
    });
    if (existing) return { skipped: true };

    const fromLevel = target.level;
    const updated = await tx.user.update({
      where: { id: target.id },
      data: { level: opts.toLevel, levelStartedAt: new Date() },
    });

    await tx.levelTransition.create({
      data: {
        userId: target.id,
        fromLevel,
        toLevel: opts.toLevel,
        method: opts.method,
        reason: opts.reason ?? null,
        actorId: opts.actorId ?? null,
        evidenceJson: (opts.evidence ?? {}) as never,
      },
    });

    return {
      user: {
        ...updated,
        gender: updated.gender as User["gender"],
        role: updated.role as User["role"],
        category: updated.category as User["category"],
        level: updated.level as Level,
        language: updated.language as User["language"],
        madhhab: updated.madhhab as User["madhhab"],
        calcMethod: updated.calcMethod as User["calcMethod"],
        levelStartedAt: updated.levelStartedAt?.toISOString() ?? null,
        createdAt: updated.createdAt.toISOString(),
        lastActiveAt: updated.lastActiveAt.toISOString(),
      },
      fromLevel,
      skipped: false,
    };
  }

  /** Bengali promotion message reused by the reminder + push payloads. */
  promotionMessage(toLevel: Level): { title: string; body: string } {
    return {
      title: "আপনি স্তরে উন্নীত হয়েছেন",
      body: `অভিনন্দন! আপনি এখন ${LEVEL_LABELS_BN[toLevel]} স্তরে আছেন।`,
    };
  }
}
