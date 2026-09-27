// ─────────────────────────────────────────────────────────────────────────────
// Worker application module — AppModule + the BullMQ processors.
//
// Only the worker entrypoints (src/worker.ts and the apps/worker dev twin)
// boot THIS module; the HTTP API boots AppModule directly so no processor
// ever runs inside the request-serving process (documented design in
// app.module.ts / queue.module.ts).
// ─────────────────────────────────────────────────────────────────────────────
import { Module } from "@nestjs/common";
import { AppModule } from "./app.module";
import { WorkerProcessorsModule } from "./queues/processors.module";

@Module({
  imports: [AppModule, WorkerProcessorsModule],
})
export class WorkerAppModule {}
