import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";

/** POST /api/enroll {courseId} — enroll in a course (idempotent). */
export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as { courseId?: string } | null;
    const courseId = (body?.courseId ?? "").trim();
    if (!courseId) throw new ApiError(400, "কোর্স নির্বাচন করা হয়নি");

    await db.enrollment.upsert({
      where: { userId_courseId: { userId: user.id, courseId } },
      create: { userId: user.id, courseId },
      update: {},
    });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}

/** PATCH /api/enroll {courseId, progressJson} — persist lesson progress. */
export async function PATCH(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as {
      courseId?: string;
      progressJson?: string;
    } | null;
    const courseId = (body?.courseId ?? "").trim();
    if (!courseId) throw new ApiError(400, "কোর্স নির্বাচন করা হয়নি");
    if (typeof body?.progressJson !== "string" || !body.progressJson) {
      throw new ApiError(400, "প্রোগ্রেস ডেটা ঠিক নয়");
    }

    await db.enrollment.upsert({
      where: { userId_courseId: { userId: user.id, courseId } },
      create: { userId: user.id, courseId, progressJson: body.progressJson },
      update: { progressJson: body.progressJson, updatedAt: new Date() },
    });
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
