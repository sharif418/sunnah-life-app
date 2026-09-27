import "server-only";
// ─────────────────────────────────────────────────────────────────────────────
// Amal engine — server helpers: locking rule (Ishraq of D+1), definition cache,
// entry mapping and 7-day completion maths shared by diary / usrah / reviews /
// admin routes.
// ─────────────────────────────────────────────────────────────────────────────

import { db } from "@/lib/db";
import { computePrayerTimes } from "@/lib/prayer-times";
import { addDays, parseKey, dateKey } from "@/lib/calendars";
import type {
  AmalCadence,
  AmalCategory,
  AmalDefinition,
  AmalInputType,
  AmalValue,
  Level,
  User,
} from "@/types/domain";

export const DHAKA_LAT = 23.8103;
export const DHAKA_LNG = 90.4125;
export const BD_TZ_HOURS = 6; // Bangladesh is UTC+6, no DST

/** Prisma row shape of AmalDefinition (structural, avoids Prisma namespace import). */
export interface AmalDefRow {
  key: string;
  titleBn: string;
  titleEn: string;
  category: string;
  inputType: string;
  cadence: string;
  targetJson: string | null;
  unit: string | null;
  minLevel: string;
  sortOrder: number;
  autoSource: string | null;
  active?: boolean;
}

export function mapDefinition(row: AmalDefRow): AmalDefinition {
  let target: Record<string, number> | null = null;
  if (row.targetJson) {
    try {
      const parsed = JSON.parse(row.targetJson);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        target = parsed as Record<string, number>;
      }
    } catch {
      target = null;
    }
  }
  return {
    key: row.key,
    titleBn: row.titleBn,
    titleEn: row.titleEn,
    category: row.category as AmalCategory,
    inputType: row.inputType as AmalInputType,
    cadence: row.cadence as AmalCadence,
    target,
    unit: row.unit,
    minLevel: row.minLevel as Level,
    sortOrder: row.sortOrder,
    autoSource: row.autoSource,
  };
}

export interface AmalEntryRow {
  id: string;
  userId: string;
  amalKey: string;
  date: string;
  valueJson: string;
  source: string;
  clientUpdatedAt: Date;
  serverUpdatedAt: Date;
}

export function mapEntry(row: AmalEntryRow): {
  id: string;
  amalKey: string;
  date: string;
  clientUpdatedAt: string;
  value: AmalValue;
  source: string;
  serverUpdatedAt: string;
} {
  let value: AmalValue = 0;
  try {
    value = JSON.parse(row.valueJson) as AmalValue;
  } catch {
    value = 0;
  }
  return {
    id: row.id,
    amalKey: row.amalKey,
    date: row.date,
    clientUpdatedAt: row.clientUpdatedAt.toISOString(),
    value,
    source: row.source,
    serverUpdatedAt: row.serverUpdatedAt.toISOString(),
  };
}

// ── Definition cache (short TTL so admin catalog edits appear quickly) ───────

const g = globalThis as unknown as { slAmalDefs?: { at: number; rows: AmalDefRow[] } };
const DEFS_TTL_MS = 30_000;

export async function loadActiveDefinitions(): Promise<AmalDefRow[]> {
  if (g.slAmalDefs && Date.now() - g.slAmalDefs.at < DEFS_TTL_MS) return g.slAmalDefs.rows;
  const rows = (await db.amalDefinition.findMany({
    where: { active: true },
    orderBy: [{ sortOrder: "asc" }, { key: "asc" }],
  })) as AmalDefRow[];
  g.slAmalDefs = { at: Date.now(), rows };
  return rows;
}

export function invalidateDefinitionCache(): void {
  g.slAmalDefs = undefined;
}

/** Active daily-cadence definitions mapped to domain shape (for completion maths). */
export async function loadDailyDefinitions(): Promise<AmalDefinition[]> {
  const rows = await loadActiveDefinitions();
  return rows.filter((r) => r.cadence === "daily").map(mapDefinition);
}

// ── Dhaka wall-clock helpers (server may run in any timezone) ────────────────

/** Epoch-ms shifted so that UTC getters read Dhaka wall clock. */
export function bdNowShifted(): number {
  return Date.now() + BD_TZ_HOURS * 3_600_000;
}

/** Today's YYYY-MM-DD in Bangladesh. */
export function bdToday(): string {
  return new Date(bdNowShifted()).toISOString().slice(0, 10);
}

/** Last n day-keys ending today (Dhaka), oldest first. */
export function lastNDayKeys(n: number): string[] {
  const today = bdToday();
  return Array.from({ length: n }, (_, i) => addDays(today, -(n - 1 - i)));
}

/** True when the YYYY-MM-DD string is a real calendar date. */
export function isValidDateKey(key: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) return false;
  const d = parseKey(key);
  return dateKey(d) === key;
}

