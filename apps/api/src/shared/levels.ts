// ─────────────────────────────────────────────────────────────────────────────
// Level engine — muhibbus-sunnah promotion requirements, loaded from
// content/level-rules.json. Used by /api/dawah, /api/dawah/requirements and
// POST /api/admin/promote so all three always agree, plus the nightly
// "levels" worker job (auto-promotion) via LevelsService.
// ─────────────────────────────────────────────────────────────────────────────

import type { Prisma } from "../common/prisma-client";
import { promises as fs } from "fs";
import path from "path";
import { toBn } from "./calendars";
import type { LevelRequirement, User } from "./domain";

export interface LevelChecklistItem {
  key: string;
  label: string;
  /** Outline category (ঈমান/ইবাদাত/ইলম/আখলাক/সিফাত/ত্যাগ ও কুরবানি) —
   * the client's outline groups the goals; shown as section headers. */
  category?: string;
}

/** Machine-checkable facts the evaluation needs (queried once per user). */
export interface LevelFacts {
  /** Whole months spent in the current level. */
  months: number;
  /** A passed assessment exists (any template, result "passed"). */
  assessmentPassed: boolean;
  /** Downline (referral closure) members already at muhibbus_sunnah. */
  referralsAtLevel: number;
}

export type LevelKey = "muhibbus_sunnah" | "farze_ain_1" | "farze_ain_2";

export interface LevelRules {
  titleBn?: string;
  minMonths: number;
  minMonthsLabelBn?: string;
  requireAssessmentPassed: boolean;
  /** Muhibbus model (Phase C/D): the usrah head reviews the outline goals
   *  item by item — NOT an assessment. Blocks admin promotion until the
   *  head attests the review (outlineReviewed flag on POST /admin/promote). */
  outlineReviewRequired: boolean;
  outlineReviewLabelBn?: string;
  minReferralsAtLevel: number;
  minReferralsLabelBn?: string;
  /** Which assessment template gates this level (farze_ain_1/2). */
  assessmentKey?: string;
  assessmentCategory?: number;
  /**
   * Whether the nightly "levels" job may auto-promote when every
   * machine-checkable rule is met (B6). The head-reviewed outline rows
   * NEVER auto-satisfy — autoPromote must stay false for levels whose
   * promotion depends on human attestation.
   */
  autoPromote: boolean;
  checklist: LevelChecklistItem[];
}

export const DEFAULT_LEVEL_RULES: LevelRules = {
  minMonths: 4,
  requireAssessmentPassed: false,
  outlineReviewRequired: true,
  minReferralsAtLevel: 5,
  autoPromote: false,
  checklist: [],
};

function parseRules(node: Record<string, unknown>): LevelRules {
  return {
    titleBn: typeof node.titleBn === "string" ? node.titleBn : undefined,
    minMonths: numOr(node.minMonths, DEFAULT_LEVEL_RULES.minMonths),
    minMonthsLabelBn: typeof node.minMonthsLabelBn === "string" ? node.minMonthsLabelBn : undefined,
    requireAssessmentPassed: node.requireAssessmentPassed !== false,
    outlineReviewRequired: node.outlineReviewRequired === true,
    outlineReviewLabelBn: typeof node.outlineReviewLabelBn === "string" ? node.outlineReviewLabelBn : undefined,
    minReferralsAtLevel: numOr(node.minReferralsAtLevel, DEFAULT_LEVEL_RULES.minReferralsAtLevel),
    minReferralsLabelBn: typeof node.minReferralsLabelBn === "string" ? node.minReferralsLabelBn : undefined,
    assessmentKey: typeof node.assessmentKey === "string" ? node.assessmentKey : undefined,
    assessmentCategory: numOr(node.assessmentCategory, 0) || undefined,
    autoPromote: node.autoPromote !== false,
    checklist: parseChecklist(node.checklistBn ?? node.checklist),
  };
}

const g = globalThis as unknown as {
  slLevelRulesDoc?: {
    at: number;
    /** Raw per-level rule nodes (DB override over the pack file). */
    nodes: Partial<Record<LevelKey, Record<string, unknown>>>;
    /** Where each level's node came from — shown by the admin editor. */
    sources: Partial<Record<LevelKey, "db" | "pack" | "default">>;
    packNote: string | null;
  };
};
const TTL_MS = 60_000;

export function contentDir(): string {
  return (
    process.env.CONTENT_DIR ||
    path.resolve(process.cwd(), "..", "..", "packages", "content")
  );
}

/** AppConfigRow reader — both PrismaService and a transaction client fit. */
export type AppConfigReader = {
  appConfigRow: {
    findUnique(args: { where: { key: string } }): Promise<{ valueJson: unknown } | null>;
  };
};

