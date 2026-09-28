// ─────────────────────────────────────────────────────────────────────────────
// seed-split.spec.ts (Phase C/W2a) — the audit's FIRST production blocker:
// "The seed wipes the database on every API boot."
//
// The split under test:
//   • seed:reference = idempotent upserts ONLY (amal catalog by key, the
//     farze_ain_v1.1 template, app config with admin-edit preservation) —
//     NEVER deletes; this is what the API container runs on boot
//   • seed:demo = demo users/usrahs; refused (exit 1) when SEED_DEMO=true in
//     production; skipped when SEED_DEMO is unset
//
// The scripts are executed as REAL subprocesses (bun) — the same entrypoints
// the Docker entrypoint and CI invoke.
// ─────────────────────────────────────────────────────────────────────────────
import { execFileSync } from "child_process";
import { join } from "path";
import { PrismaClient } from "src/generated/prisma/client";

const seedUrl = process.env.SEED_DATABASE_URL || process.env.DIRECT_URL || process.env.DATABASE_URL || "";
const db = new PrismaClient({ datasources: { db: { url: seedUrl } } });

const API_DIR = join(__dirname, "..");

interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
}

/** Run a seed entrypoint as a subprocess with env overrides. */
function run(args: string[], env: Record<string, string>): RunResult {
  try {
    const stdout = execFileSync("bun", ["run", ...args], {
      cwd: API_DIR,
      env: { ...process.env, ...env },
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { code: 0, stdout, stderr: "" };
  } catch (e) {
    const err = e as { status?: number; stdout?: string; stderr?: string };
    return { code: err.status ?? 1, stdout: err.stdout ?? "", stderr: err.stderr ?? "" };
  }
}

beforeAll(async () => {
  // ensure reference data exists (the CI prepare step runs the full seed;
  // locally this guarantees the catalog/template regardless)
  await run(["seed:reference"], {}).stdout;
});

afterAll(async () => {
  await db.$disconnect();
});

describe("seed:reference — idempotent, non-destructive", () => {
  it("running twice leaves row counts unchanged (no duplicates, no wipes)", async () => {
    const before = {
      defs: await db.amalDefinition.count(),
      templates: await db.assessmentTemplate.count(),
      config: await db.appConfigRow.count(),
      users: await db.user.count(),
    };
    expect(before.defs).toBeGreaterThan(20);
    expect(before.templates).toBeGreaterThanOrEqual(1);

    const r1 = run(["seed:reference"], {});
    expect(r1.code).toBe(0);
    const r2 = run(["seed:reference"], {});
    expect(r2.code).toBe(0);

    const after = {
      defs: await db.amalDefinition.count(),
      templates: await db.assessmentTemplate.count(),
      config: await db.appConfigRow.count(),
      users: await db.user.count(),
    };
    // upsert-by-key: no duplicate definitions; no template churn; and the
    // USER table is untouched by a reference run (the boot path!)
    expect(after.defs).toBe(before.defs);
    expect(after.templates).toBe(before.templates);
    expect(after.config).toBe(before.config);
    expect(after.users).toBe(before.users);
  });

  it("preserves an admin-edited AppConfig (update: {} — never clobbers)", async () => {
    await db.appConfigRow.upsert({
      where: { key: "app" },
      create: { key: "app", valueJson: { donationUrl: "https://example.org/admin-edit" } },
      update: { valueJson: { donationUrl: "https://example.org/admin-edit", hijriAdjust: 1 } },
    });
    const r = run(["seed:reference"], {});
    expect(r.code).toBe(0);
    const row = await db.appConfigRow.findUnique({ where: { key: "app" } });
    expect((row!.valueJson as { donationUrl: string }).donationUrl).toBe("https://example.org/admin-edit");
    expect((row!.valueJson as { hijriAdjust: number }).hijriAdjust).toBe(1);
    // restore the pack value for the other suites
    await db.appConfigRow.delete({ where: { key: "app" } });
    run(["seed:reference"], {});
  });
});

describe("seed:demo — the gate", () => {
  it("REFUSES (non-zero) when SEED_DEMO=true and NODE_ENV=production", () => {
    const r = run(["seed"], { SEED_DEMO: "true", NODE_ENV: "production" });
    expect(r.code).not.toBe(0);
    const out = r.stdout + r.stderr;
    expect(out).toContain("REFUSED");
  });

  it("skips demo data when SEED_DEMO is unset (the production boot path)", async () => {
    const usersBefore = await db.user.count();
    const r = run(["seed"], { SEED_DEMO: "" });
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("SEED_DEMO not set");
    const usersAfter = await db.user.count();
    expect(usersAfter).toBe(usersBefore); // nothing wiped
  });
});
