import { Module } from "@nestjs/common";
import { BullModule } from "@nestjs/bullmq";
import { QUEUES, redisConnectionOptions } from "./queue.constants";
import { QueuesService } from "./queues.service";

/**
 * Queue registration module — used by BOTH apps:
 *  • apps/api AppModule → queues available for enqueue + scheduler registration
 *    (no processors run in the API process)
 *  • apps/worker WorkerModule → processors consume the jobs
 */
@Module({
  imports: [
    BullModule.forRoot({
      connection: redisConnectionOptions(process.env.REDIS_URL || "redis://127.0.0.1:6380"),
    }),
    BullModule.registerQueue(
      { name: QUEUES.PRAYER_PUSH },
      { name: QUEUES.WEEKLY_REVIEWS },
      { name: QUEUES.MONTHLY_REPORT },
      { name: QUEUES.STREAKS }
    ),
  ],
  providers: [QueuesService],
  exports: [QueuesService, BullModule],
})
export class QueueModule {}
