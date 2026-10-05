// ─────────────────────────────────────────────────────────────────────────────
// Amal (Muhasaba) client engine — mirrors apps/mobile/lib/core/amal_engine.dart
// and src/lib/server/amal.ts business rules so the diary UI matches the
// server's summaries exactly. Pure helpers: no React, no fetch.
// ─────────────────────────────────────────────────────────────────────────────

import { addDays, isAyyamBeez, parseKey, toBn } from "@/lib/calendars";
import { computePrayerTimes } from "@/lib/prayer-times";
import type {
  AmalCadence,
  AmalCategory,
  AmalDefinition,
  AmalEntry,
  AmalValue,
  CalcMethodKey,
  Madhhab,
  UserCategory,
} from "@/types/domain";

/** Bangladesh is UTC+6, no DST — the whole locking rule runs in this domain. */
export const BD_TZ_HOURS = 6;

/** Location + method used for the Ishraq-of-D+1 locking rule. */
export interface AmalGeoCfg {
  lat: number;
  lng: number;
  method: CalcMethodKey;
  madhhab: Madhhab;
}

/** Effective target for points (server default: 1 when the map is absent). */
export function targetFor(def: AmalDefinition, category: UserCategory): number {
  return def.target?.[category] ?? def.target?.general ?? 1;
}

/** Target for display (null → free counter, no progress bar / লক্ষ্য subtitle). */
export function displayTarget(def: AmalDefinition, category: UserCategory): number | null {
  if (!def.target) return null;
  return def.target[category] ?? def.target.general ?? null;
}

/**
 * Points for one entry value against its definition (server parity):
 * 1 = complete, 0.5 = partial (count/quantity below target), 0 = not done.
 * Tristate: জামাত/একা = 1, কাযা = 0. Boolean: true = 1.
 */
export function amalPoints(value: AmalValue | undefined, def: AmalDefinition, category: UserCategory): number {
  if (def.inputType === "tristate") return value === "jamaat" || value === "alone" ? 1 : 0;
  if (def.inputType === "boolean") return value === true ? 1 : 0;
  if (def.inputType === "count" || def.inputType === "quantity") {
    const n = typeof value === "number" ? value : Number(value);
    if (!isFinite(n) || n <= 0) return 0;
    return n >= targetFor(def, category) ? 1 : 0.5;
  }
  if (def.inputType === "text") {
    return typeof value === "string" && value.trim().length > 0 ? 1 : 0;
  }
  return 0;
}

/** Cadence check: is this definition expected on the given YYYY-MM-DD? */
export function isAmalDay(def: AmalDefinition, date: string, hijriAdjust = 0): boolean {
  const d = parseKey(date);
  switch (def.cadence) {
    case "daily":
    case "weekly:any":
      return true;
    case "weekly:fri":
      return d.getDay() === 5;
    case "weekly:mon_thu":
      return d.getDay() === 1 || d.getDay() === 4;
    case "monthly:ayyam_beez":
      return isAyyamBeez(d, hijriAdjust);
    default:
      return true;
  }
}

/** Bengali label shown under weekly/monthly-cadence amal. */
export function cadenceLabelBn(cadence: AmalCadence): string {
  switch (cadence) {
    case "weekly:fri":
      return "শুক্রবারের আমল";
    case "weekly:mon_thu":
      return "সোম ও বৃহস্পতিবারের আমল";
    case "monthly:ayyam_beez":
      return "আইয়ামে বীজ (১৩–১৫ তারিখ)";
    default:
      return "";
  }
}

// ── Locking rule (Ishraq of D+1) ─────────────────────────────────────────────

/**
 * A diary day locks once Ishraq (sunrise + 20 min) of the NEXT day has passed,
 * computed at the user's location in the Bangladesh (UTC+6) wall-clock domain —
 * the exact mirror of computeLockDeadline()/bdNowShifted() in the server lib.
 * Today and future days are never locked.
 */
