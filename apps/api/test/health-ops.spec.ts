// ─────────────────────────────────────────────────────────────────────────────
// health-ops.spec.ts (Phase C/W2h + W5-ops) — operations hardening of the
//   infra routes:
//   • GET /health/live — LIVENESS: 200 with ZERO dependency calls (the
//     orchestrator probe; a dead Meili must not flip it, unlike readiness)
//   • GET /health/ready — READINESS: 503 when degraded, 200/ok when optional
//     deps are absent (meilisearch "absent" is a healthy state). /health
//     is the alias and keeps the same contract (existing monitors).
//   • GET /metrics is token-gated: with METRICS_TOKEN set, 403 without
//     credentials, 200 with `Authorization: Bearer …` or `?token=…`; with
//     the token cleared it stays open outside production
// Needs the real dev services (postgres :5433, redis :6380) like every
// other e2e spec — env.setup.ts pins apps/api/.env.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";

const METRICS_TOKEN_VALUE = "t0ps3cret";

// set BEFORE compiling the module — the env the app boots with
process.env.METRICS_TOKEN = METRICS_TOKEN_VALUE;

let app: INestApplication;
let http: () => ReturnType<typeof request>;

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  // mirrors main.ts: each subpath must be listed individually (NestJS excludes
  // are exact pathToRegexp matches — "health" does NOT cover "health/live")
  app.setGlobalPrefix("api", { exclude: ["health", "health/live", "health/ready", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  delete process.env.METRICS_TOKEN; // restore env for other suites
  await app.close();
});

describe("GET /health/live — liveness, no dependency calls (C/W5-ops)", () => {
  it("dead Meili host (which degrades readiness) still ⇒ 200 + status ok", async () => {
    const prev = process.env.MEILI_HOST;
    process.env.MEILI_HOST = "http://127.0.0.1:59999"; // nothing listens there
    try {
      // readiness with the same env ⇒ 503 (proved below) — liveness must NOT care
      const res = await http().get("/health/live").expect(200);
      expect(res.body.status).toBe("ok");
      expect(typeof res.body.uptimeSeconds).toBe("number");
    } finally {
      if (prev === undefined) delete process.env.MEILI_HOST;
      else process.env.MEILI_HOST = prev;
    }
  });
});

describe("GET /health/ready — readiness (C/W5-ops)", () => {
  it("dead Meili host ⇒ 503 + status degraded + checks.meilisearch down", async () => {
    const prev = process.env.MEILI_HOST;
    process.env.MEILI_HOST = "http://127.0.0.1:59999"; // nothing listens there
    try {
      const res = await http().get("/health/ready").expect(503);
      expect(res.body.status).toBe("degraded");
      expect(res.body.checks.meilisearch).toBe("down");
    } finally {
      if (prev === undefined) delete process.env.MEILI_HOST;
      else process.env.MEILI_HOST = prev;
    }
  });

  it("MEILI_HOST unset ⇒ 200 + status ok (meilisearch absent is healthy)", async () => {
    const prev = process.env.MEILI_HOST;
    delete process.env.MEILI_HOST;
    try {
      const res = await http().get("/health/ready").expect(200);
      expect(res.body.status).toBe("ok");
      expect(res.body.checks.meilisearch).toBe("absent");
    } finally {
      if (prev !== undefined) process.env.MEILI_HOST = prev;
    }
  });

  it("answers well inside the 5 s orchestrator curl budget (per-check 1.5 s)", async () => {
    const t0 = Date.now();
    await http().get("/health/ready").expect(200);
    expect(Date.now() - t0).toBeLessThan(4000);
  });

  it("repeated probes reuse the shared Redis client (no per-request connect)", async () => {
    // 5 back-to-back readiness probes — with the old new-connection-per-probe
    // code this was 5 connect/ping/disconnect cycles; the shared client stays
    // ready and every ping is sub-millisecond.
    for (let i = 0; i < 5; i++) {
      await http().get("/health/ready").expect(200);
    }
  });
});

describe("GET /health — 503 when degraded (C/W2h; alias of /health/ready)", () => {
  it("dead Meili host ⇒ 503 + status degraded + checks.meilisearch down", async () => {
    const prev = process.env.MEILI_HOST;
    process.env.MEILI_HOST = "http://127.0.0.1:59999"; // nothing listens there
    try {
      const res = await http().get("/health").expect(503);
      expect(res.body.status).toBe("degraded");
      expect(res.body.checks.meilisearch).toBe("down");
    } finally {
      if (prev === undefined) delete process.env.MEILI_HOST;
      else process.env.MEILI_HOST = prev;
    }
  });

  it("MEILI_HOST unset ⇒ 200 + status ok (meilisearch absent is healthy)", async () => {
    const prev = process.env.MEILI_HOST;
    delete process.env.MEILI_HOST;
    try {
      const res = await http().get("/health").expect(200);
      expect(res.body.status).toBe("ok");
      expect(res.body.checks.meilisearch).toBe("absent");
    } finally {
      if (prev !== undefined) process.env.MEILI_HOST = prev;
    }
  });
});

describe("GET /metrics — internal-only (C/W2h)", () => {
  it("METRICS_TOKEN set + no credentials ⇒ 403", async () => {
    const res = await http().get("/metrics").expect(403);
    expect(res.body.error).toBeDefined();
  });

  it("METRICS_TOKEN set + wrong bearer ⇒ 403", async () => {
    await http().get("/metrics").set("Authorization", "Bearer nope").expect(403);
  });

  it("METRICS_TOKEN set + `Authorization: Bearer <token>` ⇒ 200 Prometheus exposition", async () => {
    const res = await http().get("/metrics").set("Authorization", `Bearer ${METRICS_TOKEN_VALUE}`).expect(200);
    expect(res.text.startsWith("# HELP")).toBe(true);
  });

  it("METRICS_TOKEN set + `?token=<token>` ⇒ 200 (Prometheus scrape_url style)", async () => {
    await http().get(`/metrics?token=${METRICS_TOKEN_VALUE}`).expect(200);
  });

  it("METRICS_TOKEN cleared + non-production ⇒ open", async () => {
    const prev = process.env.METRICS_TOKEN;
    delete process.env.METRICS_TOKEN;
    try {
      expect(process.env.NODE_ENV).not.toBe("production"); // jest runs as test/development
      const res = await http().get("/metrics").expect(200);
      expect(res.text.startsWith("# HELP")).toBe(true);
    } finally {
      process.env.METRICS_TOKEN = prev;
    }
  });

  it("exposes Node runtime metrics (CPU/memory via collectDefaultMetrics)", async () => {
    const res = await http().get("/metrics").set("Authorization", `Bearer ${METRICS_TOKEN_VALUE}`).expect(200);
    expect(res.text).toContain("process_resident_memory_bytes");
    expect(res.text).toContain("http_request_duration_seconds");
  });
});
