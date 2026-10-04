import { Controller, Get, Injectable, Module, Req } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { RlsService } from "../common/rls.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import type { User } from "../shared/domain";

/**
 * NAV-03 — the Foundation's own announcements (sent from the admin
 * broadcast page without an usrah) for everyone in the app, guests
 * included. Usrah announcements stay in GET /api/usrah (members only).
 * Gender rule: a notice addressed to one gender is shown only to signed-in
 * members of that gender; guests see the everyone ones.
 */
@Injectable()
export class AnnouncementsService {
  constructor(private readonly rls: RlsService) {}

  async list(viewer: User | null) {
    const g = viewer?.gender === "M" || viewer?.gender === "F" ? viewer.gender : null;
    const rows = await this.rls.system((tx) =>
      tx.announcement.findMany({
        where: {
          usrahId: null,
          kind: "announcement",
          OR: [{ gender: null }, ...(g ? [{ gender: g }] : [])],
        },
        orderBy: [{ pinned: "desc" }, { createdAt: "desc" }],
        take: 20,
        include: { author: { select: { name: true } } },
      })
    );
    return {
      announcements: rows.map((a) => ({
        id: a.id,
        usrahId: null,
        authorId: a.authorId,
        authorName: a.author?.name ?? null,
        kind: a.kind,
        body: a.body,
        pinned: a.pinned,
        createdAt: a.createdAt.toISOString(),
      })),
    };
  }
}

@ApiTags("announcements")
@Controller("announcements")
export class AnnouncementsController {
  constructor(private readonly service: AnnouncementsService) {}

  @Get()
  @ApiOperation({ summary: "Foundation-wide announcements (public; gender-scoped notices for that gender only)" })
  list(@Req() req: AuthedRequest) {
    return this.service.list(currentUser(req));
  }
}

@Module({ controllers: [AnnouncementsController], providers: [AnnouncementsService] })
export class AnnouncementsModule {}
