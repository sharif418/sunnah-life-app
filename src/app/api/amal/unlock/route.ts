import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, audit, requireUser } from "@/lib/server/auth";
import { assertCanAccess, errorResponse, isSupervisor, json } from "@/lib/server/guard";
import { isValidDateKey } from "@/lib/server/amal";

/**
 * POST /api/amal/unlock — usrah_head+ unlocks a locked diary day for a member
 * of their scope (gender guard enforced). Audit-logged.
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "উসরা প্রধান বা তদের ঊর্ধ্বতনদের অনুমতি আছে");

    const body = (await req.json().catch(() => null)) as { userId?: string; date?: string; reason?: string } | null;
    const userId = body?.userId;
    const date = body?.date;
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!date || !isValidDateKey(date)) throw new ApiError(400, "তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");

    const target = await assertCanAccess(viewer, userId); // head must be of that user's usrah or above
    const reason = typeof body?.reason === "string" && body.reason.trim() ? body.reason.trim().slice(0, 500) : null;

    await db.dayUnlock.upsert({
      where: { userId_date: { userId: target.id, date } },
      create: { userId: target.id, date, byUserId: viewer.id, reason },
      update: { byUserId: viewer.id, reason },
    });

    await audit(viewer.id, "unlock_day", "user", target.id, { userId: target.id, date, reason });

    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
