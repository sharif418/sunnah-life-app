import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { assertCanAccess, errorResponse, json } from "@/lib/server/guard";
import {
  bdToday,
  isDateLocked,
  isValidDateKey,
  loadActiveDefinitions,
  mapEntry,
} from "@/lib/server/amal";
import type { AmalValue } from "@/types/domain";

const MAX_BATCH = 500;

function normalizeValue(v: unknown): AmalValue | null {
  if (typeof v === "boolean") return v;
  if (typeof v === "number" && isFinite(v)) return v;
  if (typeof v === "string") return v;
  return null;
}

/**
 * GET /api/amal/entries?from=YYYY-MM-DD&to=YYYY-MM-DD[&userId]
 * Own diary, or another user's via the gender/scope guard.
 */
export async function GET(req: NextRequest) {
  try {
    const viewer = await requireUser();
    const from = req.nextUrl.searchParams.get("from") ?? "";
    const to = req.nextUrl.searchParams.get("to") ?? "";
    if (!isValidDateKey(from) || !isValidDateKey(to)) {
      throw new ApiError(400, "তারিখের পরিসর (from ও to) ঠিকভাবে দিন");
    }
    if (from > to) throw new ApiError(400, "শুরুর তারিখ শেষের তারিখের পরে হতে পারে না");

    const targetParam = req.nextUrl.searchParams.get("userId");
    const target = targetParam ? await assertCanAccess(viewer, targetParam) : viewer;

    const rows = await db.amalEntry.findMany({
      where: { userId: target.id, date: { gte: from, lte: to } },
      orderBy: [{ date: "asc" }, { amalKey: "asc" }],
    });
    return json({ entries: rows.map(mapEntry) });
  } catch (e) {
    return errorResponse(e);
  }
}

/**
 * POST /api/amal/entries — batch offline-first sync for the signed-in user's own diary.
 * Rules: future dates rejected; a day is locked after Ishraq of the next day
 * (unless a DayUnlock row exists); conflict rule = latest clientUpdatedAt wins.
 * Per-entry outcomes are returned in { accepted, rejected } with HTTP 200 so the
 * client can reconcile individual entries.
 */
export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as {
      entries?: { amalKey?: unknown; date?: unknown; value?: unknown; clientUpdatedAt?: unknown; source?: unknown }[];
    } | null;
    const incoming = body?.entries;
    if (!Array.isArray(incoming) || incoming.length === 0) {
      throw new ApiError(400, "কোনো এন্ট্রি পাওয়া যায়নি");
    }
    if (incoming.length > MAX_BATCH) {
      throw new ApiError(400, "একবারে সর্বোচ্চ ৫০০টি এন্ট্রি পাঠানো যায়");
    }

    const definitions = await loadActiveDefinitions();
    const defKeys = new Set(definitions.map((d) => d.key));
    const today = bdToday();
    const now = new Date();

    // pre-compute lock status per distinct date (Ishraq rule + DayUnlock override)
    const dates = [...new Set(incoming.map((e) => (typeof e?.date === "string" ? e.date : "")).filter(Boolean))];
    const unlocks = dates.length
      ? await db.dayUnlock.findMany({ where: { userId: user.id, date: { in: dates } }, select: { date: true } })
      : [];
    const unlocked = new Set(unlocks.map((u) => u.date));
    const lockedByDate = new Map<string, boolean>();
    for (const d of dates) {
      lockedByDate.set(
        d,
        !unlocked.has(d) && d <= today && isValidDateKey(d) && isDateLocked(user, d)
      );
    }

    const accepted: ReturnType<typeof mapEntry>[] = [];
    const rejected: { date: string; amalKey: string; reason: string }[] = [];

    for (const e of incoming) {
      const amalKey = typeof e?.amalKey === "string" ? e.amalKey : "";
      const date = typeof e?.date === "string" ? e.date : "";
      if (!amalKey || !date || !isValidDateKey(date) || e?.value === undefined) {
        rejected.push({ date, amalKey, reason: "অসম্পূর্ণ এন্ট্রি" });
        continue;
      }
      if (!defKeys.has(amalKey)) {
        rejected.push({ date, amalKey, reason: "অজানা আমল" });
        continue;
      }
      if (date > today) {
        rejected.push({ date, amalKey, reason: "ভবিষ্যতের তারিখ" });
        continue;
      }
      if (lockedByDate.get(date)) {
        rejected.push({ date, amalKey, reason: "লক হয়ে গেছে — উসরা প্রধানের অনুমতি দরকার" });
        continue;
      }
      const value = normalizeValue(e.value);
      if (value === null) {
        rejected.push({ date, amalKey, reason: "মান ঠিক নয়" });
        continue;
      }
      const parsedCu = new Date(typeof e?.clientUpdatedAt === "string" ? e.clientUpdatedAt : NaN);
      const clientUpdatedAt = isNaN(parsedCu.getTime()) ? now : parsedCu;
      const source = typeof e?.source === "string" && e.source ? e.source : "manual";

      const existing = await db.amalEntry.findUnique({
        where: { userId_amalKey_date: { userId: user.id, amalKey, date } },
      });
      // conflict rule: latest clientUpdatedAt wins
      if (existing && existing.clientUpdatedAt >= clientUpdatedAt) {
        rejected.push({ date, amalKey, reason: "নতুন সংস্করণ আছে" });
        continue;
      }
      const row = await db.amalEntry.upsert({
        where: { userId_amalKey_date: { userId: user.id, amalKey, date } },
        create: {
          userId: user.id,
          amalKey,
          date,
          valueJson: JSON.stringify(value),
          source,
          clientUpdatedAt,
          serverUpdatedAt: now,
        },
        update: {
          valueJson: JSON.stringify(value),
          source,
          clientUpdatedAt,
          serverUpdatedAt: now,
        },
      });
      accepted.push(mapEntry(row));
    }

    if (accepted.length) {
      await db.user.update({ where: { id: user.id }, data: { lastActiveAt: now } }).catch(() => undefined);
    }

    return json({ accepted, rejected });
  } catch (e) {
    return errorResponse(e);
  }
}
