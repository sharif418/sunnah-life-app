// Export the OpenAPI document without starting a listener:
//   bun run openapi:export            → ./openapi.json
//   bun run openapi:export out.json   → custom path
// Used by packages/shared-types generation (N2b) and the admin panel.
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { writeFileSync } from "fs";
import { resolve } from "path";
import { AppModule } from "../app.module";

async function main(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });

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
  const out = resolve(process.cwd(), process.argv[2] || "openapi.json");
  writeFileSync(out, JSON.stringify(document, null, 2) + "\n");
  const paths = Object.keys(document.paths ?? {}).length;
  console.log(`openapi: ${paths} paths → ${out}`);
  await app.close();
}

main().catch((e) => {
  console.error("openapi export failed:", e);
  process.exit(1);
});
