// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life — BullMQ worker entrypoint.
//
// Same codebase as apps/api (spec: "worker — BullMQ workers, same codebase as
// api, separate entrypoint"). Boots the WorkerAppModule (AppModule +
// processors) as a standalone
// application context (no HTTP), which registers the QueueModule processors:
//
//   • prayer-push      — nightly 00:05 BD: compute next-day waqt times per
//                        user and enqueue/store reminder payloads (FCM seam).
//   • weekly-reviews   — Saturday 00:05 BD: create this week's pending
//                        WeeklyReviews for every da'ee+ and remind both
//                        parties; mark old pending ones overdue.
//   • monthly-report   — 1st of month: generate the Muhasaba PDF report per
//                        member (31-column paper-form layout, Bengali font)
//                        and upload to MinIO when configured.
//   • streaks          — daily: recompute streak caches into Redis.
//
// Run:  cd apps/api && bun install   # shared deps (workspace link)
//       cd apps/worker && bun run start
// Env:  REDIS_URL, DATABASE_URL (sunnah_app role), DIRECT_URL, S3_* optional.
// ─────────────────────────────────────────────────────────────────────────────
import { NestFactory } from "@nestjs/core";
import { Logger } from "@nestjs/common";
import { WorkerAppModule } from "../../api/src/worker-app.module";
import { QueuesService } from "../../api/src/queues/queues.service";

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
