import { db } from "@/lib/db";
import { requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";
import { completion7dForUsers } from "@/lib/server/amal";
import type { Announcement, Gender, Level, UserCategory, Usrah, UsrahMember } from "@/types/domain";

/** GET /api/usrah — own usrah with members (+7-day completion) and announcements. */
export async function GET() {
  try {
    const user = await requireUser();
    if (!user.usrahId) return json({ usrah: null, announcements: [] });

    const usrahRow = await db.usrah.findUnique({
      where: { id: user.usrahId },
      include: { members: true },
    });
    if (!usrahRow) return json({ usrah: null, announcements: [] });

    const head = usrahRow.headUserId
      ? await db.user.findUnique({ where: { id: usrahRow.headUserId }, select: { name: true } })
      : null;

    const completions = await completion7dForUsers(usrahRow.members);
    const members: UsrahMember[] = usrahRow.members
      .map((m) => ({
        id: m.id,
        name: m.name,
        gender: m.gender as Gender,
        level: m.level as Level,
        memberCode: m.memberCode,
        category: m.category as UserCategory,
        lastActiveAt: m.lastActiveAt.toISOString(),
        completion7d: completions.get(m.id) ?? 0,
      }))
      .sort((a, b) => a.name.localeCompare(b.name, "bn"));

    const usrah: Usrah & { members: UsrahMember[] } = {
      id: usrahRow.id,
      name: usrahRow.name,
      gender: usrahRow.gender as Gender,
      headUserId: usrahRow.headUserId,
      invigilatorUserId: usrahRow.invigilatorUserId,
      district: usrahRow.district,
      headName: head?.name ?? null,
      memberCount: members.length,
      members,
    };

    const announcementRows = await db.announcement.findMany({
      where: { usrahId: usrahRow.id },
      orderBy: [{ pinned: "desc" }, { createdAt: "desc" }],
      take: 50,
      include: { author: { select: { name: true } } },
    });
    const announcements: Announcement[] = announcementRows.map((a) => ({
      id: a.id,
      usrahId: a.usrahId,
      authorId: a.authorId,
      authorName: a.author?.name ?? null,
      kind: a.kind as Announcement["kind"],
      body: a.body,
      pinned: a.pinned,
      createdAt: a.createdAt.toISOString(),
    }));

    return json({ usrah, announcements });
  } catch (e) {
    return errorResponse(e);
  }
}
