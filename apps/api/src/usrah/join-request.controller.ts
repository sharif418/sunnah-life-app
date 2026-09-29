import { Req, Body, Controller, Get, HttpCode, HttpStatus, Injectable, Param, Post, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type { Gender, User } from "../shared/domain";

// ─────────────────────────────────────────────────────────────────────────────
// Usrah join requests (W4d) — a member WITHOUT an usrah asks to be assigned;
// full_admin approves into a concrete usrah (which sets User.usrahId — the
// assignment) or rejects with a reason. Placement decision: src/join is the
// PUBLIC referral landing only, and the routes are usrah-scoped
// (/api/usrah/join-request*), so this lives in the usrah module.
//
// Roles: assignment is a tarbiyah-office action — full_admin only. Usrah heads
// do NOT decide membership here (unlike goals/unlock queues, which are
// usrah_head+): the existing reviews/usrah controllers never assign
// User.usrahId; only /api/admin/usrah/:id/members does (full_admin), and this
// mirrors that boundary.
// ─────────────────────────────────────────────────────────────────────────────

/** Mapped request row (DB Date fields → ISO strings for the wire). */
export interface JoinRequestItem {
  id: string;
  userId: string;
  message: string | null;
  status: string; // pending | approved | rejected
  handledById: string | null;
  handledAt: string | null;
  usrahId: string | null;
  reason: string | null;
  createdAt: string;
}

/** Admin queue row: the request + the member's (and the target usrah's) names. */
export interface JoinRequestQueueItem extends JoinRequestItem {
  userName: string;
  userGender: Gender;
  usrahName: string | null;
}

type RequestRow = Omit<JoinRequestItem, "handledAt" | "createdAt"> & {
  handledAt: Date | null;
  createdAt: Date;
};

export function mapJoinRequest(row: RequestRow): JoinRequestItem {
  return {
    id: row.id,
    userId: row.userId,
    message: row.message,
    status: row.status,
    handledById: row.handledById,
    handledAt: row.handledAt ? row.handledAt.toISOString() : null,
    usrahId: row.usrahId,
    reason: row.reason,
    createdAt: row.createdAt.toISOString(),
  };
}

export class JoinRequestCreateDto {
  @ApiProperty({ required: false, example: "আমি ঢাকার মিরপুরে থাকি — কাছের কোনো উসরায় যুক্ত হতে চাই।" })
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: "বার্তা খুব দীর্ঘ (সর্বোচ্চ ৫০০ অক্ষর)" })
  message?: string;
}

export class JoinRequestApproveDto {
  @ApiProperty()
  @IsString({ message: "উসরা নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "উসরা নির্বাচন করা হয়নি" })
  usrahId!: string;
}

export class JoinRequestRejectDto {
  @ApiProperty({ required: false, example: "আপনার এলাকায় এখনো উসরা চালু হয়নি — ইনশাআল্লাহ শিগগির।" })
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: "কারণ খুব দীর্ঘ (সর্বোচ্চ ৫০০ অক্ষর)" })
  reason?: string;
}

