import { Req, Controller, Get, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import { completion7dForUsers } from "../shared/amal";
import type { Announcement, Gender, Level, User, UserCategory, Usrah, UsrahMember } from "../shared/domain";

@Injectable()
export class UsrahService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/usrah — own usrah with members (+7-day completion) + announcements. */
  async myUsrah(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!user.usrahId) return { usrah: null, announcements: [] };

    return this.rls.run(user, async (tx) => {
      const usrahRow = await tx.usrah.findUnique({
        where: { id: user.usrahId! },
        include: { members: true },
      });
      if (!usrahRow) return { usrah: null, announcements: [] };

      const head = usrahRow.headUserId
        ? await tx.user.findUnique({ where: { id: usrahRow.headUserId }, select: { name: true } })
        : null;

      const completions = await completion7dForUsers(
        tx,
        usrahRow.members.map((m) => ({ id: m.id, category: m.category }))
      );
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

      const announcementRows = await tx.announcement.findMany({
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

      return { usrah, announcements };
    });
  }
}

@ApiTags("usrah")
@Controller("usrah")
@UseGuards(RolesGuard)
export class UsrahController {
  constructor(private readonly service: UsrahService) {}

  @Get()
  @Roles("user") // any signed-in member (rank 0 floor); RLS scopes the rows
  @ApiOperation({ summary: "Own usrah: members (7-day completion) + announcements" })
  myUsrah(@Req() req: AuthedRequest) {
    return this.service.myUsrah(currentUser(req));
  }
}
