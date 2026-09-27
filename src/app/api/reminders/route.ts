import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { requireUser, audit, ApiError } from "@/lib/server/auth";
import { json, errorResponse } from "@/lib/server/guard";
import type { ReminderItem } from "@/types/domain";

function toDomain(r: {
  id: string; kind: string; title: string; body: string | null; link: string | null;
  scheduledAt: Date | null; read: boolean; createdAt: Date;
}): ReminderItem {
  return {
    ...r,
    scheduledAt: r.scheduledAt?.toISOString() ?? null,
    createdAt: r.createdAt.toISOString(),
  };
}

export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db.reminder.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: "desc" },
      take: 50,
    });
    return json({ reminders: rows.map(toDomain) });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const user = await requireUser();
    const { id } = (await req.json()) as { id?: string };
    if (!id) throw new ApiError(400, "আইডি দেওয়া হয়নি");
    await db.reminder.updateMany({ where: { id, userId: user.id }, data: { read: true } });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
