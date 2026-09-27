import { Req, Body, Controller, Get, Post } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { IsNotEmpty, IsString } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import type { Gender, LiveProgramItem, User } from "../shared/domain";

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

@Injectable()
export class LiveService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /**
   * GET /api/live — programs (public). Female-only sessions are visible ONLY
   * to signed-in female users; general programs are visible to everyone.
   * Order: live first (by startsAt), then upcoming, then past.
   */
  async list(viewer: User | null): Promise<{ programs: LiveProgramItem[] }> {
    const rows = (await this.rls.system((tx) =>
      tx.liveProgram.findMany({ orderBy: { startsAt: "asc" } })
    )) as unknown as ProgramRow[];

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

    return { programs };
  }

  /** POST /api/live {id} — "Notify me": reminder at the program's start time. */
  async notify(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    if (!id) throw new ApiError(400, "প্রোগ্রাম নির্বাচন করা হয়নি");

    const program = await this.rls.system((tx) => tx.liveProgram.findUnique({ where: { id } }));
    if (!program) throw new ApiError(404, "প্রোগ্রাম পাওয়া যায়নি");
    if (program.gender === "F" && user.gender !== "F") {
      throw new ApiError(403, "এই সেশনটি শুধু বোনদের জন্য");
    }

    await this.rls.run(user, async (tx) => {
      const existing = await tx.reminder.findFirst({
        where: { userId: user.id, kind: "live", title: program.titleBn, scheduledAt: program.startsAt },
      });
      if (!existing) {
        await tx.reminder.create({
          data: {
            userId: user.id,
            kind: "live",
            title: program.titleBn,
            body: program.descBn?.slice(0, 100) ?? null,
            scheduledAt: program.startsAt,
          },
        });
      }
    });
    return { ok: true };
  }
}

export class NotifyLiveDto {
  @ApiProperty()
  @IsString({ message: "প্রোগ্রাম নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "প্রোগ্রাম নির্বাচন করা হয়নি" })
  id!: string;
}

@ApiTags("live")
@Controller("live")
export class LiveController {
  constructor(private readonly service: LiveService) {}

  @Get()
  @ApiOperation({ summary: "Live programs (gender-scoped for F sessions)" })
  list(@Req() req: AuthedRequest) {
    return this.service.list(currentUser(req));
  }

  @Post()
  @ApiOperation({ summary: '"Notify me" for a program' })
  notify(@Body() dto: NotifyLiveDto, @Req() req: AuthedRequest) {
    return this.service.notify(currentUser(req), dto.id);
  }
}
