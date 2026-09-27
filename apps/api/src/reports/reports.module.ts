import { Module } from "@nestjs/common";
import { ReportsController } from "./reports.controller";
import { ReportsService } from "./reports.service";

/**
 * Monthly Muhasaba PDF report module (Task B3).
 *
 * Imported by AppModule (HTTP endpoints + service). The BullMQ processor
 * lives in queues/processors/monthly-report.processor.ts and is registered
 * in WorkerProcessorsModule so it only ever runs inside the worker process.
 * StorageService comes from the @Global StorageModule (S3/local adapter).
 */
@Module({
  controllers: [ReportsController],
  providers: [ReportsService],
  exports: [ReportsService],
})
export class ReportsModule {}
