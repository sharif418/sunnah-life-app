import { Logger } from "@nestjs/common";
import { InjectQueue, Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job, Queue } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { ReportsService } from "../../reports/reports.service";
import { bdToday } from "../../shared/amal";
import { toDomainUser } from "../../common/mappers";
import type { User } from "../../shared/domain";

/**
 * monthly-report — 1st of month 00:05 BD (repeatable scheduler in Redis).
 *
 * Two job shapes share this queue:
 *   1. { }               the monthly tick: fan out one job per active member
 *                        (da'ee+ — the tarbiyah membership — plus anyone who
 *                        wrote diary entries that month) for the PREVIOUS
 *                        month, deduplicated by jobId `mr:{userId}:{month}`.
 *   2. { userId, month } the per-member render: load the member, render the
 *                        paper-form PDF through their own RLS context, store
 *                        it (reports/{userId}/{month}.pdf), upsert the
 *                        MonthlyReport row and drop a Reminder telling them
 *                        the report is ready. Idempotent per (userId, month).
 */
@Processor(QUEUES.MONTHLY_REPORT)
export class MonthlyReportProcessor extends WorkerHost {
  private readonly logger = new Logger(MonthlyReportProcessor.name);

  constructor(
    private readonly rls: RlsService,
    private readonly reports: ReportsService,
    @InjectQueue(QUEUES.MONTHLY_REPORT) private readonly queue: Queue
  ) {
    super();
  }

  async process(job: Job): Promise<{ month: string; queued?: number; report?: unknown }> {
    const data = job.data as { userId?: string; month?: string };
    if (data?.userId && data?.month) {
      return this.renderOne(data.userId, data.month);
    }
    return this.fanOut();
  }

  /** Monthly tick → one deduplicated job per active member. */
  private async fanOut(): Promise<{ month: string; queued: number }> {
    const month = previousBdMonth();

    const members = await this.rls.system((tx) =>
      tx.user.findMany({
        where: {
          OR: [
            { role: { in: ["daee", "usrah_head", "invigilator", "full_admin"] } },
            { amalEntries: { some: { date: { startsWith: month } } } },
          ],
        },
        select: { id: true, name: true },
      })
    );

    let queued = 0;
    for (const m of members) {
      try {
        // jobId dedupes: BullMQ refuses a second job with the same id while
        // the first is waiting/active/delayed or within the completed window.
        await this.queue.add(
          "monthly-report-generate",
          { userId: m.id, month },
          {
            jobId: `mr:${m.id}:${month}`,
            attempts: 3,
            backoff: { type: "exponential", delay: 5000 },
            removeOnComplete: { age: 7 * 24 * 3600 },
            removeOnFail: 1000,
          }
        );
        queued += 1;
      } catch (e) {
        this.logger.warn(`enqueue failed for ${m.id.slice(0, 8)}… ${month}: ${e instanceof Error ? e.message : e}`);
      }
    }

    this.logger.log(`monthly-report ${month}: queued ${queued}/${members.length} member jobs`);
    return { month, queued };
  }

  /** Per-member render job. */
  private async renderOne(userId: string, month: string): Promise<{ month: string; report: unknown }> {
    const row = await this.rls.system((tx) => tx.user.findUnique({ where: { id: userId } }));
    if (!row) {
      this.logger.warn(`monthly-report: user ${userId.slice(0, 8)}… vanished — skipping`);
      return { month, report: null };
    }
    const target: User = toDomainUser(row as never);

    // actor = the member: the render reads the diary through the member's
    // own RLS context and the row write passes the self policy. No system
    // context touches any diary data.
    const report = await this.reports.generateForUser(target, month);
    this.logger.log(`monthly-report ${month} ready for ${target.name} (${target.memberCode ?? target.id.slice(0, 8)}…, ${report.byteSize} bytes)`);
    return { month, report };
  }
}

/** Previous month (YYYY-MM) in Bangladesh wall-clock time. */
export function previousBdMonth(): string {
  const [y, m] = bdToday().split("-").map(Number);
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, "0")}`;
}
