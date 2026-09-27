// ─────────────────────────────────────────────────────────────────────────────
// Generate the typed client surface from the running API's OpenAPI document.
//
//   1. boots the Nest app WITHOUT listening and writes dist/openapi.json
//      (same DocumentBuilder config as main.ts),
//   2. runs openapi-typescript over it → dist/schema.d.ts.
//
// The API must be resolvable (works with either the source tree via bun or
// the built dist/). Requires the API's node_modules (bun install in apps/api).
// ─────────────────────────────────────────────────────────────────────────────
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, "../dist");
await mkdir(outDir, { recursive: true });

// 1) openapi.json — boot the app context and reuse its swagger document.
//    We import the compiled NestModule pieces exactly as main.ts does.
const require = createRequire(resolve(here, "../../../apps/api"));
const { NestFactory } = require("@nestjs/core");
const { SwaggerModule, DocumentBuilder } = require("@nestjs/swagger");
const { AppModule } = require("../../../apps/api/dist/app.module.js");
const { version } = require("../../../apps/api/package.json");

const app = await NestFactory.create(AppModule, { logger: false });
const config = new DocumentBuilder()
  .setTitle("Sunnah Life API")
  .setDescription(
    "Public Islamic companion + Dawatus Sunnah Tarbiyah engine. Bengali-first; " +
      "all user-scoped reads/writes are additionally protected by PostgreSQL " +
      "Row-Level Security (gender + usrah policies)."
  )
  .setVersion(version ?? "1.0.0")
  .addBearerAuth()
  .addCookieAuth("sl_access")
  .build();
const document = SwaggerModule.createDocument(app, config);
await app.close();
await writeFile(resolve(outDir, "openapi.json"), JSON.stringify(document, null, 2));
console.log(`✓ dist/openapi.json (${Object.keys(document.paths ?? {}).length} paths)`);

// 2) schema.d.ts via openapi-typescript (uses the package's CLI from
//    apps/api's node_modules if installed, otherwise documents the command).
try {
  const { execSync } = require("node:child_process");
  execSync(
    `bunx --bun openapi-typescript ${resolve(outDir, "openapi.json")} -o ${resolve(outDir, "schema.d.ts")}`,
    { stdio: "inherit", cwd: resolve(here, "../../api") }
  );
  console.log("✓ dist/schema.d.ts");
} catch {
  console.log("ℹ openapi-typescript not installed here — run `bun install` in apps/api, then: bunx openapi-typescript packages/shared-types/dist/openapi.json -o packages/shared-types/dist/schema.d.ts");
}
