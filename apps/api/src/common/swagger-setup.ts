import type { INestApplication } from "@nestjs/common";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";

/**
 * Swagger/OpenAPI wiring, extracted from main.ts so the DOCS gate is
 * testable [Phase C/W2h]. main.ts (and any test app that mirrors it) calls
 * `setupSwagger(app)` only when `docsEnabled(env)` is true.
 */

/**
 * Pure gate — `true` means the Swagger UI (/docs) and the OpenAPI document
 * (/openapi.json) are registered on the app.
 *
 *   DOCS_ENABLED=false      → never (explicit kill switch, any environment)
 *   DOCS_ENABLED=1/true/…   → always (operator opt-in, even in production)
 *   unset                   → non-production only (default)
 */
export function docsEnabled(env: NodeJS.ProcessEnv): boolean {
  if (env.DOCS_ENABLED) return env.DOCS_ENABLED !== "false";
  return env.NODE_ENV !== "production";
}

/**
 * Register the Swagger UI at /docs + the stable /openapi.json route.
 * Call exactly once per app instance, after the global prefix is set.
 */
export function setupSwagger(app: INestApplication): void {
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
}