function numOr(v: unknown, fallback: number): number {
  const n = Number(v);
  return isFinite(n) && n >= 0 ? Math.floor(n) : fallback;
}

/** Checklist items may be plain strings or {key,label,categoryBn} objects. */
function parseChecklist(raw: unknown): LevelChecklistItem[] {
  if (!Array.isArray(raw)) return [];
  const items: LevelChecklistItem[] = [];
  for (const x of raw) {
    if (typeof x === "string" && x.trim()) {
      items.push({ key: `checklist_${items.length + 1}`, label: x.trim() });
    } else if (x && typeof x === "object") {
      const label = String((x as { label?: unknown }).label ?? "").trim();
      const key = String((x as { key?: unknown }).key ?? "").trim();
      const category = String((x as { categoryBn?: unknown }).categoryBn ?? "").trim();
      if (label) items.push({ key: key || `checklist_${items.length + 1}`, label, category: category || undefined });
    }
  }
  return items;
}

/** The per-level nodes of a raw level-rules document (pack file OR DB row).
 * `flatFallback` (pack only) also accepts the legacy flat shapes for
 * muhibbus: `{ minMonths: … }` / `{ muhibbus_sunnah: … }` /
 * `{ levels: { muhibbus_sunnah_level: … } }`. DB rows are always the strict
 * `{ levels: { … } }` shape this module writes — falling back to "the whole
 * document" for a DB row would treat metadata as rule fields. */
function docNodes(
  raw: unknown,
  flatFallback = false
): Partial<Record<LevelKey, Record<string, unknown>>> {
  if (!raw || typeof raw !== "object") return {};
  const r = raw as { levels?: Record<string, unknown>; muhibbus_sunnah?: unknown };
  const levels = (r.levels ?? {}) as Record<string, unknown>;
  const out: Partial<Record<LevelKey, Record<string, unknown>>> = {};
  for (const key of ["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"] as LevelKey[]) {
    const node =
      levels[key] ??
      (flatFallback && key === "muhibbus_sunnah"
        ? (r.muhibbus_sunnah ?? levels.muhibbus_sunnah_level ?? r)
        : undefined);
    if (node && typeof node === "object") out[key] = node as Record<string, unknown>;
  }
  return out;
}

/**
 * The effective level-rules document (W4h): AppConfigRow (key "level_rules",
 * written by the admin level-rules editor — PUT/DELETE /api/admin/level-rules)
 * per level OVER the content-pack file (packages/content/level-rules.json —
 * the seed default). Cached 60s per process; invalidateLevelRulesCache()
 * busts it on write.
 */
export async function loadLevelRulesDoc(reader?: AppConfigReader): Promise<{
  nodes: Partial<Record<LevelKey, Record<string, unknown>>>;
  sources: Partial<Record<LevelKey, "db" | "pack" | "default">>;
  /** The pack's top-level assumptionNote — shown read-only in the editor. */
  packNote: string | null;
}> {
  const hit = g.slLevelRulesDoc;
  if (hit && Date.now() - hit.at < TTL_MS) return { nodes: hit.nodes, sources: hit.sources, packNote: hit.packNote };

  // 1) pack file (the seed default)
  let packNodes: Partial<Record<LevelKey, Record<string, unknown>>> = {};
  let packNote: string | null = null;
  try {
    const raw = JSON.parse(await fs.readFile(path.join(contentDir(), "level-rules.json"), "utf8"));
    packNodes = docNodes(raw, true); // the pack accepts the legacy flat muhibbus shapes
    packNote = typeof raw?.assumptionNote === "string" ? raw.assumptionNote : null;
  } catch {
    /* no pack → defaults below */
  }

  // 2) DB override row (AppConfigRow is RLS-exempt — direct read is the
  // documented pattern for exempt tables, same as readAppConfig)
  let dbNodes: Partial<Record<LevelKey, Record<string, unknown>>> = {};
  if (reader) {
    try {
      const row = await reader.appConfigRow.findUnique({ where: { key: "level_rules" } });
      if (row) dbNodes = docNodes(row.valueJson);
    } catch {
      /* DB not reachable → pack */
    }
  }

  const nodes: Partial<Record<LevelKey, Record<string, unknown>>> = {};
  const sources: Partial<Record<LevelKey, "db" | "pack" | "default">> = {};
  for (const key of ["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"] as LevelKey[]) {
    if (dbNodes[key]) {
      nodes[key] = dbNodes[key];
      sources[key] = "db";
    } else if (packNodes[key]) {
      nodes[key] = packNodes[key];
      sources[key] = "pack";
    }
  }
  g.slLevelRulesDoc = { at: Date.now(), nodes, sources, packNote };
  return { nodes, sources, packNote };
}

