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

export interface LevelRules {
  minMonths: number;
  requireAssessmentPassed: boolean;
  minReferralsAtLevel: number;
  /**
   * Whether the nightly "levels" job may auto-promote when every
   * machine-checkable rule is met (B6). Set "autoPromote": false in
   * level-rules.json to force admin-only promotion. The informational
   * checklist items (iman/ibadat/…) NEVER block auto-promotion — they are
   * invigilator-verified by design.
   */
  autoPromote: boolean;
  checklist: LevelChecklistItem[];
}

export const DEFAULT_LEVEL_RULES: LevelRules = {
  minMonths: 4,
  requireAssessmentPassed: true,
  minReferralsAtLevel: 5,
  autoPromote: true,
  checklist: [],
};

const g = globalThis as unknown as { slLevelRules?: { at: number; rules: LevelRules } };
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

/** Checklist items may be plain strings or {key, label} objects. */
function parseChecklist(raw: unknown): LevelChecklistItem[] {
  if (!Array.isArray(raw)) return [];
  const items: LevelChecklistItem[] = [];
  for (const x of raw) {
    if (typeof x === "string" && x.trim()) {
      items.push({ key: `checklist_${items.length + 1}`, label: x.trim() });
    } else if (x && typeof x === "object") {
      const label = String((x as { label?: unknown }).label ?? "").trim();
      const key = String((x as { key?: unknown }).key ?? "").trim();
      if (label) items.push({ key: key || `checklist_${items.length + 1}`, label });
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
export async function loadLevelRules(): Promise<LevelRules> {
  if (g.slLevelRules && Date.now() - g.slLevelRules.at < TTL_MS) return g.slLevelRules.rules;
  let rules = DEFAULT_LEVEL_RULES;
  try {
    const raw = JSON.parse(
      await fs.readFile(path.join(contentDir(), "level-rules.json"), "utf8")
    );
    const node =
      raw?.muhibbus_sunnah ?? raw?.levels?.muhibbus_sunnah ?? raw?.levels?.muhibbus_sunnah_level ?? raw;
    if (node && typeof node === "object") {
      rules = {
        minMonths: numOr(node.minMonths, DEFAULT_LEVEL_RULES.minMonths),
        requireAssessmentPassed: node.requireAssessmentPassed !== false,
        minReferralsAtLevel: numOr(node.minReferralsAtLevel, DEFAULT_LEVEL_RULES.minReferralsAtLevel),
        autoPromote: node.autoPromote !== false,
        checklist: parseChecklist(node.checklistBn ?? node.checklist),
      };
    }
  } catch {
    rules = DEFAULT_LEVEL_RULES;
  }
  g.slLevelRules = { at: Date.now(), rules };
  return rules;
}

export function invalidateLevelRulesCache(): void {
  g.slLevelRules = undefined;
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
    labelBn: `এই স্তরে অন্তত ${toBn(rules.minMonths)} মাস অতিবাহিত করা`,
    current: facts.months,
    target: rules.minMonths,
    met: facts.months >= rules.minMonths,
    autoChecked: true,
    detailBn: `অতিবাহিত ${toBn(facts.months)} মাস (প্রয়োজন ${toBn(rules.minMonths)})`,
  });

  if (rules.requireAssessmentPassed) {
    rows.push({
      key: "assessment_passed",
      labelBn: "ফরযে আইন মূল্যায়নে উত্তীর্ণ হওয়া",
      current: facts.assessmentPassed ? 1 : 0,
      target: 1,
      met: facts.assessmentPassed,
      autoChecked: true,
      detailBn: facts.assessmentPassed ? "উত্তীর্ণ হয়েছেন" : "এখনো উত্তীর্ণ হননি",
    });
  }

  rows.push({
    key: "min_referrals",
    labelBn: `অন্তত ${toBn(rules.minReferralsAtLevel)} জন মাদউ মুহিব্বুস সুন্নাহ স্তরে উন্নীত`,
    current: facts.referralsAtLevel,
    target: rules.minReferralsAtLevel,
    met: facts.referralsAtLevel >= rules.minReferralsAtLevel,
    autoChecked: true,
    detailBn: `বর্তমানে ${toBn(facts.referralsAtLevel)} জন (প্রয়োজন ${toBn(rules.minReferralsAtLevel)})`,
  });

  for (const item of rules.checklist) {
    rows.push({
      key: `checklist_${item.key}`,
      labelBn: item.label,
      current: null,
      target: null,
      met: false,
      autoChecked: false,
      detailBn: "পরিদর্শক কর্তৃক যাচাই হবে",
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
  const [rules, facts] = await Promise.all([loadLevelRules(), gatherLevelFacts(tx, user)]);
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
