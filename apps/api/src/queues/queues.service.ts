import { Injectable, Logger, type OnModuleInit } from "@nestjs/common";
import { InjectQueue } from "@nestjs/bullmq";
import { Queue } from "bullmq";
import { JOB_SCHEDULERS, QUEUES } from "./queue.constants";

/**
 * Registers the repeatable jobs (BullMQ job schedulers, persisted in Redis).
 * Idempotent — upsertJobScheduler by scheduler id — so both the API and the
 * worker can call it safely.
 */
@Injectable()
export class QueuesService implements OnModuleInit {
  private readonly logger = new Logger(QueuesService.name);

  constructor(
    @InjectQueue(QUEUES.PRAYER_PUSH) private readonly prayerPush: Queue,
    @InjectQueue(QUEUES.WEEKLY_REVIEWS) private readonly weeklyReviews: Queue,
    @InjectQueue(QUEUES.MONTHLY_REPORT) private readonly monthlyReport: Queue,
    @InjectQueue(QUEUES.STREAKS) private readonly streaks: Queue
  ) {}

  private queueByName(name: string): Queue | null {
    switch (name) {
      case QUEUES.PRAYER_PUSH: return this.prayerPush;
      case QUEUES.WEEKLY_REVIEWS: return this.weeklyReviews;
      case QUEUES.MONTHLY_REPORT: return this.monthlyReport;
      case QUEUES.STREAKS: return this.streaks;
      default: return null;
    }
  }

  async onModuleInit(): Promise<void> {
    await this.registerSchedulers();
  }

  async registerSchedulers(): Promise<void> {
    const registered: string[] = [];
    for (const scheduler of JOB_SCHEDULERS) {
      const queue = this.queueByName(scheduler.queue);
      if (!queue) continue;
      try {
        await queue.upsertJobScheduler(
          scheduler.id,
          { pattern: scheduler.pattern, tz: "UTC" },
          { name: scheduler.name, data: {} }
        );
        registered.push(`${scheduler.id}(${scheduler.pattern} UTC)`);
      } catch (e) {
        this.logger.warn(
          `Could not register scheduler ${scheduler.id}: ${e instanceof Error ? e.message : e}`
        );
      }
    }
    if (registered.length) {
      this.logger.log(`Repeatable jobs registered → ${registered.join(", ")}`);
    }
  }

  /** Queue stats for observability (used by worker boot log + health). */
  async stats(): Promise<Record<string, { waiting: number; active: number; delayed: number; failed: number }>> {
    const out: Record<string, { waiting: number; active: number; delayed: number; failed: number }> = {};
    for (const q of [this.prayerPush, this.weeklyReviews, this.monthlyReport, this.streaks]) {
      try {
        const counts = await q.getJobCounts("waiting", "active", "delayed", "failed");
        out[q.name] = {
          waiting: counts.waiting ?? 0,
          active: counts.active ?? 0,
          delayed: counts.delayed ?? 0,
          failed: counts.failed ?? 0,
        };
      } catch {
        out[q.name] = { waiting: -1, active: -1, delayed: -1, failed: -1 };
      }
    }
    return out;
  }
}
