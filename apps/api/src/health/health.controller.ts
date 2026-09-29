import { Res, Controller, Get, HttpException, HttpStatus, Req, Injectable, OnModuleDestroy } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type Redis from "ioredis";
import { metricsRegistry } from "../common/metrics";
import type { Request, Response } from "express";
import { PrismaService } from "../common/prisma.service";

/**
 * Per-check budget [C-W5-ops]: every individual dependency probe must answer
 * well UNDER the orchestrator's curl timeout (Docker HEALTHCHECK and the
 * compose healthchecks use --timeout=5s). 1.5 s per check means a wedged
 * dependency turns the readiness answer into "degraded" fast, never into a
 * curl timeout — the failure mode that made the live staging api flap
 * "unhealthy" while it was serving traffic fine.
 */
const CHECK_TIMEOUT_MS = 1500;

@Injectable()
export class HealthService implements OnModuleDestroy {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * ONE shared Redis connection for every readiness probe [C-W5-ops].
   * The old implementation opened (and tore down) a NEW connection on every
   * /health hit — and Docker polled /health every 15–30 s for the api
   * container's lifetime. This client is created lazily on first use and
   * reused for the process lifetime; ioredis auto-reconnects it if Redis
   * restarts, and commandTimeout bounds any command (or queued command
   * while connecting) at CHECK_TIMEOUT_MS.
   */
  private static redis: Redis | null = null;

  async onModuleDestroy(): Promise<void> {
    HealthService.redis?.disconnect();
    HealthService.redis = null;
  }

  /** Race any check against the per-check budget — a hung TCP peer must
   *  never stretch the readiness answer past the probe timeout. */
  private async budgeted<T>(p: Promise<T>, fallback: T): Promise<T> {
    let timer: NodeJS.Timeout | undefined;
    try {
      return await Promise.race([
        p,
        new Promise<T>((resolve) => {
          timer = setTimeout(() => resolve(fallback), CHECK_TIMEOUT_MS);
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }

  private checkPostgres(): Promise<boolean> {
    return this.budgeted(
      this.prisma.$queryRaw`SELECT 1`.then(
        () => true,
        () => false,
      ),
      false,
    );
  }

  private async checkRedis(): Promise<boolean> {
    try {
      let client = HealthService.redis;
      if (!client || client.status === "end") {
        const { default: RedisCtor } = await import("ioredis");
        client = new RedisCtor(process.env.REDIS_URL || "redis://127.0.0.1:6380", {
          lazyConnect: true,
          maxRetriesPerRequest: 1,
          connectTimeout: CHECK_TIMEOUT_MS,
          commandTimeout: CHECK_TIMEOUT_MS,
        });
        // The probe RESULT carries the signal; an unhandled 'error' event on
        // the shared client would otherwise crash the process.
        client.on("error", () => {});
        HealthService.redis = client;
        await client.connect();
      }
      const pong = await client.ping();
      return pong === "PONG";
    } catch {
      return false;
    }
  }

  private async checkMeili(): Promise<"ok" | "absent" | "down"> {
    const host = process.env.MEILI_HOST;
    if (!host) return "absent";
    try {
      const res = await fetch(`${host}/health`, { signal: AbortSignal.timeout(CHECK_TIMEOUT_MS) });
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

  /** Liveness: the process is up and the event loop turns. NO dependency
   *  calls by design — this is what orchestrators poll (see
   *  HealthController.live). */
  live() {
    return {
      status: "ok" as const,
      uptimeSeconds: Math.round(process.uptime()),
      pid: process.pid,
      version: process.env.npm_package_version ?? "1.0.0",
    };
  }

  /** Readiness: are the dependencies up? For monitoring/alerting — never
   *  wire this into a Docker/compose healthcheck. */
  async readiness() {
    const [postgres, redis, meili, storage] = await Promise.all([
      this.checkPostgres(),
      this.budgeted(this.checkRedis(), false),
      this.checkMeili(),
      this.budgeted(
        this.checkStorage(),
        "local-unwritable" as const,
      ),
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

  /** GET /health/live — LIVENESS probe [C-W5-ops]: process up, event loop
   *  turning. Zero dependency calls — this is what the Docker HEALTHCHECK,
   *  the compose healthchecks and therefore Coolify's Traefik gate on. A
   *  slow/down Postgres must NEVER get a serving container marked unhealthy
   *  and dropped from routing, which is exactly what the combined probe
   *  caused on the live staging deployment. Always 200 while the app can
   *  answer at all. */
  @Get("health/live")
  @ApiOperation({ summary: "Liveness probe (no dependency calls)" })
  live() {
    return this.service.live();
  }

  /** GET /health/ready — READINESS probe [C-W5-ops]: postgres/redis/meili/
   *  storage with per-check budgets, on the shared Redis client. Returns
   *  503 when degraded — point uptime monitors (UptimeRobot, Better
   *  Stack, …) HERE, not at /health/live. */
  @Get("health/ready")
  @ApiOperation({ summary: "Readiness probe (postgres·redis·meili·storage)" })
  async ready(@Res({ passthrough: true }) res: Response) {
    const body = await this.service.readiness();
    res.status(body.status === "ok" ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);
    return body;
  }

  /** GET /health — the original path, kept as a READINESS alias so existing
   *  monitors and the CI compose smoke keep working unchanged [C-W2h].
   *  Orchestrator healthchecks were moved to /health/live — see above. */
  @Get("health")
  @ApiOperation({ summary: "Readiness probe (alias of /health/ready)" })
  async health(@Res({ passthrough: true }) res: Response) {
    const body = await this.service.readiness();
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
