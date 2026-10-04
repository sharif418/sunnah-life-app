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
import { Prisma } from "../common/prisma-client";
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
      });
      if (!usrahRow) return { usrah: null, announcements: [] };

      const head = usrahRow.headUserId
        ? await tx.user.findUnique({ where: { id: usrahRow.headUserId }, select: { name: true } })
        : null;

      // ROSTER via the sl_usrah_roster projection (Phase C/W2e): plain
      // members see WHO is in their usrah (names/level only) — full User
      // rows and diary visibility stay governed by the tightened policies.
      const roster = await tx.$queryRaw<{ id: string; name: string; member_code: string | null; level: string; gender: string }[]>(
        Prisma.sql`SELECT id, name, member_code, level, gender FROM sl_usrah_roster(${user.usrahId}::text)`
      );
      const completions = await completion7dForUsers(
        tx,
        roster.map((m) => ({ id: m.id, category: "general" as const }))
      );
      const members: UsrahMember[] = roster
        .map((m) => ({
          id: m.id,
          name: m.name,
          gender: m.gender as Gender,
          level: m.level as Level,
          memberCode: m.member_code,
          category: "general" as UserCategory,
          lastActiveAt: new Date(0).toISOString(),
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
      });
      // Author NAMES only, outside the member's RLS scope: a plain member
      // cannot see the head's (or a full admin's) User row, so including the
      // relation came back null and the whole usrah tab failed with a 500.
      const authorIds = [...new Set(announcementRows.map((a) => a.authorId).filter((x): x is string => !!x))];
      const authors = authorIds.length
        ? await this.rls.system((stx) =>
            stx.user.findMany({ where: { id: { in: authorIds } }, select: { id: true, name: true } })
          )
        : [];
      const authorNames = new Map(authors.map((a) => [a.id, a.name]));
      const announcements: Announcement[] = announcementRows.map((a) => ({
        id: a.id,
        usrahId: a.usrahId,
        authorId: a.authorId,
        authorName: authorNames.get(a.authorId),
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
