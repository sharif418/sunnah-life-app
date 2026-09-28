// ─────────────────────────────────────────────────────────────────────────────
// Offline monthly-report renderer (Task B3 verification path).
//
//   cd apps/api && bun run src/scripts/generate-report.ts <phoneOrUserId> <YYYY-MM>
//
// Renders the paper-form Muhasaba PDF for a REAL member straight through the
// service pipeline (Nest application context, no HTTP): the data loads inside
// the member's own RLS context, the PDF renders with the bundled Bengali
// font, and the bytes land in ./storage/reports/{userId}/{month}.pdf via the
// local storage adapter (S3 adapter takes over in prod when S3_* env is set).
// ─────────────────────────────────────────────────────────────────────────────
import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { RlsService } from "../common/rls.service";
import { ReportsService } from "../reports/reports.service";
import { toDomainUser } from "../common/mappers";
import type { User } from "../shared/domain";

async function main() {
  const [phoneOrId, month] = process.argv.slice(2);
  if (!phoneOrId || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month ?? "")) {
    console.error("ব্যবহার: bun run src/scripts/generate-report.ts <phoneOrUserId> <YYYY-MM>");
    process.exit(1);
  }

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ["error", "warn"],
  });
  app.enableShutdownHooks();

  const rls = app.get(RlsService);
  const reports = app.get(ReportsService);

  const isPhone = /^\d{6,15}$/.test(phoneOrId);
  const row = await rls.system((tx) =>
    isPhone ? tx.user.findUnique({ where: { phone: phoneOrId } }) : tx.user.findUnique({ where: { id: phoneOrId } })
  );
  if (!row) {
    console.error(`ব্যবহারকারী পাওয়া যায়নি: ${phoneOrId}`);
    await app.close();
    process.exit(1);
  }
  const target: User = toDomainUser(row as never);

  const report = await reports.generateForUser(target, month);
  console.log(
    `✓ ${month} মাসের মুহাসাবা রিপোর্ট তৈরি — ${target.name} (${target.memberCode ?? target.id})\n` +
      `  storage key : ${report.storageKey}\n` +
      `  bytes       : ${report.byteSize} · status: ${report.status} · id: ${report.id}`
  );

  await app.close();
}

main().catch((e) => {
  console.error("রেন্ডার ব্যর্থ:", e instanceof Error ? e.message : e);
  process.exit(1);
});
