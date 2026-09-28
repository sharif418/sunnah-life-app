// ─────────────────────────────────────────────────────────────────────────────
// seed-reference — IDEMPOTENT reference data (Phase C/W2a):
//   • Amal catalog (packages/content/amal-catalog.json) — upserted BY KEY
//   • Assessment template farze_ain_v1.1 (verbatim client form) — upserted
//     by (key, version)
//   • App configuration (packages/content/app-config.json) — upserted,
//     admin edits PRESERVED
//
// NEVER deletes anything. Safe (and REQUIRED) to run on every boot: the API
// container runs `bun run seed:reference` after `migrate:deploy`.
// ─────────────────────────────────────────────────────────────────────────────
import { promises as fs } from "fs";
import path from "path";

import type { PrismaClient } from "../src/generated/prisma/client";
import type { DefShape } from "./seed-helpers";

const CONTENT_DIR =
  process.env.CONTENT_DIR ||
  path.resolve(__dirname, "..", "..", "..", "packages", "content");

/** Run the reference seed (idempotent, non-destructive). */
export async function seedReference(db: PrismaClient): Promise<void> {
  // ── 1) Amal catalog — upsert by key (never delete: an admin-disabled
  //    definition is data, not drift) ────────────────────────────────────
  const catalog = JSON.parse(
    await fs.readFile(path.join(CONTENT_DIR, "amal-catalog.json"), "utf8")
  ) as { definitions: DefShape[] };
  for (const d of catalog.definitions) {
    await db.amalDefinition.upsert({
      where: { key: d.key },
      create: {
        key: d.key,
        titleBn: d.titleBn,
        titleEn: d.titleEn,
        category: d.category,
        inputType: d.inputType,
        cadence: d.cadence,
        targetJson: (d.targetJson ?? undefined) as object | undefined,
        unit: d.unit ?? null,
        minLevel: d.minLevel ?? "none",
        sortOrder: d.sortOrder ?? 0,
        autoSource: d.autoSource ?? null,
        active: true,
      },
      update: {
        titleBn: d.titleBn,
        titleEn: d.titleEn,
        category: d.category,
        inputType: d.inputType,
        cadence: d.cadence,
        targetJson: (d.targetJson ?? undefined) as object | undefined,
        unit: d.unit ?? null,
        minLevel: d.minLevel ?? "none",
        sortOrder: d.sortOrder ?? 0,
        autoSource: d.autoSource ?? null,
      },
    });
  }
  console.log(`  AmalDefinitions: ${catalog.definitions.length} upserted (by key)`);

  // ── 2) Assessment template (verbatim Farze Ain v1.1) ───────────────────
  const tmpl = JSON.parse(
    await fs.readFile(path.join(CONTENT_DIR, "assessment-farze-ain-v1.json"), "utf8")
  ) as {
    key: string; version: number; titleBn: string; titleEn: string;
    sections: { key: string; titleBn: string; criteria: { key: string; titleBn: string; hintBn?: string }[] }[];
    instructionsBn?: string; categories?: unknown; categoriesFooterBn?: string;
    scale?: unknown; scaleNoteBn?: string; summarySpec?: unknown;
    overallCommentLabelBn?: string; signatures?: unknown; headerFields?: unknown;
    source?: string;
  };
  await db.assessmentTemplate.upsert({
    where: { key_version: { key: tmpl.key, version: tmpl.version } },
    create: {
      key: tmpl.key,
      version: tmpl.version,
      titleBn: tmpl.titleBn,
      titleEn: tmpl.titleEn,
      sectionsJson: tmpl.sections,
      metaJson: {
        instructionsBn: tmpl.instructionsBn ?? null,
        categories: tmpl.categories ?? null,
        categoriesFooterBn: tmpl.categoriesFooterBn ?? null,
        scale: tmpl.scale ?? null,
        scaleNoteBn: tmpl.scaleNoteBn ?? null,
        summarySpec: tmpl.summarySpec ?? null,
        overallCommentLabelBn: tmpl.overallCommentLabelBn ?? null,
        signatures: tmpl.signatures ?? null,
        headerFields: tmpl.headerFields ?? null,
        source: tmpl.source ?? null,
      },
    },
    update: {
      titleBn: tmpl.titleBn,
      titleEn: tmpl.titleEn,
      sectionsJson: tmpl.sections,
      metaJson: {
        instructionsBn: tmpl.instructionsBn ?? null,
        categories: tmpl.categories ?? null,
        categoriesFooterBn: tmpl.categoriesFooterBn ?? null,
        scale: tmpl.scale ?? null,
        scaleNoteBn: tmpl.scaleNoteBn ?? null,
        summarySpec: tmpl.summarySpec ?? null,
        overallCommentLabelBn: tmpl.overallCommentLabelBn ?? null,
        signatures: tmpl.signatures ?? null,
        headerFields: tmpl.headerFields ?? null,
        source: tmpl.source ?? null,
      },
    },
  });
  const allCriteria = tmpl.sections.flatMap((s) => s.criteria.map((c) => ({ section: s.key, key: c.key })));
  console.log(`  AssessmentTemplate: ${tmpl.key} (${allCriteria.length} criteria) upserted`);

  // ── 3) App configuration — admin edits win (update: {}) ────────────────
  const packCfg = JSON.parse(
    await fs.readFile(path.join(CONTENT_DIR, "app-config.json"), "utf8")
  );
  await db.appConfigRow.upsert({
    where: { key: "app" },
    create: { key: "app", valueJson: packCfg },
    update: {},
  });
  console.log("  AppConfigRow: upserted (admin edits preserved)");
}

