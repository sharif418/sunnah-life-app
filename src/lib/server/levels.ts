import "server-only";
import { promises as fs } from "fs";
import path from "path";
// ─────────────────────────────────────────────────────────────────────────────
// Level engine — muhibbus-sunnah promotion requirements, loaded from
// content/level-rules.json (owned by the content agent). Used by /api/dawah
// and /api/admin/promote so both always agree.
// ─────────────────────────────────────────────────────────────────────────────

import { db } from "@/lib/db";
import { toBn } from "@/lib/calendars";
import type { LevelRequirement, User } from "@/types/domain";

export interface LevelChecklistItem {
  key: string;
  label: string;
}

export interface LevelRules {
  minMonths: number;
  requireAssessmentPassed: boolean;
  minReferralsAtLevel: number;
  checklist: LevelChecklistItem[];
}

export const DEFAULT_LEVEL_RULES: LevelRules = {
  minMonths: 4,
  requireAssessmentPassed: true,
  minReferralsAtLevel: 5,
  checklist: [],
};

const g = globalThis as unknown as { slLevelRules?: { at: number; rules: LevelRules } };
const TTL_MS = 60_000;

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
 * Reads content/level-rules.json (cached 60s). Accepts both a flat shape and
 * a nested `{ muhibbus_sunnah: { … } }` / `{ levels: { muhibbus_sunnah: { … } } }`
 * shape; falls back to documented defaults on any error.
 */
export async function loadLevelRules(): Promise<LevelRules> {
  if (g.slLevelRules && Date.now() - g.slLevelRules.at < TTL_MS) return g.slLevelRules.rules;
  let rules = DEFAULT_LEVEL_RULES;
  try {
    const raw = JSON.parse(
      await fs.readFile(path.join(process.cwd(), "content", "level-rules.json"), "utf8")
    );
    const node =
      raw?.muhibbus_sunnah ?? raw?.levels?.muhibbus_sunnah ?? raw?.levels?.muhibbus_sunnah_level ?? raw;
    if (node && typeof node === "object") {
      rules = {
        minMonths: numOr(node.minMonths, DEFAULT_LEVEL_RULES.minMonths),
        requireAssessmentPassed: node.requireAssessmentPassed !== false,
        minReferralsAtLevel: numOr(node.minReferralsAtLevel, DEFAULT_LEVEL_RULES.minReferralsAtLevel),
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

/**
 * The muhibbus-sunnah promotion checklist for a user:
 * months in level, passed assessment, downline muhibbus-sunnah count,
 * plus informational checklist items from level-rules.json.
 */
export async function computeRequirements(user: User): Promise<LevelRequirement[]> {
  const rules = await loadLevelRules();
  const months = monthsInLevelOf(user);
  const reqs: LevelRequirement[] = [];

  reqs.push({
    key: "min_months",
    label: `এই স্তরে অন্তত ${toBn(rules.minMonths)} মাস অতিবাহিত করা`,
    done: months >= rules.minMonths,
    detail: `অতিবাহিত ${toBn(months)} মাস (প্রয়োজন ${toBn(rules.minMonths)})`,
  });

  if (rules.requireAssessmentPassed) {
    const passed = await db.assessment.findFirst({
      where: { assesseeId: user.id, result: "passed" },
      select: { id: true },
    });
    reqs.push({
      key: "assessment_passed",
      label: "ফরযে আইন মূল্যায়নে উত্তীর্ণ হওয়া",
      done: !!passed,
      detail: passed ? "উত্তীর্ণ হয়েছেন" : "এখনো উত্তীর্ণ হননি",
    });
  }

  const closures = await db.referralClosure.findMany({
    where: { ancestorId: user.id },
    select: { descendantId: true },
  });
  const downlineIds = closures.map((c) => c.descendantId);
  const referralsAtLevel = downlineIds.length
    ? await db.user.count({ where: { id: { in: downlineIds }, level: "muhibbus_sunnah" } })
    : 0;
  reqs.push({
    key: "min_referrals",
    label: `অন্তত ${toBn(rules.minReferralsAtLevel)} জন মাদউ মুহিব্বুস সুন্নাহ স্তরে উন্নীত`,
    done: referralsAtLevel >= rules.minReferralsAtLevel,
    detail: `বর্তমানে ${toBn(referralsAtLevel)} জন (প্রয়োজন ${toBn(rules.minReferralsAtLevel)})`,
  });

  for (const item of rules.checklist) {
    reqs.push({
      key: `checklist_${item.key}`,
      label: item.label,
      done: false, // informational — verified manually by the invigilator/admin
      detail: "পরিদর্শক কর্তৃক যাচাই হবে",
    });
  }

  return reqs;
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