export function isDateLockedClient(date: string, cfg: AmalGeoCfg, today: string): boolean {
  if (date >= today) return false;
  const next = addDays(date, 1);
  const [y, m, d] = next.split("-").map(Number);
  const times = computePrayerTimes(
    { y, m, d },
    { lat: cfg.lat, lng: cfg.lng, tzOffsetHours: BD_TZ_HOURS, method: cfg.method, madhhab: cfg.madhhab }
  );
  // D+1 00:00 (BD wall clock) + ishraq minutes, in the UTC+6-shifted domain.
  const deadlineMs = Date.UTC(y, m - 1, d) + times.ishraq * 60_000;
  const bdNowMs = Date.now() + BD_TZ_HOURS * 3_600_000;
  return deadlineMs < bdNowMs;
}

// ── Completion maths ────────────────────────────────────────────────────────

export interface CategoryCompletion {
  done: number;
  total: number;
  points: number;
  pct: number;
}

export interface DayCompletion {
  done: number;
  total: number;
  pct: number;
  byCategory: Map<AmalCategory, CategoryCompletion>;
}

/** Completion of one day from that day's entries + the day's due definitions. */
export function dayCompletion(
  entries: AmalEntry[],
  dueDefs: AmalDefinition[],
  category: UserCategory
): DayCompletion {
  const valueOf = new Map(entries.map((e) => [e.amalKey, e.value] as const));
  const byCategory = new Map<AmalCategory, CategoryCompletion>();
  let points = 0;
  let done = 0;
  for (const def of dueDefs) {
    const p = amalPoints(valueOf.get(def.key), def, category);
    points += p;
    if (p >= 1) done++;
    const c = byCategory.get(def.category);
    if (c) {
      c.total++;
      c.points += p;
      if (p >= 1) c.done++;
    } else {
      byCategory.set(def.category, { done: p >= 1 ? 1 : 0, total: 1, points: p, pct: 0 });
    }
  }
  for (const c of byCategory.values()) c.pct = Math.round((100 * c.points) / c.total);
  return {
    done,
    total: dueDefs.length,
    pct: dueDefs.length ? Math.round((100 * points) / dueDefs.length) : 0,
    byCategory,
  };
}

/**
 * Consecutive days (ending today) with ≥ threshold% daily-cadence completion.
 * Today never breaks the streak while it is still in progress (< threshold);
 * an unfilled today is skipped.
 */
export function currentStreak(
  allEntries: AmalEntry[],
  defs: AmalDefinition[],
  category: UserCategory,
  today: string,
  thresholdPct = 50,
  lookback = 120
): number {
  const dailyDefs = defs.filter((d) => d.cadence === "daily" || d.cadence === "weekly:any");
  if (!dailyDefs.length) return 0;
  const byDate = new Map<string, AmalEntry[]>();
  for (const e of allEntries) {
    const list = byDate.get(e.date);
    if (list) list.push(e);
    else byDate.set(e.date, [e]);
  }
  let streak = 0;
  for (let i = 0; i < lookback; i++) {
    const day = addDays(today, -i);
    const dayEntries = byDate.get(day) ?? [];
    if (dayEntries.length === 0 && i === 0) continue; // today not filled yet — skip
    const pct = dayCompletion(dayEntries, dailyDefs, category).pct;
    if (pct >= thresholdPct) {
      streak++;
    } else if (i === 0) {
      continue; // today still in progress — don't break the streak
    } else {
      break;
    }
  }
  return streak;
}

// ── Display helpers ─────────────────────────────────────────────────────────

/** Unit trimmed for inline display: cuts the "—" explanation and "(…)" notes. */
export function shortUnit(unit: string | null): string {
  if (!unit) return "";
  const cut = unit.split("—")[0].split("(")[0].trim();
  return cut || unit;
}

/** Compact number → Bengali digits ("0.5" → "০.৫"). */
export function bnNumber(n: number): string {
  const s = Number.isInteger(n) ? String(n) : String(Math.round(n * 100) / 100);
  return toBn(s);
}

/** Read-only value label (locked days, month-grid tooltips). */
export function valueLabelBn(value: AmalValue | undefined, def: AmalDefinition): string {
  if (value === undefined || value === null) return "—";
  if (value === "jamaat") return "জামাতে";
  if (value === "alone") return "একা";
  if (value === "qaza") return "কাযা";
  if (value === true) return "হয়েছে";
  if (value === false) return "হয়নি";
  if (typeof value === "number") {
    if (value <= 0) return "—";
    const unit = shortUnit(def.unit);
    return unit ? `${bnNumber(value)} ${unit}` : bnNumber(value);
  }
  if (value === "") return "—";
  return value;
}
