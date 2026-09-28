// ─────────────────────────────────────────────────────────────────────────────
// Weekly review helpers — Saturday week starts (BD convention) and the
// auto-summary computed server-side from the amal diary.
// Ported from the web workspace src/lib/server/reviews.ts (tx-injected, Json).
// ─────────────────────────────────────────────────────────────────────────────

import type { Prisma } from "../common/prisma-client";
import { addDays, dateKey, parseKey } from "./calendars";
import { amalPoints, bdToday, loadDailyDefinitions } from "./amal";
import type { WeeklyReview } from "./domain";

/** Most recent Saturday (00:00) as YYYY-MM-DD — BD week starts Saturday. */
export function weekStartOf(d: Date = new Date()): string {
  const diff = (d.getDay() + 1) % 7; // Sat → 0, Sun → 1, … Fri → 6
  return dateKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() - diff));
}

export function weekDays(weekStart: string): string[] {
  return Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
}

export interface WeekSummary {
  overallPct: number;
  byCategory: Record<string, number>;
  streak: number;
  missedDays: number;
  counts: Record<string, number>;
}

/**
 * Auto-summary over weekStart..weekStart+6 from AmalEntry + AmalDefinition:
 *  - overallPct: completed-or-partial daily amal points / expected
 *  - byCategory: per-category pct
 *  - streak: consecutive days (ending at the last elapsed day of the week)
 *    with ≥50% daily completion
 *  - missedDays: elapsed days with 0 points
 *  - counts: completed count per amalKey across the week
 * Only days up to today (Dhaka) count toward expectations — a running week is
 * not punished for days that have not happened yet.
 */
export async function computeWeekSummary(
  tx: Prisma.TransactionClient,
  userId: string,
  weekStart: string
): Promise<WeekSummary> {
  const days = weekDays(weekStart);
  const today = bdToday();
  const elapsed = days.filter((d) => d <= today);

  const defs = await loadDailyDefinitions(tx);
  const entries = (await tx.amalEntry.findMany({
    where: {
      userId,
      date: { gte: days[0], lte: days[days.length - 1] },
      amalKey: { in: defs.map((d) => d.key) },
    },
  })) as unknown as { amalKey: string; date: string; valueJson: unknown }[];
  const user = await tx.user.findUnique({ where: { id: userId }, select: { category: true } });
  const category = user?.category ?? "general";

  // per-day points
  const dayPoints = new Map<string, number>(elapsed.map((d) => [d, 0]));
  const byCategoryPoints = new Map<string, number>();
  const byCategoryExpected = new Map<string, number>();
  const counts: Record<string, number> = {};
  const defMap = new Map(defs.map((d) => [d.key, d]));

  for (const d of defs) {
    byCategoryExpected.set(d.category, (byCategoryExpected.get(d.category) ?? 0) + Math.max(elapsed.length, 1));
  }

  for (const e of entries) {
    const def = defMap.get(e.amalKey);
    if (!def || !dayPoints.has(e.date)) continue;
    const pts = amalPoints(e.valueJson, def, category);
    dayPoints.set(e.date, (dayPoints.get(e.date) ?? 0) + pts);
    byCategoryPoints.set(def.category, (byCategoryPoints.get(def.category) ?? 0) + pts);
    if (pts >= 1) counts[e.amalKey] = (counts[e.amalKey] ?? 0) + 1;
  }

  const expectedTotal = defs.length * Math.max(elapsed.length, 1);
  const totalPoints = [...dayPoints.values()].reduce((a, b) => a + b, 0);
  const overallPct = expectedTotal > 0 ? Math.round((100 * totalPoints) / expectedTotal) : 0;

  const byCategory: Record<string, number> = {};
  for (const [cat, exp] of byCategoryExpected) {
    const pts = byCategoryPoints.get(cat) ?? 0;
    byCategory[cat] = exp > 0 ? Math.round((100 * pts) / exp) : 0;
  }

  // streak backwards from the last elapsed day
  let streak = 0;
  for (let i = elapsed.length - 1; i >= 0; i--) {
    const pts = dayPoints.get(elapsed[i]) ?? 0;
    const pct = defs.length > 0 ? (100 * pts) / defs.length : 0;
    if (pct >= 50) streak++;
    else break;
  }

  const missedDays = elapsed.filter((d) => (dayPoints.get(d) ?? 0) <= 0).length;

  return { overallPct, byCategory, streak, missedDays, counts };
}

export interface ReviewRow {
  id: string;
  userId: string;
  reviewerId: string;
  weekStart: string;
  summaryJson: unknown;
  comment: string | null;
  rating: number | null;
  nextGoals: string | null;
  status: string;
  createdAt: Date;
  completedAt: Date | null;
}

/** Map a Prisma WeeklyReview row (plus optional names) to the domain shape. */
export function mapReview(
  row: ReviewRow,
  reviewerName?: string | null,
  userName?: string | null
): WeeklyReview {
  const raw = row.summaryJson;
  const summary = (raw && typeof raw === "object" && !Array.isArray(raw) ? raw : null) as WeeklyReview["summary"];
  return {
    id: row.id,
    userId: row.userId,
    userName: userName ?? undefined,
    reviewerId: row.reviewerId,
    reviewerName: reviewerName ?? undefined,
    weekStart: row.weekStart,
    summary,
    comment: row.comment,
    rating: row.rating,
    nextGoals: row.nextGoals,
    status: row.status as WeeklyReview["status"],
    createdAt: row.createdAt.toISOString(),
    completedAt: row.completedAt?.toISOString() ?? null,
  };
}

/** Parse a YYYY-MM-DD weekStart into a Date (midnight). */
export function parseWeekStart(key: string): Date {
  return parseKey(key);
}
