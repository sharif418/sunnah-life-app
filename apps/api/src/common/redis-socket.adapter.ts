import type { INestApplication } from "@nestjs/common";
import { IoAdapter } from "@nestjs/platform-socket.io";
import { createAdapter } from "@socket.io/redis-adapter";
import { Server } from "socket.io";
import Redis from "ioredis";

/**
 * socket.io Redis adapter [Phase C/W2h] — broadcast/emits are replicated
 * across every api instance via Redis pub/sub, so `--scale api=N` gives real
 * multi-instance quiz rooms instead of the stock in-memory adapter (where
 * each replica only ever saw its own sockets).
 *
 * NOTE: the gateway's per-room GAME state (scores/timers, quiz.gateway.ts
 * header) still lives in-process — the adapter fixes the SOCKET fan-out,
 * not the room state; quiz rooms remain single-instance until that state
 * is externalized (see the compose comment on the api service).
 */
export class RedisSocketAdapter extends IoAdapter {
  private readonly pub: Redis;
  private readonly sub: Redis;

  constructor(app: INestApplication) {
    super(app);
    // same REDIS_URL the rest of the stack uses (BullMQ, throttler, health) —
    // default matches env.validation's REDIS_URL default.
    const url = process.env.REDIS_URL || "redis://127.0.0.1:6380";
    this.pub = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 });
    this.sub = this.pub.duplicate();
    for (const client of [this.pub, this.sub]) {
      client.on("error", () => {}); // an unhandled 'error' would kill the process
    }
    this.pub.connect().catch(() => {}); // socket.io keeps working over its own retry
    this.sub.connect().catch(() => {});
  }

  override createIOServer(port: number, options?: Record<string, unknown>): Server {
    const io = super.createIOServer(port, options) as Server;
    io.adapter(createAdapter(this.pub, this.sub));
    return io;
  }

  /** Nest shutdown path — also close the pub/sub pair so the process exits. */
  override async close(server: Server): Promise<void> {
    await super.close(server);
    this.pub.disconnect();
    this.sub.disconnect();
  }
}
