// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life API — bootstrap.
//
//   GET  /health            liveness/readiness (no prefix, no auth)
//   GET  /metrics           Prometheus exposition (no prefix)
//   GET  /docs              Swagger UI
//   GET  /openapi.json      OpenAPI 3 document (also /docs-json)
//   /api/…                  all product routes (web + mobile contract)
//
// The runtime DB connection is the NOBYPASSRLS `sunnah_app` role; every
// request-scoped query runs through RlsService.run() (SET LOCAL app.user_id /
// app.gender / app.usrah_id / app.role) so PostgreSQL itself enforces the
// gender/usrah/downline visibility model — see prisma/migrations/*_rls.
// ─────────────────────────────────────────────────────────────────────────────
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { NestExpressApplication } from "@nestjs/platform-express";
import helmet from "helmet";
import { AppModule } from "./app.module";
import { StructuredLogger } from "./common/structured-logger";
import { docsEnabled, setupSwagger } from "./common/swagger-setup";
import { RedisSocketAdapter } from "./common/redis-socket.adapter";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // structured JSON logs (one line per event, no PII) for every Nest log call
  // from here on — the docker json-file driver and Loki both parse them. [C-W2h]
  app.useLogger(app.get(StructuredLogger));

  // Product routes under /api (web + mobile contract); infra endpoints bare.
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });

  // socket.io gateways (live usrah quiz) mount on the SAME HTTP server at
  // /socket.io — one backend, one auth, one deployment. The Redis adapter
  // replicates broadcasts across api replicas (real --scale api=N rooms).
  app.useWebSocketAdapter(new RedisSocketAdapter(app));

  // Request access log — one line per /api hit (method, route, status, ms).
  // This is the operator-facing proof that web/mobile traffic reaches the
  // API port; keep it cheap (no body logging, no PII).
  const access = new Logger("HTTP");
  app.use((req: { method?: string; originalUrl?: string }, res: { statusCode?: number; on?: (ev: string, cb: () => void) => void }, next: () => void) => {
    const startedAt = Date.now();
    // PATH ONLY [C-W2h]: the query string is stripped — admin user search
    // (/api/admin/users?q=…) carries names/phones in ?q= and must never land
    // in logs. Route + status + duration is all the log needs.
    const path = (req.originalUrl ?? "").split("?")[0];
    if (path.startsWith("/api/") && res.on) {
      res.on("finish", () => {
        access.log(`${req.method} ${path} → ${res.statusCode} ${Date.now() - startedAt}ms`);
      });
    }
    next();
  });

  // DTO validation: strip unknown props, auto-transform payloads.
  // (Phase C/W2g) The pipe is registered GLOBALLY in AppModule via
  // { provide: APP_PIPE } so e2e test apps run the exact same pipeline —
  // main.ts no longer registers a second one here.

  // CORS for the web PWA / mobile app (cookie-based flows need credentials).
  // Production: STRICTLY the CORS_ORIGINS list (env.validation refuses an
  // empty list in production). Non-production keeps the reflect-any fallback
  // so local tools and the sandbox preview work without configuration.
  const origins = (process.env.CORS_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  const isProduction = process.env.NODE_ENV === "production";
  app.enableCors({
    origin: isProduction ? origins : origins.length ? origins : true,
    credentials: true,
  });

  // Security headers. CSP disabled so the locally-served Swagger UI assets can
  // load; re-enable with tailored directives behind an edge proxy in prod.
  app.use(
    helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: "cross-origin" },
    })
  );

  // OpenAPI document — matches the deployed route map (all /api/* + health).
  // GATED [C-W2h]: off in production (and whenever DOCS_ENABLED=false) — the
  // full route map is recon material; unknown routes simply 404.
  if (docsEnabled(process.env)) {
    setupSwagger(app);
  }

  app.enableShutdownHooks(); // PrismaService/queues close cleanly

  const port = Number(process.env.PORT || 3001);
  await app.listen(port, "0.0.0.0");
  new Logger("Bootstrap").log(
    `⚡ Sunnah Life API listening on :${port}${docsEnabled(process.env) ? " (docs at /docs, spec at /openapi.json)" : ""}`
  );
}

bootstrap().catch((err) => {
  console.error("Failed to bootstrap Sunnah Life API:", err);
  process.exit(1);
});
