// BullMQ queue names shared by the API (enqueue/schedulers) and the worker
// (processors). Redis connection comes from REDIS_URL.
export const QUEUES = {
  PRAYER_PUSH: "prayer-push",
  WEEKLY_REVIEWS: "weekly-reviews",
  MONTHLY_REPORT: "monthly-report",
  STREAKS: "streaks",
} as const;

export type QueueName = (typeof QUEUES)[keyof typeof QUEUES];

/**
 * Repeatable job schedules (cron in UTC; Bangladesh = UTC+6):
 *   prayer-push     → nightly 00:05 BD = 18:05 UTC (previous day)
 *   weekly-reviews  → Saturday 00:05 BD = Friday 18:05 UTC
 *   monthly-report  → 1st of month 00:05 BD = 18:05 UTC on the last day of prev month
 *   streaks         → daily 00:10 BD = 18:10 UTC
 */
export const JOB_SCHEDULERS: { id: string; queue: QueueName; pattern: string; name: string }[] = [
  { id: "prayer-push-nightly", queue: QUEUES.PRAYER_PUSH, pattern: "5 18 * * *", name: "prayer-push-nightly" },
  { id: "weekly-reviews-saturday", queue: QUEUES.WEEKLY_REVIEWS, pattern: "5 18 * * 5", name: "weekly-reviews-saturday" },
  { id: "monthly-report-first", queue: QUEUES.MONTHLY_REPORT, pattern: "5 18 1 * *", name: "monthly-report-first" },
  { id: "streaks-daily", queue: QUEUES.STREAKS, pattern: "10 18 * * *", name: "streaks-daily" },
];

/** Parse a redis:// URL into ioredis connection options (for BullMQ). */
export function redisConnectionOptions(url: string): {
  host: string;
  port: number;
  password?: string;
  username?: string;
} {
  try {
    const u = new URL(url);
    return {
      host: u.hostname || "127.0.0.1",
      port: Number(u.port || 6379),
      ...(u.password ? { password: u.password } : {}),
      ...(u.username && u.username !== "default" ? { username: u.username } : {}),
    };
  } catch {
    return { host: "127.0.0.1", port: 6379 };
  }
}
