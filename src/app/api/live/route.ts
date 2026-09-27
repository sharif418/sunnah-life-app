import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { errorResponse, json } from "@/lib/server/guard";
import { getSessionUser } from "@/lib/server/auth";
import type { Gender, LiveProgramItem } from "@/types/domain";

type ProgramRow = {
  id: string;
  titleBn: string;
  descBn: string | null;
  hostName: string | null;
  startsAt: Date;
  endsAt: Date | null;
  youtubeId: string | null;
  gender: string;
  status: string;
  recordingUrl: string | null;
};

function programStatus(p: ProgramRow, now: Date): LiveProgramItem["status"] {
  // a seeded "live" status is respected (demo), the rest computed from time
  if (p.status === "live") return "live";
  if (p.startsAt.getTime() > now.getTime()) return "upcoming";
  const end = p.endsAt ?? new Date(p.startsAt.getTime() + 2 * 3_600_000);
  return now.getTime() > end.getTime() ? "past" : "live";
}

/**
 * GET /api/live — programs (public). Female-only sessions are visible ONLY to
 * signed-in female users; general/default programs are visible to everyone.
 * Order: live first (by startsAt), then upcoming, then past.
 */
export async function GET() {
  try {
    const viewer = await getSessionUser(); // may be null → guest
    const rows = (await db.liveProgram.findMany({ orderBy: { startsAt: "asc" } })) as ProgramRow[];

    const now = new Date();
    const visible = rows.filter((p) => p.gender !== "F" || (viewer?.gender ?? "M") === "F");

    const rank: Record<LiveProgramItem["status"], number> = { live: 0, upcoming: 1, past: 2 };
    const programs: LiveProgramItem[] = visible
      .map((p) => ({
        id: p.id,
        titleBn: p.titleBn,
        descBn: p.descBn,
        hostName: p.hostName,
        startsAt: p.startsAt.toISOString(),
        endsAt: p.endsAt?.toISOString() ?? null,
        youtubeId: p.youtubeId,
        gender: p.gender as Gender,
        status: programStatus(p, now),
        recordingUrl: p.recordingUrl,
      }))
      .sort((a, b) => {
        const r = rank[a.status] - rank[b.status];
        if (r !== 0) return r;
        const at = Date.parse(a.startsAt) - Date.parse(b.startsAt);
        return a.status === "past" ? -at : at; // past: newest first
      });

    return json({ programs });
  } catch (e) {
    return errorResponse(e);
  }
}

/** POST /api/live {id} — "Notify me": reminder at the program's start time. */
export async function POST(req: NextRequest) {
  try {
    const user = await requireUser();
    const body = (await req.json().catch(() => null)) as { id?: string } | null;
    if (!body?.id) throw new ApiError(400, "প্রোগ্রাম নির্বাচন করা হয়নি");

    const program = await db.liveProgram.findUnique({ where: { id: body.id } });
    if (!program) throw new ApiError(404, "প্রোগ্রাম পাওয়া যায়নি");
    if (program.gender === "F" && user.gender !== "F") {
      throw new ApiError(403, "এই সেশনটি শুধু বোনদের জন্য");
    }

    const existing = await db.reminder.findFirst({
      where: { userId: user.id, kind: "live", title: program.titleBn, scheduledAt: program.startsAt },
    });
    if (!existing) {
      await db.reminder.create({
        data: {
          userId: user.id,
          kind: "live",
          title: program.titleBn,
          body: program.descBn?.slice(0, 100) ?? null,
          scheduledAt: program.startsAt,
        },
      });
    }
    return json({ ok: true });
  } catch (e) {
    return errorResponse(e);
  }
}
