import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";

/** POST /api/quiz-attempt {quizId, score, total} — guests get 401 (client stores locally). */
export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as {
      quizId?: string;
      score?: number;
      total?: number;
    } | null;

    const quizId = (body?.quizId ?? "").trim();
    const score = Number(body?.score);
    const total = Number(body?.total);
    if (!quizId) throw new ApiError(400, "কুইজ নির্বাচন করা হয়নি");
    if (!Number.isInteger(score) || !Number.isInteger(total) || total <= 0 || score < 0 || score > total) {
      throw new ApiError(400, "স্কোর ঠিক নয়");
    }

    await db.quizAttempt.create({ data: { userId: user.id, quizId, score, total } });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