/**
 * One level's parsed rules: the DB override over the pack file over the
 * documented defaults. `reader` (the caller's Prisma client/tx) enables the
 * DB override read — every production call site passes its tx; the pure
 * pack-only path stays available for tests.
 */
export async function loadLevelRules(
  level: LevelKey = "muhibbus_sunnah",
  reader?: AppConfigReader
): Promise<LevelRules> {
  const fallback: LevelRules =
    level === "muhibbus_sunnah"
      ? DEFAULT_LEVEL_RULES
      : { ...DEFAULT_LEVEL_RULES, outlineReviewRequired: false, requireAssessmentPassed: true, minMonths: 0 };
  const { nodes } = await loadLevelRulesDoc(reader);
  const node = nodes[level];
  if (!node) return fallback;
  return parseRules(node);
}

export async function loadAllLevelRules(
  reader?: AppConfigReader
): Promise<Record<LevelKey, LevelRules>> {
  const [muhibbus, fa1, fa2] = await Promise.all([
    loadLevelRules("muhibbus_sunnah", reader),
    loadLevelRules("farze_ain_1", reader),
    loadLevelRules("farze_ain_2", reader),
  ]);
  return { muhibbus_sunnah: muhibbus, farze_ain_1: fa1, farze_ain_2: fa2 };
}

export function invalidateLevelRulesCache(): void {
  g.slLevelRulesDoc = undefined;
}

/** Whole months spent in the current level (30.44-day months). */
export function monthsInLevelOf(user: Pick<User, "levelStartedAt">): number {
  if (!user.levelStartedAt) return 0;
  const ms = Date.now() - new Date(user.levelStartedAt).getTime();
  if (ms <= 0) return 0;
  return Math.floor(ms / (30.44 * 86_400_000));
}

// ── Rich checklist (B6) ─────────────────────────────────────────────────────

/** One requirement row of the live checklist (GET /api/dawah/requirements). */
export interface LevelCheckRow {
  key: string;
  labelBn: string;
  /** Machine-evaluated progress (null for invigilator-verified items). */
  current: number | null;
  target: number | null;
  met: boolean;
  /** Whether this row is machine-checkable (drives auto-promotion). */
  autoChecked: boolean;
  detailBn: string;
}

export interface LevelChecklist {
  rows: LevelCheckRow[];
  /** Every machine-checkable rule is met. */
  allMet: boolean;
  /** Auto-promotion allowed at all (rules.autoPromote && allMet). */
  autoEligible: boolean;
}

/**
 * PURE checklist builder (unit-tested) — same facts feed the member-facing
 * checklist, the admin promote validation and the nightly auto-promotion.
 */
export function buildLevelChecklist(rules: LevelRules, facts: LevelFacts): LevelChecklist {
  const rows: LevelCheckRow[] = [];

  rows.push({
    key: "min_months",
    labelBn: rules.minMonthsLabelBn ?? `এই স্তরে অন্তত ${toBn(rules.minMonths)} মাস অতিবাহিত করা`,
    current: facts.months,
    target: rules.minMonths,
    met: facts.months >= rules.minMonths,
    autoChecked: true,
    detailBn: `অতিবাহিত ${toBn(facts.months)} মাস (প্রয়োজন ${toBn(rules.minMonths)})`,
  });

  if (rules.requireAssessmentPassed) {
    rows.push({
      key: "assessment_passed",
      labelBn: rules.assessmentKey
        ? `${rules.assessmentKey} মূল্যায়নে উত্তীর্ণ হওয়া (প্রতি সেকশনে অধিকাংশ 'সম্পূর্ণ')`
        : "ফরযে আইন মূল্যায়নে উত্তীর্ণ হওয়া",
      current: facts.assessmentPassed ? 1 : 0,
      target: 1,
      met: facts.assessmentPassed,
      autoChecked: true,
      detailBn: facts.assessmentPassed ? "উত্তীর্ণ হয়েছেন" : "এখনো উত্তীর্ণ হননি",
    });
  }

  rows.push({
    key: "min_referrals",
    labelBn:
      rules.minReferralsLabelBn ??
      `অন্তত ${toBn(rules.minReferralsAtLevel)} জন মাদউ মুহিব্বুস সুন্নাহ স্তরে উন্নীত`,
    current: facts.referralsAtLevel,
    target: rules.minReferralsAtLevel,
    met: facts.referralsAtLevel >= rules.minReferralsAtLevel,
    autoChecked: true,
    detailBn: `বর্তমানে ${toBn(facts.referralsAtLevel)} জন (প্রয়োজন ${toBn(rules.minReferralsAtLevel)})`,
  });

  // Muhibbus model (Phase C/D): the usrah head reviews the outline goals —
  // a single attested row summarising the per-item checklist below.
  if (rules.outlineReviewRequired) {
    rows.push({
      key: "outline_review",
      labelBn: rules.outlineReviewLabelBn ?? "উসরা প্রধানের আউটলাইন পর্যালোচনা সম্পন্ন",
      current: null,
      target: null,
      met: false,
      autoChecked: false,
      detailBn: "উসরা প্রধান আইটেম ধরে ধরে যাচাই করে সই দিলে সম্পন্ন হবে",
    });
  }

  for (const item of rules.checklist) {
    rows.push({
      key: `checklist_${item.key}`,
      labelBn: item.label,
      current: null,
      target: null,
      met: false,
      autoChecked: false,
      detailBn: item.category ? `(${item.category}) উসরা প্রধান কর্তৃক যাচাই হবে` : "উসরা প্রধান কর্তৃক যাচাই হবে",
    });
  }

  const machine = rows.filter((r) => r.autoChecked);
  const allMet = machine.every((r) => r.met);
  return { rows, allMet, autoEligible: allMet && rules.autoPromote };
}

