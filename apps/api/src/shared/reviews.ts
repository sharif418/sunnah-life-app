// ─────────────────────────────────────────────────────────────────────────────
// Weekly review helpers — Saturday week starts (BD convention) and the
// auto-summary computed server-side from the amal diary.
// Ported from the web workspace src/lib/server/reviews.ts (tx-injected, Json).
// ─────────────────────────────────────────────────────────────────────────────

import type { Prisma } from "../common/prisma-client";
import { addDays, dateKey, parseKey } from "./calendars";
import { amalPoints, loadActiveDefinitions, loadDailyDefinitions, mapDefinition } from "./amal";
import { todayInTz, weekStartInTz } from "./tz";
import type { WeeklyReview } from "./domain";

/**
 * Most recent Saturday (00:00) as YYYY-MM-DD — the week starts Saturday.
 * Phase C/W1a: computed in the given IANA zone (default Asia/Dhaka). The old
 * signature read the SERVER's local clock — wrong on any non-Dhaka host.
 */
export function weekStartOf(tz: string | null | undefined = "Asia/Dhaka", at: Date = new Date()): string {
  return weekStartInTz(tz, at);
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
  /** Phase C/W4c: the member's APPROVED goals ride along so the reviewing
   * head sees target progress next to the week's amal rollup (amalPoints
   * summed over the week's entries for each goal's amalKey). */
  goals: { amalKey: string; title: string; weekPoints: number; weekDays: number }[];
}

/**
 * Auto-summary over weekStart..weekStart+6 from AmalEntry + AmalDefinition:
 *  - overallPct: completed-or-partial daily amal points / expected
 *  - byCategory: per-category pct
 *  - streak: consecutive days (ending at the last elapsed day of the week)
 *    with ≥50% daily completion
 *  - missedDays: elapsed days with 0 points
 *  - counts: completed count per amalKey across the week
 * Only days up to today (the member's zone) count toward expectations — a
 * running week is not punished for days that have not happened yet.
 */
export async function computeWeekSummary(
  tx: Prisma.TransactionClient,
  userId: string,
  weekStart: string,
  userTz?: string | null
): Promise<WeekSummary> {
  const days = weekDays(weekStart);
  // "today" in the MEMBER's zone (Phase C/W1a), falling back to Dhaka.
  const today = todayInTz(userTz ?? "Asia/Dhaka");
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

  // Phase C/W4c — approved goals with their week progress (amalPoints over
  // the week's entries for each goal's amalKey; the daily-defs entries looped
  // above do not cover non-daily amal keys, so goal entries are read here).
  const goalRows = (await tx.personalGoal.findMany({
    where: { userId, status: "approved", active: true },
    orderBy: { createdAt: "asc" },
  })) as unknown as { amalKey: string; title: string }[];
  const goals: WeekSummary["goals"] = [];
  if (goalRows.length) {
    const allDefMap = new Map(
      (await loadActiveDefinitions(tx)).map((d) => [d.key, mapDefinition(d)])
    );
    const goalEntries = (await tx.amalEntry.findMany({
      where: {
        userId,
        date: { gte: days[0], lte: days[days.length - 1] },
        amalKey: { in: [...new Set(goalRows.map((g) => g.amalKey))] },
      },
    })) as unknown as { amalKey: string; date: string; valueJson: unknown }[];
    const pts = new Map<string, number>();
    for (const e of goalEntries) {
      if (!elapsed.includes(e.date)) continue;
      const gdef = allDefMap.get(e.amalKey);
      if (!gdef) continue;
      pts.set(e.amalKey, (pts.get(e.amalKey) ?? 0) + amalPoints(e.valueJson, gdef, category));
    }
    for (const g of goalRows) {
      goals.push({
        amalKey: g.amalKey,
        title: g.title,
        weekPoints: Math.round((pts.get(g.amalKey) ?? 0) * 10) / 10,
        weekDays: elapsed.length,
      });
    }
  }

  return { overallPct, byCategory, streak, missedDays, counts, goals };
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