@Injectable()
export class JoinRequestService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /**
   * POST /api/usrah/join-request — only for a member WITHOUT an usrah. 409 when
   * they already have one. IDEMPOTENT while a request is PENDING: the same
   * pending row is returned (201 either way — the /api/enroll upsert precedent);
   * one row per user is enforced here, not by a partial unique index.
   */
  async create(viewer: User | null, dto: JoinRequestCreateDto) {
    const user = this.guard.requireUser(viewer);
    if (user.usrahId) throw new ApiError(409, "আপনি ইতিমধ্যেই একটি উসরায় আছেন");

    return this.rls.run(user, async (tx) => {
      const existing = (await tx.usrahJoinRequest.findFirst({
        where: { userId: user.id, status: "pending" },
        orderBy: { createdAt: "desc" },
      })) as unknown as RequestRow | null;
      if (existing) return { request: mapJoinRequest(existing) }; // idempotent

      const row = (await tx.usrahJoinRequest.create({
        data: {
          userId: user.id,
          message: (dto.message ?? "").trim().slice(0, 500) || null,
          status: "pending",
        },
      })) as unknown as RequestRow;
      return { request: mapJoinRequest(row) };
    });
  }

  /** GET /api/usrah/join-request — own current/last request (null when none). */
  async status(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    const row = (await this.rls.run(user, (tx) =>
      tx.usrahJoinRequest.findFirst({
        where: { userId: user.id },
        orderBy: { createdAt: "desc" },
      })
    )) as unknown as RequestRow | null;
    return { request: row ? mapJoinRequest(row) : null };
  }

  /** GET /api/usrah/join-requests — full_admin queue, PENDING first (FIFO). */
  async queue(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const rows = (await tx.usrahJoinRequest.findMany({
        orderBy: { createdAt: "desc" },
        take: 100,
      })) as unknown as RequestRow[];
      if (!rows.length) return { requests: [] };

      const userIds = [...new Set(rows.map((r) => r.userId))];
      const users = await tx.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, name: true, gender: true },
      });
      const userById = new Map(users.map((u) => [u.id, u]));
      const usrahIds = [...new Set(rows.map((r) => r.usrahId).filter((x): x is string => !!x))];
      const usrahs = usrahIds.length
        ? await tx.usrah.findMany({ where: { id: { in: usrahIds } }, select: { id: true, name: true } })
        : [];
      const usrahNames = new Map(usrahs.map((u) => [u.id, u.name]));

      const requests: JoinRequestQueueItem[] = rows
        .map((r) => {
          const member = userById.get(r.userId);
          return {
            ...mapJoinRequest(r),
            userName: member?.name ?? "সদস্য",
            userGender: (member?.gender ?? "M") as Gender,
            usrahName: r.usrahId ? usrahNames.get(r.usrahId) ?? null : null,
          };
        })
        // pending first (oldest first — a FIFO queue), decided rows after
        .sort((a, b) =>
          a.status === "pending" && b.status !== "pending"
            ? -1
            : b.status === "pending" && a.status !== "pending"
              ? 1
              : 0
        );
      return { requests };
    });
  }

  /**
   * POST /api/usrah/join-requests/:id/approve {usrahId} — full_admin: the
   * assignment. Sets User.usrahId (the member moves into the usrah — gender
   * must match, exactly like /api/admin/usrah/:id/members), marks the request
   * approved and audits it. Idempotent: re-approving an approved request is a
   * no-op returning the current row.
   */
  async approve(viewer: User | null, id: string, dto: JoinRequestApproveDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!dto.usrahId) throw new ApiError(400, "উসরা নির্বাচন করা হয়নি");

    return this.rls.run(user, async (tx) => {
      const request = await tx.usrahJoinRequest.findUnique({ where: { id } });
      if (!request) throw new ApiError(404, "অনুরোধটি পাওয়া যায়নি");
      if (request.status === "approved") {
        return { request: mapJoinRequest(request as unknown as RequestRow) }; // idempotent
      }
      if (request.status !== "pending") throw new ApiError(400, "অনুরোধটি আর অপেক্ষমাণ নয়");

      const usrah = await tx.usrah.findUnique({ where: { id: dto.usrahId } });
      if (!usrah) throw new ApiError(404, "উসরা পাওয়া যায়নি");
      const member = await tx.user.findUnique({ where: { id: request.userId } });
      if (!member) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      if (member.gender !== usrah.gender) {
        throw new ApiError(400, "সদস্যের লিঙ্গ উসরার লিঙ্গের সাথে মিলতে হবে");
      }

      // status guard: another admin may have decided between the read above
      // and this write — updateMany only fires on a still-pending row.
      const res = await tx.usrahJoinRequest.updateMany({
        where: { id, status: "pending" },
        data: {
          status: "approved",
          usrahId: usrah.id,
          handledById: user.id,
          handledAt: new Date(),
        },
      });
      if (res.count === 0) {
        const cur = await tx.usrahJoinRequest.findUnique({ where: { id } });
        if (cur?.status === "approved") {
          return { request: mapJoinRequest(cur as unknown as RequestRow) };
        }
        throw new ApiError(400, "অনুরোধটি আর অপেক্ষমাণ নয়");
      }

      // THE assignment — full_admin context passes the User column guard
      // (sl_guard_user_columns) the same way /api/admin/usrah/:id/members does.
      await tx.user.update({ where: { id: request.userId }, data: { usrahId: usrah.id } });

      const updated = (await tx.usrahJoinRequest.findUnique({ where: { id } })) as unknown as RequestRow;
      await this.guard.audit(user.id, "join_request_approve", "usrah_join_request", id, {
        userId: request.userId,
        usrahId: usrah.id,
      });
      return { request: mapJoinRequest(updated) };
    });
  }

  /** POST /api/usrah/join-requests/:id/reject {reason?} — full_admin (idempotent). */
  async reject(viewer: User | null, id: string, dto: JoinRequestRejectDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const reason = (dto?.reason ?? "").toString().trim().slice(0, 500) || null;

    return this.rls.run(user, async (tx) => {
      const request = await tx.usrahJoinRequest.findUnique({ where: { id } });
      if (!request) throw new ApiError(404, "অনুরোধটি পাওয়া যায়নি");
      if (request.status === "rejected") {
        return { request: mapJoinRequest(request as unknown as RequestRow) }; // idempotent
      }
      if (request.status !== "pending") throw new ApiError(400, "অনুরোধটি আর অপেক্ষমাণ নয়");

      const res = await tx.usrahJoinRequest.updateMany({
        where: { id, status: "pending" },
        data: { status: "rejected", reason, handledById: user.id, handledAt: new Date() },
      });
      if (res.count === 0) {
        const cur = await tx.usrahJoinRequest.findUnique({ where: { id } });
        if (cur?.status === "rejected") {
          return { request: mapJoinRequest(cur as unknown as RequestRow) };
        }
        throw new ApiError(400, "অনুরোধটি আর অপেক্ষমাণ নয়");
      }

      const updated = (await tx.usrahJoinRequest.findUnique({ where: { id } })) as unknown as RequestRow;
      await this.guard.audit(user.id, "join_request_reject", "usrah_join_request", id, {
        userId: request.userId,
        reason,
      });
      return { request: mapJoinRequest(updated) };
    });
  }
}