/** Query the three facts for a user inside an RLS transaction. */
export async function gatherLevelFacts(
  tx: Prisma.TransactionClient,
  user: User
): Promise<LevelFacts> {
  const months = monthsInLevelOf(user);

  // W4i read-path fix: ONLY a CONFIRMED (assessee-acknowledged) passed
  // assessment satisfies the rule — a pending_confirmation or declined
  // result is not final and must never gate/promote a level transition.
  const passed = await tx.assessment.findFirst({
    where: { assesseeId: user.id, result: "passed", status: "confirmed" },
    select: { id: true },
  });

  const closures = await tx.referralClosure.findMany({
    where: { ancestorId: user.id },
    select: { descendantId: true },
  });
  const downlineIds = closures.map((c) => c.descendantId);
  const referralsAtLevel = downlineIds.length
    ? await tx.user.count({ where: { id: { in: downlineIds }, level: "muhibbus_sunnah" } })
    : 0;

  return { months, assessmentPassed: !!passed, referralsAtLevel };
}

// ── W4h: admin level-rules editor validation ────────────────────────────────

/** Every field the engine (parseRules/buildLevelChecklist) reads, plus the two
 * display strings the pack carries for the farze_ain levels. Nothing else is
 * accepted — an unknown key is REJECTED with the key named, so a typo can
 * never silently drop a rule. */
const RULE_FIELDS: Record<string, "string" | "int" | "bool" | "checklist"> = {
  titleBn: "string",
  minMonths: "int",
  minMonthsLabelBn: "string",
  requireAssessmentPassed: "bool",
  outlineReviewRequired: "bool",
  outlineReviewLabelBn: "string",
  minReferralsAtLevel: "int",
  minReferralsLabelBn: "string",
  assessmentKey: "string",
  assessmentCategory: "int",
  assessmentRuleBn: "string",
  categoryDescriptionBn: "string",
  autoPromote: "bool",
  checklistBn: "checklist",
};

const LIMITS: Record<string, number> = {
  titleBn: 120,
  minMonths: 120,
  minMonthsLabelBn: 300,
  outlineReviewLabelBn: 500,
  minReferralsAtLevel: 10_000,
  minReferralsLabelBn: 500,
  assessmentKey: 100,
  assessmentRuleBn: 1000,
  categoryDescriptionBn: 2000,
};

/**
 * PURE validator (unit-testable) of one level's rule node for the admin
 * editor (PUT /api/admin/level-rules/:level). Returns the NORMALIZED node —
 * strings trimmed, exactly the known keys — or throws the Bengali 400 the
 * editor shows. Merge semantics live in the caller: the validated node is
 * layered over the level's current effective node.
 */
