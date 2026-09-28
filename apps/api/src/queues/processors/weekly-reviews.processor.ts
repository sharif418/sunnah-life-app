import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { PushService } from "../../push/push.service";
import { DEEP_LINKS } from "../../push/deep-links";
import { addDays } from "../../shared/calendars";
import { todayInTz } from "../../shared/tz";
import { weekStartOf } from "../../shared/reviews";

/**
 * weekly-reviews — Saturday 00:05 BD.
 * Creates this week's pending WeeklyReviews for every da'ee+ (reviewer =
 * their usrah head, falling back to the first full_admin), reminds BOTH
 * parties and (since B2) PUSHES both parties through PushService. Idempotent:
 * the (userId, weekStart) unique constraint is honored with ON CONFLICT DO
 * NOTHING (Prisma createMany skipDuplicates on PG). Old pending reviews are
 * marked overdue — same rule as the API route.
 *
 * Gender isolation for the head's aggregate push: only members whose gender
 * matches the usrah (and only when the head's own gender matches too) are
 * counted/named — the same single-gender-usrah invariant the RLS policies
 * enforce for token resolution.
 */
@Processor(QUEUES.WEEKLY_REVIEWS)
export class WeeklyReviewsProcessor extends WorkerHost {
  private readonly logger = new Logger(WeeklyReviewsProcessor.name);

  constructor(
    private readonly rls: RlsService,
    private readonly push: PushService
  ) {
    super();
  }

