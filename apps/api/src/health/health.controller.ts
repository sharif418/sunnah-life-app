import { Res, Controller, Get, HttpException, HttpStatus, Req } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { metricsRegistry } from "../common/metrics";
import type { Request, Response } from "express";
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

  /** GET /health — PG + Redis + Meili + storage probes (no auth).
   *  Degraded ⇒ HTTP 503 (load balancers / compose healthchecks can act on
   *  it); the body shape is unchanged for human readers. [C-W2h] */
  @Get("health")
  @ApiOperation({ summary: "Liveness/readiness probe" })
  async health(@Res({ passthrough: true }) res: Response) {
    const body = await this.service.health();
    res.status(body.status === "ok" ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);
    return body;
  }

  /** GET /metrics — Prometheus exposition, internal-only [C-W2h].
   *  Gate: when METRICS_TOKEN is set, callers must present it via
   *  `Authorization: Bearer <token>` or `?token=<token>`; without a token
   *  configured the endpoint is open ONLY outside production (sandbox/dev),
   *  and 403s in production so the registry is never accidentally public. */
  @Get("metrics")
  @ApiOperation({ summary: "Prometheus metrics (internal)" })
  async metrics(@Res({ passthrough: true }) res: Response, @Req() req: Request) {
    const expected = process.env.METRICS_TOKEN;
    if (expected) {
      const header = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
      const raw = req.query.token;
      const query = Array.isArray(raw) ? String(raw[0]) : String(raw ?? "");
      if (header !== expected && query !== expected) {
        throw new HttpException("metrics token required", HttpStatus.FORBIDDEN);
      }
    } else if (process.env.NODE_ENV === "production") {
      // no token configured — refuse in production rather than expose it
      throw new HttpException("metrics disabled", HttpStatus.FORBIDDEN);
    }
    res.setHeader("Content-Type", metricsRegistry.contentType);
    const body = await metricsRegistry.metrics();
    res.send(body);
  }
}