export function validateLevelRulesNode(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new LevelRulesValidationError("নিয়মের তথ্য অবজেক্ট আকারে দিন");
  }
  const src = input as Record<string, unknown>;
  const unknown = Object.keys(src).filter((k) => !(k in RULE_FIELDS));
  if (unknown.length) {
    throw new LevelRulesValidationError(`অজানা ফিল্ড: ${unknown.join(", ")}`);
  }

  const out: Record<string, unknown> = {};
  for (const [key, kind] of Object.entries(RULE_FIELDS)) {
    if (!(key in src)) continue;
    const v = src[key];
    if (kind === "bool") {
      if (typeof v !== "boolean") throw new LevelRulesValidationError(`${key} সত্য/মিথ্যা (boolean) হতে হবে`);
      out[key] = v;
    } else if (kind === "int") {
      if (typeof v !== "number" || !Number.isInteger(v)) {
        throw new LevelRulesValidationError(`${key} পূর্ণসংখ্যা হতে হবে`);
      }
      const limit = LIMITS[key] ?? Number.MAX_SAFE_INTEGER;
      const min = key === "assessmentCategory" ? 1 : 0;
      if (v < min || v > limit) {
        throw new LevelRulesValidationError(`${key} ${min}–${limit} এর মধ্যে হতে হবে`);
      }
      out[key] = v;
    } else if (kind === "string") {
      if (typeof v !== "string") throw new LevelRulesValidationError(`${key} লেখা (string) হতে হবে`);
      const trimmed = v.trim();
      const limit = LIMITS[key] ?? 500;
      if (trimmed.length > limit) {
        throw new LevelRulesValidationError(`${key} সর্বোচ্চ ${limit} অক্ষরের হতে হবে`);
      }
      if (key === "assessmentKey" && !trimmed) continue; // optional: absent beats empty
      out[key] = trimmed;
    } else if (kind === "checklist") {
      if (!Array.isArray(v)) throw new LevelRulesValidationError("checklistBn তালিকা (array) হতে হবে");
      if (v.length > 100) throw new LevelRulesValidationError("checklistBn সর্বোচ্চ ১০০টি আইটেম হতে হবে");
      const items: Record<string, string>[] = [];
      for (const item of v) {
        if (!item || typeof item !== "object" || Array.isArray(item)) {
          throw new LevelRulesValidationError("চেকলিস্টের প্রতিটি আইটেম অবজেক্ট হতে হবে");
        }
        const obj = item as Record<string, unknown>;
        const label = typeof obj.label === "string" ? obj.label.trim() : "";
        if (!label || label.length > 1000) {
          throw new LevelRulesValidationError("চেকলিস্টের প্রতিটি আইটেমের label দরকার (১–১০০০ অক্ষর)");
        }
        const unknownItem = Object.keys(obj).filter((k) => !["key", "categoryBn", "label"].includes(k));
        if (unknownItem.length) {
          throw new LevelRulesValidationError(`চেকলিস্ট আইটেমে অজানা ফিল্ড: ${unknownItem.join(", ")}`);
        }
        items.push({
          ...(typeof obj.key === "string" && obj.key.trim() ? { key: obj.key.trim().slice(0, 60) } : {}),
          ...(typeof obj.categoryBn === "string" && obj.categoryBn.trim()
            ? { categoryBn: obj.categoryBn.trim().slice(0, 60) }
            : {}),
          label,
        });
      }
      out.checklistBn = items;
    }
  }
  if (Object.keys(src).length === 0) {
    throw new LevelRulesValidationError("কোনো নিয়ম পাঠানো হয়নি");
  }
  return out;
}

/** Validation failure carrying the Bengali user-facing message. */
export class LevelRulesValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LevelRulesValidationError";
  }
}

/**
 * The muhibbus-sunnah promotion checklist for a user (member-facing shape):
 * months in level, passed assessment, downline muhibbus-sunnah count, plus
 * informational checklist items from level-rules.json. Built on the same
 * facts + builder as the live checklist and the nightly job.
 */
export async function computeRequirements(
  tx: Prisma.TransactionClient,
  user: User
): Promise<LevelRequirement[]> {
  // Rules apply to the user's NEXT level (Phase C/D ladder: none → muhibbus
  // via outline review; muhibbus → farze_ain via the assessment).
  const target = nextLevelOf(user.level);
  const [rules, facts] = await Promise.all([
    loadLevelRules(target === "none" ? "muhibbus_sunnah" : target, tx),
    gatherLevelFacts(tx, user),
  ]);
  const { rows } = buildLevelChecklist(rules, facts);
  return rows.map((r) => ({
    key: r.key,
    label: r.labelBn,
    done: r.met,
    detail: r.detailBn,
  }));
}

/** Next rung of the tarbiyah ladder (used by /api/dawah). */
export function nextLevelOf(level: User["level"]): User["level"] {
  switch (level) {
    case "none":
      return "muhibbus_sunnah";
    case "muhibbus_sunnah":
      return "farze_ain_1";
    case "farze_ain_1":
      return "farze_ain_2";
    default:
      return "farze_ain_2";
  }
}