/** Member routes — any signed-in member; RLS scopes the rows to their own. */
@ApiTags("usrah")
@Controller("usrah/join-request")
@UseGuards(RolesGuard)
export class JoinRequestController {
  constructor(private readonly service: JoinRequestService) {}

  /** GET /api/usrah/join-request — own current/last request + status. */
  @Get()
  @Roles("user")
  @ApiOperation({ summary: "Own usrah join request (current/last, null when none)" })
  status(@Req() req: AuthedRequest) {
    return this.service.status(currentUser(req));
  }

  /** POST /api/usrah/join-request — ask for an usrah (idempotent while pending). */
  @Post()
  @Roles("user")
  @ApiOperation({ summary: "Request usrah assignment (409 when already in one)" })
  create(@Body() dto: JoinRequestCreateDto, @Req() req: AuthedRequest) {
    return this.service.create(currentUser(req), dto);
  }
}

/** Admin routes — full_admin only (assignment is a tarbiyah-office action). */
@ApiTags("usrah")
@Controller("usrah/join-requests")
@UseGuards(RolesGuard)
export class JoinRequestAdminController {
  constructor(private readonly service: JoinRequestService) {}

  /** GET /api/usrah/join-requests — the queue (pending first). */
  @Get()
  @Roles("full_admin")
  @ApiOperation({ summary: "full_admin: join-request queue (pending first)" })
  queue(@Req() req: AuthedRequest) {
    return this.service.queue(currentUser(req));
  }

  /** POST /api/usrah/join-requests/:id/approve {usrahId} — the assignment. */
  @Post(":id/approve")
  @HttpCode(HttpStatus.OK) // decision action, not a resource creation
  @Roles("full_admin")
  @ApiOperation({ summary: "full_admin: approve into an usrah (sets User.usrahId, audited)" })
  approve(@Param("id") id: string, @Body() dto: JoinRequestApproveDto, @Req() req: AuthedRequest) {
    return this.service.approve(currentUser(req), id, dto);
  }

  /** POST /api/usrah/join-requests/:id/reject {reason?}. */
  @Post(":id/reject")
  @HttpCode(HttpStatus.OK) // decision action, not a resource creation
  @Roles("full_admin")
  @ApiOperation({ summary: "full_admin: reject with an optional reason (audited)" })
  reject(@Param("id") id: string, @Body() dto: JoinRequestRejectDto, @Req() req: AuthedRequest) {
    return this.service.reject(currentUser(req), id, dto);
  }
}
