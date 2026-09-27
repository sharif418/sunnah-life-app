import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";
import { isValidDateKey } from "@/lib/server/amal";

/** Mapped PersonalGoal (there is no domain type — this shape is the contract). */
export interface GoalItem {
  id: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string;
  active: boolean;
  createdAt: string;
}

function mapGoal(row: {
  id: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string;
  active: boolean;
  createdAt: Date;
}): GoalItem {
  return { ...row, createdAt: row.createdAt.toISOString() };
}

const MAX_ACTIVE_GOALS = 14;

/** GET /api/goals — own active personal goals (also used for habit tracking). */
export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db.personalGoal.findMany({
      where: { userId: user.id, active: true },
      orderBy: { createdAt: "desc" },
    });
    return json({ goals: rows.map(mapGoal) });
  } catch (e) {
    return errorResponse(e);
  }
}

/** POST /api/goals — {amalKey, title, note?, target?, startDate} (max 14 active). */
export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as {
      amalKey?: string;
      title?: string;
      note?: string;
      target?: string;
      startDate?: string;
    } | null;

    const amalKey = (body?.amalKey ?? "").trim();
    const title = (body?.title ?? "").trim().slice(0, 200);
    const startDate = body?.startDate ?? "";
    if (!amalKey) throw new ApiError(400, "আমল নির্বাচন করুন");
    if (!title) throw new ApiError(400, "লক্ষ্যের নাম লিখুন");
    if (!isValidDateKey(startDate)) throw new ApiError(400, "শুরুর তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");

    const activeCount = await db.personalGoal.count({ where: { userId: user.id, active: true } });
    if (activeCount >= MAX_ACTIVE_GOALS) throw new ApiError(400, "সর্বোচ্চ ১৪টি লক্ষ্য");

    const row = await db.personalGoal.create({
      data: {
        userId: user.id,
        amalKey,
        title,
        note: body?.note?.trim().slice(0, 1000) || null,
        target: body?.target?.toString().trim().slice(0, 200) || null,
        startDate,
      },
    });
    return json({ goal: mapGoal(row) });
  } catch (e) {
    return errorResponse(e);
  }
}

/** DELETE /api/goals?id= — remove one of my goals. */
export async function DELETE(req: NextRequest) {
  try {
    const user = await requireUser();
    const id = req.nextUrl.searchParams.get("id");
    if (!id) throw new ApiError(400, "আইডি দেওয়া হয়নি");
    await db.personalGoal.deleteMany({ where: { id, userId: user.id } });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
