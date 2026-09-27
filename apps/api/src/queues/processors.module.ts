// ─────────────────────────────────────────────────────────────────────────────
// Worker-side processor registration (Task B2 fix).
//
// The @Processor() classes must be listed as providers for @nestjs/bullmq's
// discovery to instantiate them — a bare decorated file is never picked up
// (that was the latent Task 3-b bug: the worker booted, registered the
// repeatable schedulers, and then sat idle while queued jobs piled up).
//
// This module is imported ONLY by the worker entrypoints (worker-app.module)
// so the HTTP API process stays processor-free by design; both processes
// still register the queues + schedulers via QueueModule inside AppModule.
// ─────────────────────────────────────────────────────────────────────────────
import { Module } from "@nestjs/common";
import { QueueModule } from "./queue.module";
import { PushModule } from "../push/push.module";
import { ReportsModule } from "../reports/reports.module";
import { LevelsModule } from "../levels/levels.module";
import { PrayerPushProcessor } from "./processors/prayer-push.processor";
import { StreaksProcessor } from "./processors/streaks.processor";
import { WeeklyReviewsProcessor } from "./processors/weekly-reviews.processor";
import { MonthlyReportProcessor } from "./processors/monthly-report.processor";
import { LevelsProcessor } from "./processors/levels.processor";

@Module({
  imports: [QueueModule, PushModule, ReportsModule, LevelsModule], // PushModule: processors deliver via PushService; ReportsModule: monthly PDF service; LevelsModule: nightly auto-promotion engine (B6)
  providers: [
    PrayerPushProcessor,
    StreaksProcessor,
    WeeklyReviewsProcessor,
    MonthlyReportProcessor,
    LevelsProcessor,
  ],
})
export class WorkerProcessorsModule {}
