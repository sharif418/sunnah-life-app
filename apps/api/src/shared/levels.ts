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
  slLevelRulesAll?: Partial<Record<LevelKey, { at: number; rules: LevelRules }>>;
};
const TTL_MS = 60_000;

export function contentDir(): string {
  return (
    process.env.CONTENT_DIR ||
    path.resolve(process.cwd(), "..", "..", "packages", "content")
  );
}

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

/**
 * Reads level-rules.json from the content dir (cached 60s). Accepts both a
 * flat shape and a nested `{ muhibbus_sunnah: { … } }` /
 * `{ levels: { muhibbus_sunnah: { … } } }` shape; falls back to documented
 * defaults on any error.
 */
export async function loadLevelRules(level: LevelKey = "muhibbus_sunnah"): Promise<LevelRules> {
  const cache = (g.slLevelRulesAll ??= {});
  const hit = cache[level];
  if (hit && Date.now() - hit.at < TTL_MS) return hit.rules;
  let rules: LevelRules =
    level === "muhibbus_sunnah"
      ? DEFAULT_LEVEL_RULES
      : { ...DEFAULT_LEVEL_RULES, outlineReviewRequired: false, requireAssessmentPassed: true, minMonths: 0 };
  try {
    const raw = JSON.parse(
      await fs.readFile(path.join(contentDir(), "level-rules.json"), "utf8")
    );
    const node =
      raw?.levels?.[level] ??
      (level === "muhibbus_sunnah"
        ? (raw?.muhibbus_sunnah ?? raw?.levels?.muhibbus_sunnah_level ?? raw)
        : undefined);
    if (node && typeof node === "object") {
      rules = parseRules(node as Record<string, unknown>);
    }
  } catch {
    /* keep defaults */
  }
  cache[level] = { at: Date.now(), rules };
  return rules;
}

export async function loadAllLevelRules(): Promise<Record<LevelKey, LevelRules>> {
  const [muhibbus, fa1, fa2] = await Promise.all([
    loadLevelRules("muhibbus_sunnah"),
    loadLevelRules("farze_ain_1"),
    loadLevelRules("farze_ain_2"),
  ]);
  return { muhibbus_sunnah: muhibbus, farze_ain_1: fa1, farze_ain_2: fa2 };
}

export function invalidateLevelRulesCache(): void {
  g.slLevelRulesAll = undefined;
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

  const passed = await tx.assessment.findFirst({
    where: { assesseeId: user.id, result: "passed" },
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
    loadLevelRules(target === "none" ? "muhibbus_sunnah" : target),
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
