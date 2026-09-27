import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { addDays } from "../../shared/calendars";
import { bdToday } from "../../shared/amal";
import { weekStartOf } from "../../shared/reviews";

/**
 * weekly-reviews — Saturday 00:05 BD.
 * Creates this week's pending WeeklyReviews for every da'ee+ (reviewer =
 * their usrah head, falling back to the first full_admin) and reminds BOTH
 * parties. Idempotent: the (userId, weekStart) unique constraint is honored
 * with ON CONFLICT DO NOTHING (Prisma createMany skipDuplicates on PG).
 * Old pending reviews are marked overdue — same rule as the API route.
 */
@Processor(QUEUES.WEEKLY_REVIEWS)
export class WeeklyReviewsProcessor extends WorkerHost {
  private readonly logger = new Logger(WeeklyReviewsProcessor.name);

  constructor(private readonly rls: RlsService) {
    super();
  }

  async process(_job: Job): Promise<{ weekStart: string; created: number; overdue: number; reminders: number }> {
    const ws = weekStartOf(new Date());
    const cutoff = addDays(bdToday(), -7);

    const result = await this.rls.system(async (tx) => {
      // reviewers: usrah heads (+ first admin fallback)
      const usrahs = await tx.usrah.findMany({
        select: { id: true, headUserId: true, name: true },
      });
      const admin = await tx.user.findFirst({
        where: { role: "full_admin" },
        select: { id: true, name: true },
      });
      const reviewerFor = new Map<string, { id: string; name: string }>();
      for (const u of usrahs) {
        if (!u.headUserId) continue;
        const head = await tx.user.findUnique({ where: { id: u.headUserId }, select: { id: true, name: true } });
        if (head) reviewerFor.set(u.id, head);
      }

      // targets: all daees and heads (grouped under a known reviewer when possible)
      const targets = await tx.user.findMany({
        where: { role: { in: ["daee", "usrah_head"] } },
        select: { id: true, name: true, usrahId: true },
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
            const reviewer = (t.usrahId ? reviewerFor.get(t.usrahId) : undefined) ?? admin;
            return {
              userId: t.id,
              reviewerId: reviewer?.id ?? t.id, // self when no reviewer exists
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
      for (const t of missing) {
        const reviewer = (t.usrahId ? reviewerFor.get(t.usrahId) : undefined) ?? admin;
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
        }
      }

      return { created, overdue: overdueRes.count, reminders };
    });

    this.logger.log(
      `weekly-reviews ${ws}: created ${result.created}, overdue ${result.overdue}, reminders ${result.reminders}`
    );
    return { weekStart: ws, ...result };
  }
}
