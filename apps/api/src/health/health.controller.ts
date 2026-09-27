import { Res, Controller, Get } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { metricsRegistry } from "../common/metrics";
import type { Response } from "express";
import { PrismaService } from "../common/prisma.service";

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  private async checkPostgres(): Promise<boolean> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }

  private async checkRedis(): Promise<boolean> {
    try {
      const { Redis } = await import("ioredis");
      const redis = new Redis(process.env.REDIS_URL || "redis://127.0.0.1:6380", {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
      });
      await redis.connect();
      const pong = await redis.ping();
      redis.disconnect();
      return pong === "PONG";
    } catch {
      return false;
    }
  }

  private async checkMeili(): Promise<"ok" | "absent" | "down"> {
    const host = process.env.MEILI_HOST;
    if (!host) return "absent";
    try {
      const res = await fetch(`${host}/health`, { signal: AbortSignal.timeout(1500) });
      return res.ok ? "ok" : "down";
    } catch {
      return "down";
    }
  }

  private async checkStorage(): Promise<"local" | "s3" | "local-unwritable"> {
    const s3 = !!(process.env.S3_ENDPOINT && process.env.S3_BUCKET && process.env.S3_ACCESS_KEY && process.env.S3_SECRET_KEY);
    if (s3) return "s3";
    const dir = process.env.STORAGE_DIR || "./storage";
    try {
      const fs = await import("fs");
      await fs.promises.mkdir(dir, { recursive: true });
      await fs.promises.access(dir, fs.constants.W_OK);
      return "local";
    } catch {
      return "local-unwritable";
    }
  }

  async health() {
    const [postgres, redis, meili, storage] = await Promise.all([
      this.checkPostgres(),
      this.checkRedis(),
      this.checkMeili(),
      this.checkStorage(),
    ]);
    const healthy = postgres && redis && meili !== "down" && storage !== "local-unwritable";
    return {
      status: healthy ? "ok" : "degraded",
      checks: { postgres, redis, meilisearch: meili, storage },
      uptimeSeconds: Math.round(process.uptime()),
      version: process.env.npm_package_version ?? "1.0.0",
    };
  }
}

@ApiTags("health")
@Controller()
export class HealthController {
  constructor(private readonly service: HealthService) {}

  /** GET /health — PG + Redis + Meili + storage probes (no auth). */
  @Get("health")
  @ApiOperation({ summary: "Liveness/readiness probe" })
  health() {
    return this.service.health();
  }

  /** GET /metrics — Prometheus exposition (no auth in sandbox; guard in prod). */
  @Get("metrics")
  @ApiOperation({ summary: "Prometheus metrics" })
  async metrics(@Res({ passthrough: true }) res: Response) {
    res.setHeader("Content-Type", metricsRegistry.contentType);
    const body = await metricsRegistry.metrics();
    res.send(body);
  }
}
