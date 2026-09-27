import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, getSessionUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";

/**
 * POST /api/masala — ask a fiqh question (guests allowed). If signed in, the
 * question is linked to the account.
 */
export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as {
      name?: string;
      phone?: string;
      question?: string;
    } | null;

    const name = (body?.name ?? "").toString().trim().slice(0, 120);
    const question = (body?.question ?? "").toString().trim().slice(0, 4000);
    const phone = (body?.phone ?? "").toString().replace(/[^\d+]/g, "").slice(0, 20) || null;
    if (!name) throw new ApiError(400, "আপনার নাম লিখুন");
    if (!question) throw new ApiError(400, "প্রশ্নটি লিখুন");

    const viewer = await getSessionUser();
    await db.masalaQuestion.create({
      data: { userId: viewer?.id ?? null, name, phone, question },
    });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
