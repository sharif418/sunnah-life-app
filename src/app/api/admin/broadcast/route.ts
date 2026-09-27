import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, audit, requireUser } from "@/lib/server/auth";
import { errorResponse, isSupervisor, json } from "@/lib/server/guard";
import { ownUsrahIds } from "@/lib/server/amal";
import type { Gender } from "@/types/domain";

/**
 * POST /api/admin/broadcast — usrah_head+. Creates an Announcement (usrah-
 * scoped or global) and fans out Reminders to the target audience.
 * Scoping: heads → own usrahs; invigilator → own-gender usrahs/all own-gender
 * users; full_admin → anything, global fan-out allowed only for full_admin.
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "ঘোষণা পাঠানোর অনুমতি নেই");

    const body = (await req.json().catch(() => null)) as {
      usrahId?: string | null;
      gender?: Gender | null;
      body?: string;
    } | null;

    const text = (body?.body ?? "").toString().trim().slice(0, 2000);
    if (!text) throw new ApiError(400, "ঘোষণার লেখা লিখুন");

    const usrahId = body?.usrahId ?? null;
    const gender = body?.gender ?? null;

    if (!usrahId && !gender && viewer.role !== "full_admin") {
      throw new ApiError(403, "সবার জন্য ঘোষণা শুধু প্রধান অ্যাডমিন পাঠাতে পারবেন");
    }

    let targetUserIds: string[] = [];

    if (usrahId) {
      const usrah = await db.usrah.findUnique({ where: { id: usrahId }, include: { members: true } });
      if (!usrah) throw new ApiError(400, "উসরা পাওয়া যায়নি");
      if (viewer.role !== "full_admin") {
        const own = await ownUsrahIds(viewer);
        const sameGenderOk = viewer.role === "invigilator" && usrah.gender === viewer.gender;
        if (!own.includes(usrahId) && !sameGenderOk) {
          throw new ApiError(403, "শুধু নিজের উসরার জন্য ঘোষণা পাঠানো যাবে");
        }
      }
      targetUserIds = usrah.members.map((m) => m.id);
    } else if (gender) {
      if (viewer.role !== "full_admin" && gender !== viewer.gender) {
        throw new ApiError(403, "বিপরীত লিঙ্গের জন্য ঘোষণা পাঠানো যাবে না");
      }
      const users = await db.user.findMany({ where: { gender }, select: { id: true } });
      targetUserIds = users.map((u) => u.id);
    } else {
      const users = await db.user.findMany({ select: { id: true } });
      targetUserIds = users.map((u) => u.id);
    }

    const announcement = await db.announcement.create({
      data: { usrahId, authorId: viewer.id, kind: "announcement", body: text, pinned: false },
    });

    if (targetUserIds.length) {
      await db.reminder.createMany({
        data: targetUserIds.map((id) => ({
          userId: id,
          kind: "broadcast",
          title: "নতুন ঘোষণা",
          body: text.slice(0, 200),
        })),
      });
    }

    await audit(viewer.id, "broadcast", "announcement", announcement.id, {
      usrahId,
      gender,
      recipients: targetUserIds.length,
    });

    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
