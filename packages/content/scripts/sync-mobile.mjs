// ─────────────────────────────────────────────────────────────────────────────
// sync-mobile.mjs — packages/content is the ONLY source of content packs.
//
//   sync   (default): copy every pack below into apps/mobile/assets/content.
//   check  (--check): exit 1 if any copy differs from the source or any pack
//                     is empty/`{}` — the CI gate that keeps the pipeline
//                     honest (Phase C: "a CI step that fails if any mobile
//                     content pack is {} or the copies differ").
//
// Run from packages/content:
//   bun run sync:mobile        (or: node scripts/sync-mobile.mjs)
//   bun run check:mobile       (or: node scripts/sync-mobile.mjs --check)
// ─────────────────────────────────────────────────────────────────────────────
import { copyFileSync, readFileSync, statSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, "..");
const DST = path.join(SRC, "..", "..", "apps", "mobile", "assets", "content");

// Every content pack the app bundles. quran-uthmani/quran-bn are the heavy
// Qur'an packs (already bundled pre-Phase-C); the rest were drifting/missing.
const PACKS = [
  "amal-catalog.json",
  "assessment-farze-ain-v1.json",
  "level-rules.json",
  "diary-instructions.json",
  "duas.json",
  "adhkar.json",
  "names99.json",
  "islamic-names.json",
  "iman-branches.json",
  "sunnahs.json",
  "articles.json",
  "courses.json",
  "quizzes.json",
  "mosques.json",
  "faq.json",
  "quran-meta-bn.json",
  "quran-uthmani.json",
  "quran-bn.json",
];

/** A pack is "empty" when it has no meaningful payload: {} , [] , or a
 *  top-level collection field (surahs/items/mosques/definitions/…) that is
 *  an empty array. This is exactly the regression that shipped to the
 *  owner's phone (quran-meta-bn.json = { "surahs": [] }). */
function isEmptyPack(file) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return `unparseable JSON`;
  }
  if (parsed === null || typeof parsed !== "object") return "not an object";
  const keys = Object.keys(parsed).filter((k) => k !== "generated" && k !== "source");
  if (keys.length === 0) return "{} — empty object";
  for (const k of keys) {
    const v = parsed[k];
    if (Array.isArray(v) && v.length === 0) return `.${k} is an empty array`;
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      const inner = Object.keys(v);
      if (inner.length === 0) return `.${k} is {}`;
    }
  }
  return null;
}

const CHECK = process.argv.includes("--check");
let failed = false;

for (const pack of PACKS) {
  const src = path.join(SRC, pack);
  const dst = path.join(DST, pack);

  if (!existsSync(src)) {
    console.error(`✗ ${pack}: MISSING from packages/content`);
    failed = true;
    continue;
  }
  const empty = isEmptyPack(src);
  if (empty) {
    console.error(`✗ ${pack}: source pack is empty (${empty})`);
    failed = true;
    continue;
  }
  const size = statSync(src).size;
  if (!existsSync(dst)) {
    if (CHECK) {
      console.error(`✗ ${pack}: not copied to apps/mobile/assets/content`);
      failed = true;
    } else {
      copyFileSync(src, dst);
      console.log(`→ ${pack} (${size} bytes) copied`);
    }
    continue;
  }
  const same =
    readFileSync(src, "utf8") === readFileSync(dst, "utf8") &&
    statSync(src).size === statSync(dst).size;
  if (same) {
    console.log(`✓ ${pack} (${size} bytes) in sync`);
  } else if (CHECK) {
    console.error(`✗ ${pack}: DIFFERS from packages/content — run \`bun run content:sync\``);
    failed = true;
  } else {
    copyFileSync(src, dst);
    console.log(`→ ${pack} (${size} bytes) updated`);
  }
}

// Extra canaries for the packs that were {} on the owner's phone.
const CANARIES = [
  ["quran-meta-bn.json", (d) => d.surahs?.length === 114, "must list exactly 114 surahs"],
  ["assessment-farze-ain-v1.json", (d) => (d.sections ?? []).reduce((a, s) => a + (s.criteria?.length ?? 0), 0) === 23, "must have exactly 23 criteria"],
  ["level-rules.json", (d) => (d.levels?.muhibbus_sunnah?.checklistBn ?? []).length >= 30, "Muhibbus outline must have ≥30 goals"],
  // A bare U+06DD (end of ayah) encloses no number, so the font draws an
  // empty dotted circle; every mark must be followed by Arabic-Indic digits.
  ["adhkar.json", (d) => !/۝(?![٠-٩])/.test(JSON.stringify(d)), "every ۝ ayah mark must carry its number (۝١)"],
];
for (const [pack, test, why] of CANARIES) {
  const d = JSON.parse(readFileSync(path.join(SRC, pack), "utf8"));
  if (!test(d)) {
    console.error(`✗ ${pack}: ${why}`);
    failed = true;
  } else {
    console.log(`✓ ${pack}: ${why}`);
  }
}

if (CHECK && failed) {
  console.error("\ncontent check FAILED — see above");
  process.exit(1);
}
console.log(CHECK ? "\ncontent check passed" : "\nsync complete");
