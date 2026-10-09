// ─────────────────────────────────────────────────────────────────────────────
// Sync-conflict rule (pure, unit-tested): given an incoming offline entry and
// the existing row, decide accept/reject with the exact Bengali reasons used
// by the web API. Mirrors src/app/api/amal/entries/route.ts POST logic.
// ─────────────────────────────────────────────────────────────────────────────

import type { Prisma } from "../common/prisma-client";
import { isValidDateKey } from "./amal";
import type { AmalValue } from "./domain";

export const MAX_BATCH = 500;

/** Max clock skew tolerated on clientUpdatedAt: incoming timestamps are
 * clamped to now + 5 min (Phase C/W2g — a lying client clock a year in the
 * future used to permanently win every future LWW conflict). */
export const CLIENT_TS_MAX_SKEW_MS = 5 * 60_000;

/** Clamp a client timestamp to now + CLIENT_TS_MAX_SKEW_MS (never in the
 * deep future). Past timestamps pass through unchanged. */
export function clampClientTs(ts: Date, now: Date): Date {
  const cap = new Date(now.getTime() + CLIENT_TS_MAX_SKEW_MS);
  return ts.getTime() > cap.getTime() ? cap : ts;
}

/** Allowed machine sources: literal "manual" or auto:<engine>(:<topic>)?
 * (e.g. "auto:prayer:fajr"). Anything else — free text, HTML, junk — is
 * stored as "manual" so the column can never become a client-controlled
 * string sink (Phase C/W2g). */
const AUTO_SOURCE_RE = /^auto:[a-z]+(:[a-z0-9_]+)?$/;

/** Sanitize a client-supplied source string (≤ 64 chars, guard-listed
 * shapes only); everything else degrades to "manual". */
export function guardSource(source: string): string {
  if (source === "manual") return "manual";
  if (source.length <= 64 && AUTO_SOURCE_RE.test(source)) return source;
  return "manual";
}

/** Value ↔ definition inputType check (catalog-driven, Phase C/W2g).
 * Unknown inputType → accepted (catalog drift tolerance: an admin edit or a
 * stale cached catalog must not brick sync). */
function valueMatchesInputType(value: AmalValue, inputType: string | undefined): boolean {
  switch (inputType) {
    case "tri_state": // spec spelling
    case "tri-state":
    case "tristate": // content-pack / AmalInputType spelling
      // "" = cleared (the member un-ticked it) — the clear must reach the
      // server, or the old জামাতে stays there while the phone shows nothing
      return value === "jamaat" || value === "alone" || value === "qaza" || value === "";
    case "boolean":
      return typeof value === "boolean";
    case "count":
    case "quantity":
    case "number":
      return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1_000_000;
    default:
      return true;
  }
}

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
  /** Stored value (valueJson) — when present, a newerVersion rejection echoes
   * it back as serverValue so the client can reconcile (Phase C/W2g). */
  value?: unknown;
}

export type EntryDecision =
  | { ok: true; amalKey: string; date: string; value: AmalValue; clientUpdatedAt: Date; source: string; unchanged?: false }
  /** the server already holds exactly this value — accepted, nothing written */
  | { ok: true; amalKey: string; date: string; unchanged: true }
  | { ok: false; amalKey: string; date: string; reason: string; serverValue?: AmalValue };

const sameValue = (a: unknown, b: unknown) => b !== null && JSON.stringify(a ?? null) === JSON.stringify(b);

/** Coerce a JSON value to a storable amal value (tristate/boolean/number/string). */
export function normalizeValue(v: unknown): AmalValue | null {
  if (typeof v === "boolean") return v;
  if (typeof v === "number" && isFinite(v)) return v;
  if (typeof v === "string") return v;
  return null;
}

/**
 * Per-entry decision for the batch sync endpoint. `lockedByDate`, `defKeys`
 * and `defTypes` (amalKey → inputType) are pre-computed by the caller.
 */
export function decideEntry(
  e: IncomingEntry,
  defKeys: Set<string>,
  defTypes: Map<string, string>,
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
  // An idempotent replay — the same value the server already holds (a guest
  // diary imported at sign-in and then re-sent by the phone's queue, a retry
  // after a lost response) — is accepted as it is, even on a day that has
  // locked since: nothing changes. It used to come back "newer version" /
  // "locked" and sat on the phone as a failed upload.
  if (existing && e.value !== undefined && sameValue(existing.value, normalizeValue(e.value))) {
    return { ok: true, amalKey, date, unchanged: true };
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
  // catalog-driven value semantics (Phase C/W2g): a tri-state field must be
  // jamaat/alone/qaza, a count must be a sane non-negative number, …
  if (!valueMatchesInputType(value, defTypes.get(amalKey))) {
    return { ok: false, amalKey, date, reason: REJECT_REASONS.badValue };
  }
  const parsedCu = new Date(typeof e?.clientUpdatedAt === "string" ? e.clientUpdatedAt : NaN);
  // invalid client timestamp → server now; anything parseable is clamped to
  // now + CLIENT_TS_MAX_SKEW_MS (a lying future clock can't win forever).
  const clientUpdatedAt = clampClientTs(isNaN(parsedCu.getTime()) ? now : parsedCu, now);
  const source = guardSource(typeof e?.source === "string" && e.source ? e.source : "manual");
  // conflict rule: latest clientUpdatedAt wins; the rejected entry carries
  // the SERVER's winning value so the client can reconcile (Phase C/W2g).
  if (existing && existing.clientUpdatedAt >= clientUpdatedAt) {
    const serverValue = existing.value === undefined ? null : normalizeValue(existing.value);
    return {
      ok: false,
      amalKey,
      date,
      reason: REJECT_REASONS.newerVersion,
      ...(serverValue === null ? {} : { serverValue }),
    };
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