// ── Locking rule ─────────────────────────────────────────────────────────────

export type LockUser = Pick<User, "lat" | "lng" | "calcMethod" | "madhhab">;

/**
 * Deadline of amal-day `date`: Ishraq (sunrise + 20 min) of the NEXT day,
 * computed at the user's location (fallback: Dhaka), Karachi/Hanafi defaults
 * from the user's own profile. Returned in the Dhaka-shifted epoch domain —
 * compare with `bdNowShifted()`.
 */
export function computeLockDeadline(date: string, user: LockUser): number {
  const next = addDays(date, 1);
  const [y, m, d] = next.split("-").map(Number);
  const times = computePrayerTimes(
    { y, m, d },
    {
      lat: user.lat ?? DHAKA_LAT,
      lng: user.lng ?? DHAKA_LNG,
      tzOffsetHours: BD_TZ_HOURS,
      method: user.calcMethod,
      madhhab: user.madhhab,
    }
  );
  // D+1 00:00 (Dhaka wall clock) + ishraq minutes, expressed in the shifted domain.
  return Date.UTC(y, m - 1, d) + times.ishraq * 60_000;
}

/** A diary day is locked once Ishraq of the next day has passed (Dhaka time). */
export function isDateLocked(user: LockUser, date: string): boolean {
  return computeLockDeadline(date, user) < bdNowShifted();
}

// ── Completion maths ──────────────────────────────────────────────────────────

/**
 * Points for one entry value against its definition: 1 = completed,
 * 0.5 = partial (count/quantity below target), 0 = not done.
 * Tri-state: জামাত/একা = done, কাযা = not. Boolean: true = done.
 */
export function amalPoints(value: unknown, def: AmalDefinition, userCategory: string): number {
  if (def.inputType === "tristate") return value === "jamaat" || value === "alone" ? 1 : 0;
  if (def.inputType === "boolean") return value === true ? 1 : 0;
  if (def.inputType === "count" || def.inputType === "quantity") {
    const n = typeof value === "number" ? value : Number(value);
    if (!isFinite(n) || n <= 0) return 0;
    const target = def.target?.[userCategory] ?? def.target?.["general"] ?? 1;
    return n >= target ? 1 : 0.5;
  }
  if (def.inputType === "text") {
    return typeof value === "string" && value.trim().length > 0 ? 1 : 0;
  }
  return 0;
}

/**
 * Completion % of a set of entries over `days` for the daily definitions.
 * Denominator: dailyDefCount × days; result rounded, capped 0–100.
 */
export function completionPctFromEntries(
  entries: { amalKey: string; valueJson: string }[],
  defs: AmalDefinition[],
  userCategory: string,
  days: string[]
): number {
  const defMap = new Map(defs.map((d) => [d.key, d]));
  let points = 0;
  for (const e of entries) {
    const def = defMap.get(e.amalKey);
    if (!def) continue;
    let v: unknown = 0;
    try {
      v = JSON.parse(e.valueJson);
    } catch {
      v = 0;
    }
    points += amalPoints(v, def, userCategory);
  }
  const expected = defs.length * Math.max(days.length, 1);
  if (expected <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((100 * points) / expected)));
}

/** Batch 7-day completion % for many users (one entries query). */
export async function completion7dForUsers(
  users: { id: string; category: string }[]
): Promise<Map<string, number>> {
  const result = new Map<string, number>();
  if (!users.length) return result;
  const defs = await loadDailyDefinitions();
  const days = lastNDayKeys(7);
  const rows = await db.amalEntry.findMany({
    where: {
      userId: { in: users.map((u) => u.id) },
      date: { gte: days[0], lte: days[days.length - 1] },
      amalKey: { in: defs.map((d) => d.key) },
    },
  });
  const byUser = new Map<string, { amalKey: string; valueJson: string }[]>();
  for (const r of rows) {
    const list = byUser.get(r.userId) ?? [];
    list.push(r);
    byUser.set(r.userId, list);
  }
  for (const u of users) {
    result.set(u.id, completionPctFromEntries(byUser.get(u.id) ?? [], defs, u.category, days));
  }
  return result;
}

/** 7-day completion % for a single user. */
export async function completion7d(userId: string, category: string): Promise<number> {
  const m = await completion7dForUsers([{ id: userId, category }]);
  return m.get(userId) ?? 0;
}

// ── Misc shared helpers ──────────────────────────────────────────────────────

/** Usrahs the viewer may manage: headed by them, or the one they belong to. */
export async function ownUsrahIds(user: User): Promise<string[]> {
  const usrahs = await db.usrah.findMany({
    where: { OR: [{ headUserId: user.id }, ...(user.usrahId ? [{ id: user.usrahId }] : [])] },
    select: { id: true },
  });
  return usrahs.map((u) => u.id);
}
