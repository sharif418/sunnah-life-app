import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, getSessionUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";

/** POST /api/feedback — app feedback (guests allowed). */
export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as { message?: string } | null;
    const message = (body?.message ?? "").toString().trim().slice(0, 4000);
    if (!message) throw new ApiError(400, "আপনার মতামত লিখুন");

    const viewer = await getSessionUser();
    await db.feedback.create({ data: { userId: viewer?.id ?? null, message } });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
