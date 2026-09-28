// ─────────────────────────────────────────────────────────────────────────────
// tz.ts — IANA time-zone math WITHOUT a dependency (Intl only).
//
// Phase C/W1a: the audit found three tz bugs — prayer pushes fired ~6 h late
// (Dhaka wall clock stored as UTC, delayed against real Date.now()),
// weekStartOf used server-LOCAL time, and the day-lock was hard-coded to
// UTC+6. Everything now flows through HERE with the user's own `tz`
// (User.tz, default "Asia/Dhaka").
//
// All converters are DST-correct (offsets are sampled AT the target instant,
// not today's), verified for Dhaka (+6 fixed), Riyadh (+3 fixed) and London
// (+0 winter / +1 summer) in test/tz.spec.ts.
// ─────────────────────────────────────────────────────────────────────────────

export const BD_TZ = "Asia/Dhaka";

/** Valid IANA zone? Falls back to Asia/Dhaka for anything Intl rejects. */
export function safeTz(tz: string | null | undefined): string {
  if (!tz) return BD_TZ;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return tz;
  } catch {
    return BD_TZ;
  }
}

const partsCache = new Map<string, Intl.DateTimeFormat>();
function dtf(tz: string): Intl.DateTimeFormat {
  let f = partsCache.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour12: false,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    partsCache.set(tz, f);
  }
  return f;
}

/** Offset (ms) of `tz` at the instant `at` — positive east of UTC. */
export function tzOffsetMs(at: Date, tz: string): number {
  const zone = safeTz(tz);
  const parts = dtf(zone).formatToParts(at);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? "0");
  let hour = get("hour");
  if (hour === 24) hour = 0; // some ICU versions emit 24:00
  const asUTC = Date.UTC(get("year"), get("month") - 1, get("day"), hour, get("minute"), get("second"));
  return asUTC - at.getTime();
}

/** Local wall-clock pieces of an instant in `tz`. */
export function wallTime(at: Date, tz: string): { dateKey: string; minutes: number } {
  const zone = safeTz(tz);
  const parts = dtf(zone).formatToParts(at);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "0";
  const y = get("year");
  const mo = get("month");
  const d = get("day");
  let hour = Number(get("hour"));
  if (hour === 24) hour = 0;
  return {
    dateKey: `${y}-${mo}-${d}`,
    minutes: hour * 60 + Number(get("minute")),
  };
}

/**
 * Absolute epoch of a LOCAL wall time: `dateKey` + minutes-into-day in `tz`.
 * The inverse of wallTime() and the fix for the prayer-push bug: wall clock
 * may no longer be stored as UTC — it converts through the zone offset.
 */
export function wallTimeToEpoch(dateKey: string, minutesIntoDay: number, tz: string): Date {
  const zone = safeTz(tz);
  const [y, m, d] = dateKey.split("-").map(Number);
  const h = Math.floor(minutesIntoDay / 60);
  const min = minutesIntoDay % 60;
  // 1) naive: interpret the wall time as UTC
  const naive = new Date(Date.UTC(y, m - 1, d, h, min, 0));
  // 2) correct by the zone's offset AT that instant (handles DST edges: the
  //    offset is sampled at the naive instant, then re-sampled once — for
  //    spring-forward gaps this lands on the resolved side, matching the
  //    wall-clock semantics the prayer engine assumes)
  const first = tzOffsetMs(naive, zone);
  const corrected = new Date(naive.getTime() - first);
  const second = tzOffsetMs(corrected, zone);
  return second === first ? corrected : new Date(naive.getTime() - second);
}

/** Today's YYYY-MM-DD in `tz` (was bdToday() — which stays for BD callers). */
export function todayInTz(tz: string | null | undefined, at: Date = new Date()): string {
  return wallTime(at, safeTz(tz)).dateKey;
}

/**
 * The week's Saturday (YYYY-MM-DD) in `tz` — the diary week boundary.
 * Mirrors reviews.ts weekStartOf but computed from the user's zone, not the
 * server's local clock (the audit's second tz bug).
 */
export function weekStartInTz(tz: string | null | undefined, at: Date = new Date()): string {
  const zone = safeTz(tz);
  const { dateKey: today } = wallTime(at, zone);
  const [y, m, d] = today.split("-").map(Number);
  const localMidnightUTCish = new Date(Date.UTC(y, m - 1, d));
  // day-of-week of that local date (UTC-safe: only the DATE matters)
  const dow = localMidnightUTCish.getUTCDay();
  const diff = (dow + 1) % 7; // Sat → 0, Sun → 1, … Fri → 6
  const start = new Date(Date.UTC(y, m - 1, d - diff));
  return start.toISOString().slice(0, 10);
}

/**
 * The zone's UTC offset in HOURS on the given calendar date — the input the
 * prayer engine takes (tzOffsetHours). Sampled at local noon so a DST
 * transition at 02:00 doesn't flip the whole day's prayer times.
 */
export function tzOffsetHoursFor(dateKey: string, tz: string | null | undefined): number {
  return tzOffsetMs(wallTimeToEpoch(dateKey, 12 * 60, safeTz(tz)), safeTz(tz)) / 3_600_000;
}
