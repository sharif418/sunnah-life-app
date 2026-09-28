// ─────────────────────────────────────────────────────────────────────────────
// docs-gating.spec.ts (Phase C/W2h) — the Swagger UI / OpenAPI document must
// not be public knowledge by default:
//   • docsEnabled(env) — the pure gate (DOCS_ENABLED=false kills it anywhere;
//     unset ⇒ non-production only; explicit opt-in works in production)
//   • the route registration itself — an app booted WITHOUT setupSwagger
//     404s on /docs and /openapi.json; with it (gate open) they serve 200.
// The gate is applied at BOOT time (main.ts), so this spec mirrors exactly
// what main.ts does: `if (docsEnabled(process.env)) setupSwagger(app)`.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { docsEnabled, setupSwagger } from "src/common/swagger-setup";

describe("docsEnabled(env) — the pure gate", () => {
  it("DOCS_ENABLED=false disables docs in ANY environment", () => {
    expect(docsEnabled({ DOCS_ENABLED: "false", NODE_ENV: "development" })).toBe(false);
    expect(docsEnabled({ DOCS_ENABLED: "false", NODE_ENV: "production" })).toBe(false);
  });

  it("DOCS_ENABLED explicitly set (not 'false') is an operator opt-in, even in production", () => {
    expect(docsEnabled({ DOCS_ENABLED: "true", NODE_ENV: "production" })).toBe(true);
    expect(docsEnabled({ DOCS_ENABLED: "1", NODE_ENV: "production" })).toBe(true);
  });

  it("unset ⇒ non-production only (default)", () => {
    expect(docsEnabled({ NODE_ENV: "development" })).toBe(true);
    expect(docsEnabled({ NODE_ENV: "test" })).toBe(true);
    expect(docsEnabled({ NODE_ENV: "production" })).toBe(false);
    expect(docsEnabled({})).toBe(true); // no NODE_ENV at all = not production
  });
});

describe("DOCS_ENABLED=false — the routes never get registered", () => {
  let app: INestApplication;
  let http: () => ReturnType<typeof request>;

  beforeAll(async () => {
    process.env.DOCS_ENABLED = "false";
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
    if (docsEnabled(process.env)) setupSwagger(app); // mirror main.ts exactly
    await app.init();
    http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
  });

  afterAll(async () => {
    delete process.env.DOCS_ENABLED; // restore for the next describe
    await app.close();
  });

  it("GET /docs → 404", async () => {
    await http().get("/docs").expect(404);
  });

  it("GET /openapi.json → 404", async () => {
    await http().get("/openapi.json").expect(404);
  });
});

describe("default (DOCS_ENABLED unset, non-production) — docs are served", () => {
  let app: INestApplication;
  let http: () => ReturnType<typeof request>;

  beforeAll(async () => {
    delete process.env.DOCS_ENABLED;
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
    if (docsEnabled(process.env)) setupSwagger(app); // mirror main.ts exactly
    await app.init();
    http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
  });

  afterAll(async () => {
    await app.close();
  });

  it("GET /openapi.json → 200 (the shared-types generation URL)", async () => {
    const res = await http().get("/openapi.json").expect(200);
    expect(res.body.openapi).toBeDefined();
    expect(res.body.info.title).toBe("Sunnah Life API");
  });

  it("GET /docs → 200 (Swagger UI HTML)", async () => {
    const res = await http().get("/docs").expect(200);
    expect(String(res.headers["content-type"])).toContain("text/html");
  });
});
