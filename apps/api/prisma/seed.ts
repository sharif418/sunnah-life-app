// ─────────────────────────────────────────────────────────────────────────────
// seed.ts — entrypoint. Phase C/W2a split:
//
//   bun run seed             → seed:reference ALWAYS, + seed:demo when
//                              SEED_DEMO=true && NODE_ENV !== production
//   bun run seed:reference   → reference data only (the API container boot)
//   bun run seed:demo        → demo dataset (dev/staging; refuses in production)
//
// seed:reference is IDEMPOTENT and NEVER deletes (amal catalog by key,
// farze_ain_v1.1 template by (key, version), app config with admin-edit
// preservation). seed:demo wipes USER-DOMAIN tables only — the old seed
// wiped EVERYTHING on every boot, which is why production data could never
// survive a restart (the audit's first production blocker).
// ─────────────────────────────────────────────────────────────────────────────
import { PrismaClient } from "../src/generated/prisma/client";
import { seedReference } from "./seed-reference";
import { seedDemo } from "./seed-demo";

const seedUrl =
  process.env.SEED_DATABASE_URL || process.env.DIRECT_URL || process.env.DATABASE_URL || "";
const db = new PrismaClient({ datasources: { db: { url: seedUrl } } });

export async function runSeed(opts?: { referenceOnly?: boolean }): Promise<void> {
  console.log(`— Sunnah Life seed (postgres, url role: ${/\/\/([^:@]+)[:@]/.exec(seedUrl)?.[1] ?? "?"})`);
  await seedReference(db);
  if (opts?.referenceOnly) {
    console.log("— seed:reference complete");
    return;
  }
  await seedDemo(db);
}

const referenceOnly = process.argv.includes("--reference-only");
runSeed({ referenceOnly })
  .then(() => db.$disconnect())
  .catch(async (e) => {
    console.error("SEED FAILED:", e instanceof Error ? e.message : e);
    await db.$disconnect();
    process.exit(1);
  });
