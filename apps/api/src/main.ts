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
import { ValidationPipe, Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { NestExpressApplication } from "@nestjs/platform-express";
import { IoAdapter } from "@nestjs/platform-socket.io";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import helmet from "helmet";
import { AppModule } from "./app.module";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Product routes under /api (web + mobile contract); infra endpoints bare.
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });

  // socket.io gateways (live usrah quiz) mount on the SAME HTTP server at
  // /socket.io — one backend, one auth, one deployment.
  app.useWebSocketAdapter(new IoAdapter(app));

  // Request access log — one line per /api hit (method, route, status, ms).
  // This is the operator-facing proof that web/mobile traffic reaches the
  // API port; keep it cheap (no body logging, no PII).
  const access = new Logger("HTTP");
  app.use((req: { method?: string; originalUrl?: string }, res: { statusCode?: number; on?: (ev: string, cb: () => void) => void }, next: () => void) => {
    const startedAt = Date.now();
    const url = req.originalUrl ?? "";
    if (url.startsWith("/api/") && res.on) {
      res.on("finish", () => {
        access.log(`${req.method} ${url} → ${res.statusCode} ${Date.now() - startedAt}ms`);
      });
    }
    next();
  });

  // DTO validation: strip unknown props, auto-transform payloads.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    })
  );

  // CORS for the web PWA / mobile app (cookie-based flows need credentials).
  const origins = (process.env.CORS_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  app.enableCors({ origin: origins.length ? origins : true, credentials: true });

  // Security headers. CSP disabled so the locally-served Swagger UI assets can
  // load; re-enable with tailored directives behind an edge proxy in prod.
  app.use(
    helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: "cross-origin" },
    })
  );

  // OpenAPI document — matches the deployed route map (all /api/* + health).
  const config = new DocumentBuilder()
    .setTitle("Sunnah Life API")
    .setDescription(
      "দাওয়াতুস সুন্নাহ তারবিয়াত প্ল্যাটফর্ম — auth (OTP + JWT), muhasaba diary, " +
        "usrah & dawah engine, weekly reviews, assessments, admin console. " +
        "Every data route is enforced by PostgreSQL Row-Level Security (gender / " +
        "usrah / downline scoping); auth via `Authorization: Bearer <accessToken>` " +
        "or the HttpOnly sl_access cookie."
    )
    .setVersion(process.env.npm_package_version ?? "1.0.0")
    .addBearerAuth()
    .addCookieAuth("sl_access")
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("docs", app, document);
  // Stable machine URL for shared-types generation (N2b / admin panel).
  app.getHttpAdapter().get("/openapi.json", (_req, res) => {
    (res as { setHeader: (k: string, v: string) => void }).setHeader("Content-Type", "application/json");
    (res as { json: (d: unknown) => void }).json(document);
  });

  app.enableShutdownHooks(); // PrismaService/queues close cleanly

  const port = Number(process.env.PORT || 3001);
  await app.listen(port, "0.0.0.0");
  console.log(`⚡ Sunnah Life API listening on :${port} (docs at /docs, spec at /openapi.json)`);
}

bootstrap().catch((err) => {
  console.error("Failed to bootstrap Sunnah Life API:", err);
  process.exit(1);
});
