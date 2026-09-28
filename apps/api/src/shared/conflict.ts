// ─────────────────────────────────────────────────────────────────────────────
// Sync-conflict rule (pure, unit-tested): given an incoming offline entry and
// the existing row, decide accept/reject with the exact Bengali reasons used
// by the web API. Mirrors src/app/api/amal/entries/route.ts POST logic.
// ─────────────────────────────────────────────────────────────────────────────

import type { Prisma } from "@prisma/client";
import { isValidDateKey } from "./amal";
import type { AmalValue } from "./domain";

export const MAX_BATCH = 500;

export const REJECT_REASONS = {
  incomplete: "অসম্পূর্ণ এন্ট্রি",
  unknownAmal: "অজানা আমল",
  future: "ভবিষ্যতের তারিখ",
  locked: "লক হয়ে গেছে — উসরা প্রধানের অনুমতি দরকার",
  badValue: "মান ঠিক নয়",
  newerVersion: "নতুন সংস্করণ আছে",
} as const;

export interface IncomingEntry {
  amalKey?: unknown;
  date?: unknown;
  value?: unknown;
  clientUpdatedAt?: unknown;
  source?: unknown;
}

export interface ExistingEntry {
  amalKey: string;
  date: string;
  clientUpdatedAt: Date;
}

export type EntryDecision =
  | { ok: true; amalKey: string; date: string; value: AmalValue; clientUpdatedAt: Date; source: string }
  | { ok: false; amalKey: string; date: string; reason: string };

/** Coerce a JSON value to a storable amal value (tristate/boolean/number/string). */
export function normalizeValue(v: unknown): AmalValue | null {
  if (typeof v === "boolean") return v;
  if (typeof v === "number" && isFinite(v)) return v;
  if (typeof v === "string") return v;
  return null;
}

/**
 * Per-entry decision for the batch sync endpoint. `lockedByDate` and
 * `defKeys` are pre-computed by the caller (same as the web route).
 */
export function decideEntry(
  e: IncomingEntry,
  defKeys: Set<string>,
  today: string,
  lockedByDate: Map<string, boolean>,
  existing: ExistingEntry | null,
  now = new Date()
): EntryDecision {
  const amalKey = typeof e?.amalKey === "string" ? e.amalKey : "";
  const date = typeof e?.date === "string" ? e.date : "";
  if (!amalKey || !date || !isValidDateKey(date) || e?.value === undefined) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.incomplete };
  }
  if (!defKeys.has(amalKey)) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.unknownAmal };
  }
  if (date > today) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.future };
  }
  if (lockedByDate.get(date)) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.locked };
  }
  const value = normalizeValue(e.value);
  if (value === null) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.badValue };
  }
  const parsedCu = new Date(typeof e?.clientUpdatedAt === "string" ? e.clientUpdatedAt : NaN);
  const clientUpdatedAt = isNaN(parsedCu.getTime()) ? now : parsedCu;
  const source = typeof e?.source === "string" && e.source ? e.source : "manual";
  // conflict rule: latest clientUpdatedAt wins
  if (existing && existing.clientUpdatedAt >= clientUpdatedAt) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.newerVersion };
  }
  return { ok: true, amalKey, date, value, clientUpdatedAt, source };
}

/** Pre-compute lock status per distinct date (Ishraq rule + DayUnlock override). */
export function lockedDatesFor(
  user: { lat: number | null; lng: number | null; calcMethod: string; madhhab: string },
  dates: string[],
  unlocked: Set<string>,
  today: string,
  isLocked: (u: typeof user, date: string) => boolean
): Map<string, boolean> {
  const m = new Map<string, boolean>();
  for (const d of dates) {
    m.set(d, !unlocked.has(d) && d <= today && isValidDateKey(d) && isLocked(user, d));
  }
  return m;
}

/** Type re-export so services can share the transaction client type. */
export type Tx = Prisma.TransactionClient;
