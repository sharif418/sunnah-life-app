import { Req, Body, Controller, Get, Injectable, Param, Post, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { IsString, MaxLength } from "class-validator";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import type { User } from "../shared/domain";

// ─────────────────────────────────────────────────────────────────────────────
// Live support threads (W4d) — the member half. A member opens a thread with a
// subject + first message; every message lands in SupportMessage (isAdmin
// distinguishes the support team's replies). Status: open → (admin reply)
// answered → (member reply) open → … → closed (admin-only, terminal —
// appending to a closed thread is refused; the member opens a new one).
// ─────────────────────────────────────────────────────────────────────────────

/** Mapped thread row (DB Date fields → ISO strings for the wire). */
export interface SupportThreadItem {
  id: string;
  userId: string;
  subject: string;
  status: string; // open | answered | closed
  createdAt: string;
  updatedAt: string;
  closedAt: string | null;
}

/** List row: the thread + its conversation stats (GET /api/support). */
export interface SupportThreadListItem extends SupportThreadItem {
  messageCount: number;
  lastMessageAt: string | null; // last activity (thread.updatedAt mirrors it)
  lastPreview: string | null; // first ~120 chars of the last message body
  /** True when the LAST message is a support-team reply — the member's "new
   *  answer" badge. No read-receipts exist: opening the thread does not clear
   *  it (kept minimal; a lastReadAt column is the honest follow-up). */
  unreadForUser: boolean;
}

export interface SupportMessageItem {
  id: string;
  threadId: string;
  authorId: string;
  isAdmin: boolean;
  body: string;
  createdAt: string;
}

type ThreadRow = Omit<SupportThreadItem, "createdAt" | "updatedAt" | "closedAt"> & {
  createdAt: Date;
  updatedAt: Date;
  closedAt: Date | null;
};
type MessageRow = Omit<SupportMessageItem, "createdAt"> & { createdAt: Date };

export function mapThread(row: ThreadRow): SupportThreadItem {
  return {
    id: row.id,
    userId: row.userId,
    subject: row.subject,
    status: row.status,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    closedAt: row.closedAt ? row.closedAt.toISOString() : null,
  };
}

export function mapMessage(row: MessageRow): SupportMessageItem {
  return {
    id: row.id,
    threadId: row.threadId,
    authorId: row.authorId,
    isAdmin: row.isAdmin,
    body: row.body,
    createdAt: row.createdAt.toISOString(),
  };
}

export class SupportCreateDto {
  @ApiProperty({ example: "নামাজের সময় জানতে চাই" })
  @IsString({ message: "বিষয় লিখুন" })
  @MaxLength(120, { message: "বিষয় খুব দীর্ঘ (সর্বোচ্চ ১২০ অক্ষর)" })
  subject!: string;

  @ApiProperty({ example: "আসসালামু আলাইকুম, আমার এলাকার নামাজের সময়সূচি দেখাচ্ছে না।" })
  @IsString({ message: "বার্তা লিখুন" })
  @MaxLength(2000, { message: "বার্তা খুব দীর্ঘ (সর্বোচ্চ ২০০০ অক্ষর)" })
  message!: string;
}

export class SupportReplyDto {
  @ApiProperty({ example: "জাযাকাল্লাহু খাইরান, সমস্যাটি সমাধান হয়েছে।" })
  @IsString({ message: "বার্তা লিখুন" })
  @MaxLength(2000, { message: "বার্তা খুব দীর্ঘ (সর্বোচ্চ ২০০০ অক্ষর)" })
  message!: string;
}

/** Soft cap on a member's still-open (non-closed) threads — the same
 *  anti-spam shape as the max-14 open goals. */
export const MAX_OPEN_SUPPORT_THREADS = 5;

@Injectable()
export class SupportService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /**
   * Own thread pre-check (the goals loadForDecision pattern): metadata-only
   * existence read in the system context so the caller gets the CORRECT error
   * (404 missing / 403 someone else's thread) BEFORE any write; the mutation
   * itself still runs in the caller's own RLS context — PostgreSQL is the net.
   */
  private async loadOwnThread(viewer: User, id: string): Promise<ThreadRow> {
    const row = (await this.rls.system((tx) => tx.supportThread.findUnique({ where: { id } }))) as unknown as
      | ThreadRow
      | null;
    if (!row) throw new ApiError(404, "আলাপনাটি পাওয়া যায়নি");
    if (row.userId !== viewer.id) throw new ApiError(403, "এই আলাপনাটি আপনার নয়");
    return row;
  }

  /** POST /api/support — open a thread (subject + first message). */
  async create(viewer: User | null, dto: SupportCreateDto) {
    const user = this.guard.requireUser(viewer);
    const subject = (dto.subject ?? "").trim();
    const body = (dto.message ?? "").trim();
    if (subject.length < 3) throw new ApiError(400, "বিষয় কমপক্ষে ৩ অক্ষরের হতে হবে");
    if (body.length < 3) throw new ApiError(400, "বার্তা কমপক্ষে ৩ অক্ষরের হতে হবে");

    const openCount = await this.rls.run(user, (tx) =>
      tx.supportThread.count({ where: { userId: user.id, status: { not: "closed" } } })
    );
    if (openCount >= MAX_OPEN_SUPPORT_THREADS) {
      throw new ApiError(400, "সর্বোচ্চ ৫টি চলমান আলাপনা রাখা যায় — সাপোর্ট দল বন্ধ করলে নতুন খুলতে পারবেন");
    }

    const thread = await this.rls.run(user, async (tx) => {
      const created = (await tx.supportThread.create({
        data: { userId: user.id, subject, status: "open" },
      })) as unknown as ThreadRow;
      await tx.supportMessage.create({
        data: { threadId: created.id, authorId: user.id, body, isAdmin: false },
      });
      return created;
    });
    return { thread: mapThread(thread) };
  }

  /** GET /api/support — own threads, newest activity first, with stats. */
  async list(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    return this.rls.run(user, async (tx) => {
      const rows = (await tx.supportThread.findMany({
        where: { userId: user.id },
        orderBy: { updatedAt: "desc" },
        take: 50,
      })) as unknown as ThreadRow[];
      if (!rows.length) return { threads: [] };

      // one read for every thread's messages → counts + last message each
      const messages = (await tx.supportMessage.findMany({
        where: { threadId: { in: rows.map((r) => r.id) } },
        orderBy: { createdAt: "asc" },
      })) as unknown as MessageRow[];
      const byThread = new Map<string, MessageRow[]>();
      for (const m of messages) {
        const list = byThread.get(m.threadId) ?? [];
        list.push(m);
        byThread.set(m.threadId, list);
      }

      const threads: SupportThreadListItem[] = rows.map((r) => {
        const msgs = byThread.get(r.id) ?? [];
        const last = msgs.length ? msgs[msgs.length - 1] : null;
        return {
          ...mapThread(r),
          messageCount: msgs.length,
          lastMessageAt: last ? last.createdAt.toISOString() : r.createdAt.toISOString(),
          lastPreview: last ? last.body.slice(0, 120) : null,
          unreadForUser: !!last?.isAdmin,
        };
      });
      return { threads };
    });
  }

  /** GET /api/support/:id — own thread + its messages (asc). */
  async detail(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    await this.loadOwnThread(user, id); // 404 / 403 before anything else

    return this.rls.run(user, async (tx) => {
      const row = (await tx.supportThread.findUnique({ where: { id } })) as unknown as ThreadRow | null;
      if (!row) throw new ApiError(404, "আলাপনাটি পাওয়া যায়নি");
      const messages = (await tx.supportMessage.findMany({
        where: { threadId: id },
        orderBy: { createdAt: "asc" },
        take: 200,
      })) as unknown as MessageRow[];
      return { thread: mapThread(row), messages: messages.map(mapMessage) };
    });
  }

  /**
   * POST /api/support/:id/messages — append to own thread. DECISION (W4d):
   * appending to a CLOSED thread is refused with 400 (no auto-reopen — the
   * member opens a new thread; keeps `closed` a truthful terminal state). A
   * reply on an ANSWERED thread flips it back to "open" (awaits the support
   * team again — the admin queue orders open-first).
   */
  async append(viewer: User | null, id: string, dto: SupportReplyDto) {
    const user = this.guard.requireUser(viewer);
    const row = await this.loadOwnThread(user, id);
    if (row.status === "closed") {
      throw new ApiError(400, "এই আলাপনা বন্ধ করা হয়েছে — প্রয়োজনে নতুন আলাপনা শুরু করুন");
    }
    const body = (dto.message ?? "").trim();
    if (body.length < 3) throw new ApiError(400, "বার্তা কমপক্ষে ৩ অক্ষরের হতে হবে");

    return this.rls.run(user, async (tx) => {
      const message = (await tx.supportMessage.create({
        data: { threadId: id, authorId: user.id, body, isAdmin: false },
      })) as unknown as MessageRow;
      // member reply → back to "open"; the @updatedAt column bumps the
      // thread's last-activity stamp either way.
      await tx.supportThread.update({
        where: { id },
        data: { status: row.status === "answered" ? "open" : row.status },
      });
      return { message: mapMessage(message) };
    });
  }
}

