import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { PushService } from "../../push/push.service";
import { DEEP_LINKS } from "../../push/deep-links";
import { LevelsService } from "../../levels/levels.service";
import type { Level, User } from "../../shared/domain";

/**
 * levels — nightly 00:30 BD (18:30 UTC, scheduler "levels-nightly").
 *
 * Auto-promotion pass (B6): every member (User with a memberCode — the
 * da'ee-membership marker) at level "none" is evaluated against
 * level-rules.json through the SAME pure checklist the member sees in
 * GET /api/dawah/requirements and the admin sees in POST /api/admin/promote.
 * When every machine-checkable rule is met and rules.autoPromote is enabled,
 * the user is promoted to muhibbus_sunnah with method "auto":
 *
 *   • LevelTransition {fromLevel, toLevel, method: "auto", reason} — the
 *     idempotency anchor (a user never transitions twice out of one level)
 *   • User.level + levelStartedAt reset
 *   • AuditLog "promote_level" (meta.method = "auto")
 *   • Reminder "আপনি স্তরে উন্নীত হয়েছেন…"
 *   • PushService fan-out after the RLS transaction commits
 *
 * The informational checklist items (iman/ibadat/… — invigilator-verified by
 * design) never block auto-promotion; only the machine-checkable rules do.
 * farze_ain levels have no rule pack → admin-override only, by design.
 */
@Processor(QUEUES.LEVELS)
export class LevelsProcessor extends WorkerHost {
  private readonly logger = new Logger(LevelsProcessor.name);

  constructor(
    private readonly rls: RlsService,
    private readonly push: PushService,
    private readonly levels: LevelsService
  ) {
    super();
  }

  async process(_job: Job): Promise<{ evaluated: number; promoted: number; skipped: number }> {
    const promotedIds: string[] = [];

    const result = await this.rls.system(async (tx) => {
      // members of the tarbiyah program = users with a memberCode
      const members = (await tx.user.findMany({
        where: { memberCode: { not: null }, level: "none" },
      })) as unknown as User[];

      let promoted = 0;
      let skipped = 0;

      for (const member of members) {
        const { checklist, nextLevel } = await this.levels.evaluate(tx, member);
        // rules apply to the none → muhibbus_sunnah step only (pack scope)
        if (member.level !== "none" || nextLevel !== "muhibbus_sunnah") {
          skipped++;
          continue;
        }
        if (!checklist.autoEligible) {
          skipped++;
          continue;
        }

        const evidence = {
          requirements: checklist.rows.filter((r) => r.autoChecked).map((r) => ({
            key: r.key,
            current: r.current,
            target: r.target,
            met: r.met,
          })),
        };

        const outcome = await this.levels.promoteInTx(tx, member, {
          toLevel: nextLevel as Level,
          method: "auto",
          reason: "স্বয়ংক্রিয় মূল্যায়নে সবগুলো শর্ত পূরণ হয়েছে",
          evidence,
        });
        if (outcome.skipped) {
          skipped++;
          continue;
        }

        // audit entry (same action name as the admin promote; method differs)
        await tx.auditLog.create({
          data: {
            actorId: null,
            action: "promote_level",
            targetType: "user",
            targetId: member.id,
            metaJson: {
              userId: member.id,
              fromLevel: outcome.fromLevel,
              toLevel: nextLevel,
              method: "auto",
            } as never,
          },
        });

        const message = this.levels.promotionMessage(nextLevel as Level);
        await tx.reminder.create({
          data: {
            userId: member.id,
            kind: "review",
            title: message.title,
            body: message.body,
            link: "dawah",
          },
        });

        promoted++;
        promotedIds.push(member.id);
      }

      return { evaluated: members.length, promoted, skipped };
    });

    // ── push fan-out (B2) — own-user messages only, after the commit ────────
    if (promotedIds.length) {
      try {
        await this.push.send(promotedIds, {
          title: "আপনি স্তরে উন্নীত হয়েছেন",
          body: "অভিনন্দন! মুহিব্বুস সুন্নাহ স্তরে উন্নীত হয়েছেন — দাওয়াত ট্যাবে বিস্তারিত দেখুন।",
          deepLink: DEEP_LINKS.dawah,
        });
      } catch (e) {
        this.logger.warn(
          `level-promotion push fan-out failed: ${e instanceof Error ? e.message : e}`
        );
      }
    }

    this.logger.log(
      `levels-nightly: evaluated ${result.evaluated}, promoted ${result.promoted}` +
        (result.promoted ? ` (${promotedIds.join(", ")})` : "")
    );
    return result;
  }
}