  async process(_job: Job): Promise<{
    weekStart: string;
    created: number;
    overdue: number;
    reminders: number;
    push?: { sent: number; users: number };
  }> {
    // Week starts per reviewed member's zone (Phase C/W1a) — computed per
    // user inside; the BD default covers heads whose members share Dhaka.
    const ws = weekStartOf("Asia/Dhaka");
    const cutoff = addDays(todayInTz("Asia/Dhaka"), -7);

    const result = await this.rls.system(async (tx) => {
      // reviewers: usrah heads; fallback = a SAME-GENDER invigilator —
      // never a cross-gender admin (Phase C/W2e; the old "first admin
      // fallback" could assign reviews of sisters to a male admin).
      const usrahs = await tx.usrah.findMany({
        select: { id: true, headUserId: true, name: true, gender: true },
      });
      const invigilators = await tx.user.findMany({
        where: { role: "invigilator" },
        select: { id: true, name: true, gender: true },
      });
      const invigilatorForGender = new Map<string, { id: string; name: string; gender: string }>();
      for (const inv of invigilators) {
        if (!invigilatorForGender.has(inv.gender)) invigilatorForGender.set(inv.gender, inv);
      }
      const reviewerFor = new Map<string, { id: string; name: string; gender?: string }>();
      for (const u of usrahs) {
        if (!u.headUserId) continue;
        const head = await tx.user.findUnique({
          where: { id: u.headUserId },
          select: { id: true, name: true, gender: true },
        });
        if (head) reviewerFor.set(u.id, head);
      }

      // targets: all daees and heads (grouped under a known reviewer when possible)
      const targets = await tx.user.findMany({
        where: { role: { in: ["daee", "usrah_head"] } },
        select: { id: true, name: true, usrahId: true, gender: true },
      });

      // lazily create this week's pending reviews
      const existing = await tx.weeklyReview.findMany({
        where: { weekStart: ws, userId: { in: targets.map((t) => t.id) } },
        select: { userId: true },
      });
      const have = new Set(existing.map((e) => e.userId));
      const missing = targets.filter((t) => !have.has(t.id));

      let created = 0;
      if (missing.length) {
        const res = await tx.weeklyReview.createMany({
          data: missing.map((t) => {
            // head of the member's usrah → else a same-gender invigilator →
            // else the member themself (self-review flag, surfaced for the
            // admin to assign). A CROSS-GENDER reviewer is never chosen.
            const reviewer =
              (t.usrahId ? reviewerFor.get(t.usrahId) : undefined) ??
              invigilatorForGender.get(t.gender ?? "M");
            return {
              userId: t.id,
              reviewerId: reviewer?.id ?? t.id, // self when no same-gender reviewer exists
              weekStart: ws,
              status: "pending",
            };
          }),
          skipDuplicates: true,
        });
        created = res.count;
      }

      // overdue sweep — older pending reviews
      const overdueRes = await tx.weeklyReview.updateMany({
        where: { status: "pending", weekStart: { lt: cutoff } },
        data: { status: "overdue" },
      });

      // remind both parties for the fresh week
      let reminders = 0;
      const freshMemberIds: string[] = [];
      const headAggregates = new Map<string, string[]>();
      for (const t of missing) {
        const reviewer =
          (t.usrahId ? reviewerFor.get(t.usrahId) : undefined) ??
          invigilatorForGender.get(t.gender ?? "M");
        if (reviewer && reviewer.id !== t.id) {
          await tx.reminder.create({
            data: {
              userId: t.id,
              kind: "review",
              title: "সাপ্তাহিক মুহাসাবা রিভিউ বাকি আছে",
              body: `${ws} সপ্তাহের ডায়েরি রিভিউর জন্য প্রস্তুত করুন।`,
              link: "dawah",
            },
          });
          await tx.reminder.create({
            data: {
              userId: reviewer.id,
              kind: "review",
              title: "এই সপ্তাহের রিভিউ সম্পন্ন করুন",
              body: `${t.name}-এর সাপ্তাহিক রিভিউ জমা দেওয়া বাকি।`,
              link: "dawah",
            },
          });
          reminders += 2;

          // push fan-out bookkeeping (gender-isolated — see class doc)
          freshMemberIds.push(t.id);
          const usrah = t.usrahId ? usrahs.find((u) => u.id === t.usrahId) : undefined;
          if (
            usrah &&
            usrah.gender === t.gender &&
            reviewer.gender === usrah.gender
          ) {
            const names = headAggregates.get(reviewer.id) ?? [];
            names.push(t.name);
            headAggregates.set(reviewer.id, names);
          }
        }
      }

      return {
        created,
        overdue: overdueRes.count,
        reminders,
        freshMemberIds,
        headAggregates: [...headAggregates.entries()].map(([id, names]) => ({ id, names })),
      };
    });

    // ── push fan-out (B2) — worker context; own-user messages only ──────────
    let push: { sent: number; users: number } | undefined;
    try {
      let sent = 0;
      let users = 0;
      if (result.freshMemberIds.length) {
        const out = await this.push.send(
          result.freshMemberIds,
          {
            title: "সাপ্তাহিক মুহাসাবা রিভিউ বাকি আছে",
            body: `${ws} সপ্তাহের ডায়েরি রিভিউর জন্য প্রস্তুত করুন।`,
            deepLink: DEEP_LINKS.reviews,
          }
        );
        sent += out.sent;
        users += out.users;
      }
      for (const head of result.headAggregates) {
        const shown = head.names.slice(0, 3).join(", ");
        const more = head.names.length > 3 ? ` (+${head.names.length - 3})` : "";
        const out = await this.push.send(
          [head.id],
          {
            title: "এই সপ্তাহের রিভিউ সম্পন্ন করুন",
            body: `${shown}-এর সাপ্তাহিক রিভিউ জমা দেওয়া বাকি${more}।`,
            deepLink: DEEP_LINKS.reviews,
          }
        );
        sent += out.sent;
        users += out.users;
      }
      if (sent || users) push = { sent, users };
    } catch (e) {
      this.logger.warn(`review push fan-out failed: ${e instanceof Error ? e.message : e}`);
    }

    this.logger.log(
      `weekly-reviews ${ws}: created ${result.created}, overdue ${result.overdue}, reminders ${result.reminders}` +
        (push ? `, push ${push.sent}/${push.users}` : "")
    );
    return {
      weekStart: ws,
      created: result.created,
      overdue: result.overdue,
      reminders: result.reminders,
      ...(push ? { push } : {}),
    };
  }
}
