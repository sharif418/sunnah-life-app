// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life — BullMQ worker entrypoint (canonical).
//
// Same codebase as the api (spec: "worker — BullMQ workers, same codebase as
// api, separate entrypoint"). Boots the WorkerAppModule (AppModule + the
// processor providers) as a standalone application context (no HTTP), which
// registers the QueueModule queues/schedulers AND consumes the jobs:
//
//   • prayer-push      — nightly 00:05 BD: compute next-day waqt times per
//                        user, store reminder payloads and enqueue delayed
//                        per-waqt FCM pushes (PushService — Task B2).
//   • weekly-reviews   — Saturday 00:05 BD: create this week's pending
//                        WeeklyReviews for every da'ee+ and remind BOTH
//                        parties (in-app Reminder + push); mark old pending
//                        ones overdue.
//   • monthly-report   — 1st of month: generate the Muhasaba PDF report per
//                        member (31-column paper-form layout, Bengali font)
//                        and upload to MinIO when configured.
//   • streaks          — daily: recompute streak caches into Redis.
//
// Runs:  node dist/worker.js        (production / Docker compose `worker` service)
//   or:  bun run start:worker       (dev, from apps/api)
// Env:   REDIS_URL, DATABASE_URL (sunnah_app role), DIRECT_URL, S3_* optional.
//
// apps/worker/ keeps a hot-reload dev twin (bun --hot) that reuses this
// module graph; this file is the compiled, deployable one.
// ─────────────────────────────────────────────────────────────────────────────
import { NestFactory } from "@nestjs/core";
import { Logger } from "@nestjs/common";
import { WorkerAppModule } from "./worker-app.module";
import { QueuesService } from "./queues/queues.service";

async function bootstrap() {
  const logger = new Logger("Worker");
  const app = await NestFactory.createApplicationContext(WorkerAppModule, {
    logger: ["log", "warn", "error"],
  });
  app.enableShutdownHooks();

  // Register the repeatable job schedules (idempotent upserts — BullMQ
  // replaces schedulers by id on every boot via onModuleInit).
  const queues = app.get(QueuesService);
  await queues.registerSchedulers();

  const stats = await queues.stats();
  logger.log(`Worker up — queues: ${JSON.stringify(stats)}`);
  logger.log("Waiting for jobs… (Ctrl+C to stop)");
}

bootstrap().catch((e) => {
  console.error("Worker failed to start:", e);
  process.exit(1);
});