@ApiTags("support")
@Controller("support")
@UseGuards(RolesGuard)
export class SupportController {
  constructor(private readonly service: SupportService) {}

  /** GET /api/support — own threads (id, subject, status, stats, preview). */
  @Get()
  @Roles("user") // any signed-in member (rank 0 floor); RLS scopes the rows
  @ApiOperation({ summary: "Own support threads (newest activity first)" })
  list(@Req() req: AuthedRequest) {
    return this.service.list(currentUser(req));
  }

  /** POST /api/support — open a support thread (subject + first message). */
  @Post()
  @Roles("user")
  @ApiOperation({ summary: "Open a support thread (max 5 open)" })
  create(@Body() dto: SupportCreateDto, @Req() req: AuthedRequest) {
    return this.service.create(currentUser(req), dto);
  }

  /** GET /api/support/:id — own thread + messages. */
  @Get(":id")
  @Roles("user")
  @ApiOperation({ summary: "One own support thread with its messages" })
  detail(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.detail(currentUser(req), id);
  }

  /** POST /api/support/:id/messages — append (400 once closed). */
  @Post(":id/messages")
  @Roles("user")
  @ApiOperation({ summary: "Append a message to an own support thread" })
  append(@Param("id") id: string, @Body() dto: SupportReplyDto, @Req() req: AuthedRequest) {
    return this.service.append(currentUser(req), id, dto);
  }
}
