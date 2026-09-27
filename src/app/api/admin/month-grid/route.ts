import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { assertCanAccess, errorResponse, json } from "@/lib/server/guard";
import { loadActiveDefinitions, mapDefinition } from "@/lib/server/amal";
import type { AmalValue, MonthGrid, MonthGridCell } from "@/types/domain";

/**
 * GET /api/admin/month-grid?userId&month=YYYY-MM — 31-column amal heatmap
 * data for one member (guard-checked).
 */
export async function GET(req: NextRequest) {
  try {
    const viewer = await requireUser();
    const userId = req.nextUrl.searchParams.get("userId");
    const month = req.nextUrl.searchParams.get("month") ?? "";
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw new ApiError(400, "মাস ঠিকভাবে দিন (YYYY-MM)");

    const target = await assertCanAccess(viewer, userId);

    const [y, m] = month.split("-").map(Number);
    const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
    const days = Array.from({ length: lastDay }, (_, i) => `${month}-${String(i + 1).padStart(2, "0")}`);

    const definitions = (await loadActiveDefinitions()).map(mapDefinition);
    const entries = await db.amalEntry.findMany({
      where: { userId: target.id, date: { gte: days[0], lte: days[days.length - 1] } },
    });
    const cellMap = new Map(entries.map((e) => [`${e.amalKey}|${e.date}`, e]));

    const amalKeys: string[] = [];
    const rows: Record<string, MonthGridCell[]> = {};
    for (const def of definitions) {
      amalKeys.push(def.key);
      rows[def.key] = days.map((date) => {
        const e = cellMap.get(`${def.key}|${date}`);
        if (!e) return { date, value: null, source: "none" };
        let value: AmalValue = 0;
        try {
          value = JSON.parse(e.valueJson) as AmalValue;
        } catch {
          value = 0;
        }
        return { date, value, source: e.source };
      });
    }

    const grid: MonthGrid = { amalKeys, definitions, days, rows };
    return json({ grid });
  } catch (e) {
    return errorResponse(e);
  }
}
