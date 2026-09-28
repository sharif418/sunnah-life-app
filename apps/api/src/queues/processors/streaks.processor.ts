import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { amalPoints, loadDailyDefinitions } from "../../shared/amal";
import { BD_TZ, todayInTz } from "../../shared/tz";
import { addDays } from "../../shared/calendars";

/**
 * streaks — daily 00:10 BD.
 * Recomputes each member's current diary streak (consecutive days ending
 * today with ≥50% daily-amal completion) into Redis caches
 * (sl:streak:{userId}, TTL 40 days) for fast profile/home reads.
 */
@Processor(QUEUES.STREAKS)
export class StreaksProcessor extends WorkerHost {
  private readonly logger = new Logger(StreaksProcessor.name);

  constructor(private readonly rls: RlsService) {
    super();
  }

  async process(_job: Job): Promise<{ users: number }> {
    const { Redis } = await import("ioredis");
    const redis = new Redis(process.env.REDIS_URL || "redis://127.0.0.1:6380", { maxRetriesPerRequest: 1 });

    try {
      // per-USER day boundaries (Phase C/W1a): each streak is computed against
      // the member's own "today", not a single Dhaka sweep date
      const since = addDays(todayInTz(BD_TZ), -60);

      const result = await this.rls.system(async (tx) => {
        const users = (await tx.user.findMany({
          where: { amalEntries: { some: { date: { gte: since } } } },
          select: { id: true, category: true, tz: true },
        })) as { id: string; category: string; tz: string | null }[];
        const defs = await loadDailyDefinitions(tx);

        let n = 0;
        for (const u of users) {
          const today = todayInTz(u.tz); // the member's own today
          const entries = (await tx.amalEntry.findMany({
            where: { userId: u.id, date: { gte: since }, amalKey: { in: defs.map((d) => d.key) } },
            select: { date: true, amalKey: true, valueJson: true },
          })) as unknown as { date: string; amalKey: string; valueJson: unknown }[];

          // per-day points
          const perDay = new Map<string, number>();
          const defMap = new Map(defs.map((d) => [d.key, d]));
          for (const e of entries) {
            const def = defMap.get(e.amalKey);
            if (!def) continue;
            perDay.set(e.date, (perDay.get(e.date) ?? 0) + amalPoints(e.valueJson, def, u.category));
          }

          // walk back from today while day completion ≥ 50%
          let streak = 0;
          let cursor = today;
          // today counts only if already ≥50%; otherwise start from yesterday
          // (a running day is not punished — same rule as reviews).
          const todayPct = defs.length ? (100 * (perDay.get(today) ?? 0)) / defs.length : 0;
          if (todayPct < 50) cursor = addDays(today, -1);
          while (true) {
            const pct = defs.length ? (100 * (perDay.get(cursor) ?? 0)) / defs.length : 0;
            if (pct >= 50) {
              streak++;
              cursor = addDays(cursor, -1);
            } else break;
          }

          await redis.set(`sl:streak:${u.id}`, streak, "EX", 40 * 86400);
          n++;
        }
        return n;
      });

      this.logger.log(`streaks recomputed for ${result} users (Redis keys sl:streak:*)`);
      return { users: result };
    } finally {
      redis.disconnect();
    }
  }
}
