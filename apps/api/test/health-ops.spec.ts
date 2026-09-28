// ─────────────────────────────────────────────────────────────────────────────
// health-ops.spec.ts (Phase C/W2h) — operations hardening of the infra routes:
//   • GET /health returns HTTP 503 (not just a body flag) when degraded —
//     a dead Meili host must flip the status code load balancers read
//   • GET /health stays 200/ok when optional dependencies are ABSENT
//     (meilisearch "absent" is a healthy state)
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
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  delete process.env.METRICS_TOKEN; // restore env for other suites
  await app.close();
});

describe("GET /health — 503 when degraded (C/W2h)", () => {
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
