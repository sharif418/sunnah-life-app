// ─────────────────────────────────────────────────────────────────────────────
// Content workflow (2026-10-09) — every content pack except the Qur'an is
// edited in the admin, reviewed by a scholar, then published:
//
//   editor   → saves a DRAFT (one working copy per pack), submits it
//   reviewer → APPROVES (→ published: the apps get it) or REJECTS with a
//              note (→ back to the editor); never their own draft
//   reviewer → may roll back to any earlier published version
//
// Roles: User.contentRole "editor" | "reviewer" (orthogonal to the tarbiyah
// role; set by full_admin, column-guarded in the DB). full_admin may do both
// — but still not approve their own draft (two people for every change).
//
// Storage: ContentRevision rows (system-only RLS — this service checks the
// content role first). Publishing also writes the pack override file the
// public GET /api/content/:pack already serves (atomic tmp + rename), so the
// read path and the offline bundles are unchanged. The first draft of a pack
// snapshots what is live as version 1, so even the original can be restored.
// ─────────────────────────────────────────────────────────────────────────────
import { Body, Controller, Delete, Get, HttpException, Injectable, Param, Patch, Post, Put, Req } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { promises as fs } from "fs";
import path from "path";

import { ApiError } from "../common/api-error";
import { currentUser, type AuthedRequest } from "../common/auth.guard";
import { GuardService } from "../common/guard.service";
import { RlsService } from "../common/rls.service";
import type { Prisma } from "../common/prisma-client";
import type { ContentRole, User } from "../shared/domain";
import {
  invalidatePackCache,
  loadPack,
  PACK_FILES,
  PACK_KEYS,
  packOverrideDir,
  type PackKey,
} from "../shared/quran";
import { countItems, PACK_LABEL_BN, validatePack, type PackIssue } from "./cms.validation";

/** The packs the CMS manages: everything but the Qur'an (not a pack). */
export const CMS_EDITABLE: PackKey[] = PACK_KEYS;
const MAX_BYTES = 2_000_000;
const WORKING = ["draft", "in_review", "rejected"];

type Tx = Prisma.TransactionClient;

interface RevisionRow {
  id: string;
  pack: string;
  version: number;
  status: string;
  dataJson: unknown;
  itemCount: number;
  note: string | null;
  reviewNote: string | null;
  authorId: string;
  reviewerId: string | null;
  createdAt: Date;
  updatedAt: Date;
  submittedAt: Date | null;
  reviewedAt: Date | null;
  publishedAt: Date | null;
}

export const canEdit = (u: User) =>
  u.role === "full_admin" || u.contentRole === "editor" || u.contentRole === "reviewer";
export const canReview = (u: User) => u.role === "full_admin" || u.contentRole === "reviewer";

@Injectable()
export class CmsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  private requireEditor(viewer: User | null): User {
    const u = this.guard.requireUser(viewer);
    if (!canEdit(u)) throw new ApiError(403, "কনটেন্ট সম্পাদনার অনুমতি নেই");
    return u;
  }

  private requireReviewer(viewer: User | null): User {
    const u = this.guard.requireUser(viewer);
    if (!canReview(u)) throw new ApiError(403, "যাচাই ও প্রকাশের অনুমতি শুধু যাচাইকারী আলেমের");
    return u;
  }

  private packKey(pack: string): PackKey {
    if (!CMS_EDITABLE.includes(pack as PackKey)) throw new ApiError(404, "এই কনটেন্ট পাওয়া যায়নি");
    return pack as PackKey;
  }

  private async names(tx: Tx, ids: (string | null)[]): Promise<Map<string, string>> {
    const want = [...new Set(ids.filter((x): x is string => !!x))];
    if (!want.length) return new Map();
    const rows = await tx.user.findMany({ where: { id: { in: want } }, select: { id: true, name: true } });
    return new Map(rows.map((r) => [r.id, r.name]));
  }

  private meta(r: RevisionRow, names: Map<string, string>) {
    return {
      id: r.id,
      version: r.version,
      status: r.status,
      itemCount: r.itemCount,
      note: r.note,
      reviewNote: r.reviewNote,
      authorId: r.authorId,
      authorName: names.get(r.authorId) ?? null,
      reviewerId: r.reviewerId,
      reviewerName: r.reviewerId ? (names.get(r.reviewerId) ?? null) : null,
      createdAt: r.createdAt.toISOString(),
      updatedAt: r.updatedAt.toISOString(),
      submittedAt: r.submittedAt?.toISOString() ?? null,
      reviewedAt: r.reviewedAt?.toISOString() ?? null,
      publishedAt: r.publishedAt?.toISOString() ?? null,
    };
  }

  private async live(tx: Tx, pack: PackKey): Promise<RevisionRow | null> {
    return (await tx.contentRevision.findFirst({
      where: { pack, status: "published" },
      orderBy: { publishedAt: "desc" },
    })) as RevisionRow | null;
  }

  private async working(tx: Tx, pack: PackKey): Promise<RevisionRow | null> {
    return (await tx.contentRevision.findFirst({
      where: { pack, status: { in: WORKING } },
      orderBy: { version: "desc" },
    })) as RevisionRow | null;
  }

  private async nextVersion(tx: Tx, pack: PackKey): Promise<number> {
    const top = await tx.contentRevision.findFirst({ where: { pack }, orderBy: { version: "desc" } });
    return (top?.version ?? 0) + 1;
  }

  /** The live pack as the apps see it now (override file or the bundle). */
  private async liveData(pack: PackKey): Promise<unknown> {
    invalidatePackCache(pack);
    return (await loadPack(pack)) ?? {};
  }

  /** Writes the pack the apps read (atomic) and drops the read cache. */
  private async writeLive(pack: PackKey, data: unknown): Promise<void> {
    const dir = packOverrideDir();
    await fs.mkdir(dir, { recursive: true });
    const target = path.join(dir, PACK_FILES[pack]);
    const tmp = `${target}.cms-tmp`;
    await fs.writeFile(tmp, `${JSON.stringify(data, null, 2)}\n`, "utf8");
    await fs.rename(tmp, target);
    invalidatePackCache(pack);
  }

  // ── reads ──────────────────────────────────────────────────────────────────

  /** GET /api/admin/cms — every pack: live version, the working copy. */
  async overview(viewer: User | null) {
    const user = this.requireEditor(viewer);
    const rows = await this.rls.system(async (tx) => {
      const all = (await tx.contentRevision.findMany({
        where: { status: { in: ["published", ...WORKING] } },
        orderBy: { version: "desc" },
      })) as RevisionRow[];
      const names = await this.names(tx, all.flatMap((r) => [r.authorId, r.reviewerId]));
      return { all, names };
    });
    const packs = [];
    for (const pack of CMS_EDITABLE) {
      const mine = rows.all.filter((r) => r.pack === pack);
      const live = mine.filter((r) => r.status === "published").sort((a, b) => +(b.publishedAt ?? 0) - +(a.publishedAt ?? 0))[0];
      const work = mine.find((r) => WORKING.includes(r.status));
      packs.push({
        pack,
        labelBn: PACK_LABEL_BN[pack],
        liveVersion: live?.version ?? 0,
        liveItemCount: live ? live.itemCount : countItems(pack, await loadPack(pack)),
        livePublishedAt: live?.publishedAt?.toISOString() ?? null,
        working: work ? this.meta(work, rows.names) : null,
      });
    }
    return {
      packs,
      canReview: canReview(user),
      pendingReview: packs.filter((p) => p.working?.status === "in_review").length,
    };
  }

  /** GET /api/admin/cms/:pack — live data, the working copy, history. */
  async pack(viewer: User | null, pack: string) {
    this.requireEditor(viewer);
    const key = this.packKey(pack);
    const live = await this.liveData(key);
    return this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      const history = (await tx.contentRevision.findMany({
        where: { pack: key, status: { in: ["published", "archived", "rejected"] } },
        orderBy: { version: "desc" },
        take: 40,
      })) as RevisionRow[];
      const names = await this.names(tx, [...history, ...(work ? [work] : [])].flatMap((r) => [r.authorId, r.reviewerId]));
      return {
        pack: key,
        labelBn: PACK_LABEL_BN[key],
        live,
        working: work ? { ...this.meta(work, names), data: work.dataJson, issues: validatePack(key, work.dataJson) } : null,
        history: history.map((r) => this.meta(r, names)),
      };
    });
  }

  /** GET /api/admin/cms/:pack/revisions/:id — one version's content. */
  async revision(viewer: User | null, pack: string, id: string) {
    this.requireEditor(viewer);
    const key = this.packKey(pack);
    return this.rls.system(async (tx) => {
      const r = (await tx.contentRevision.findFirst({ where: { id, pack: key } })) as RevisionRow | null;
      if (!r) throw new ApiError(404, "সংস্করণটি পাওয়া যায়নি");
      const names = await this.names(tx, [r.authorId, r.reviewerId]);
      return { ...this.meta(r, names), data: r.dataJson };
    });
  }

  // ── editing ────────────────────────────────────────────────────────────────

  /** PUT /api/admin/cms/:pack/draft — save the working copy. */
  async saveDraft(viewer: User | null, pack: string, body: { data?: unknown; note?: string }) {
    const user = this.requireEditor(viewer);
    const key = this.packKey(pack);
    const data = body?.data;
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      throw new ApiError(400, "কনটেন্টটি অবজেক্ট আকারে দিন");
    }
    if (JSON.stringify(data).length > MAX_BYTES) throw new ApiError(400, "কনটেন্ট খুব বড় — ছোট করে দিন");
    // the admin autosaves; a save without a note keeps the one already there
    const hasNote = typeof body.note === "string";
    const note = hasNote ? (body.note as string).trim().slice(0, 500) || null : null;
    const live = await this.liveData(key);

    const saved = await this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      if (work?.status === "in_review") {
        throw new ApiError(409, "এই কনটেন্ট যাচাইয়ের অপেক্ষায় — আগে ফেরত নিন, তারপর বদলান");
      }
      if (work) {
        return (await tx.contentRevision.update({
          where: { id: work.id },
          // a rejected draft turns back into a draft; the scholar's note stays
          // beside it until the next decision
          data: {
            dataJson: data as Prisma.InputJsonValue,
            itemCount: countItems(key, data),
            ...(hasNote ? { note } : {}),
            status: "draft",
            authorId: user.id,
          },
        })) as RevisionRow;
      }
      // the first edit of a pack: keep what is live now as version 1, so it
      // can always be restored
      if (!(await tx.contentRevision.findFirst({ where: { pack: key } }))) {
        await tx.contentRevision.create({
          data: {
            pack: key,
            version: 1,
            status: "published",
            dataJson: live as Prisma.InputJsonValue,
            itemCount: countItems(key, live),
            note: "প্রাথমিক সংস্করণ (অ্যাপের সাথে আসা কনটেন্ট)",
            authorId: user.id,
            publishedAt: new Date(),
          },
        });
      }
      return (await tx.contentRevision.create({
        data: {
          pack: key,
          version: await this.nextVersion(tx, key),
          status: "draft",
          dataJson: data as Prisma.InputJsonValue,
          itemCount: countItems(key, data),
          note,
          authorId: user.id,
        },
      })) as RevisionRow;
    });
    return { id: saved.id, version: saved.version, status: saved.status, issues: validatePack(key, data) };
  }

  /** DELETE /api/admin/cms/:pack/draft — throw the working copy away. */
  async discardDraft(viewer: User | null, pack: string) {
    const user = this.requireEditor(viewer);
    const key = this.packKey(pack);
    await this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      if (!work) throw new ApiError(404, "কোনো খসড়া নেই");
      if (work.status === "in_review") throw new ApiError(409, "যাচাইয়ের অপেক্ষায় থাকা খসড়া আগে ফেরত নিন");
      await tx.contentRevision.delete({ where: { id: work.id } });
    });
    await this.guard.audit(user.id, "content_draft_discard", "content_pack", key, { pack: key });
    return { ok: true };
  }

  /** POST /api/admin/cms/:pack/submit — the draft goes to a reviewer. */
  async submit(viewer: User | null, pack: string) {
    const user = this.requireEditor(viewer);
    const key = this.packKey(pack);
    const rev = await this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      if (!work || work.status === "in_review") {
        throw new ApiError(409, work ? "আগেই যাচাইয়ে পাঠানো হয়েছে" : "পাঠানোর মতো কোনো খসড়া নেই");
      }
      const issues = validatePack(key, work.dataJson);
      if (issues.length) {
        throw new HttpException(
          { error: `ঠিক করার বাকি আছে (${issues.length}টি) — যাচাইয়ে পাঠানো যায়নি`, issues },
          400
        );
      }
      return (await tx.contentRevision.update({
        where: { id: work.id },
        data: { status: "in_review", submittedAt: new Date(), authorId: user.id },
      })) as RevisionRow;
    });
    await this.guard.audit(user.id, "content_submit", "content_pack", key, { pack: key, version: rev.version });
    return { id: rev.id, version: rev.version, status: rev.status };
  }

  /** POST /api/admin/cms/:pack/withdraw — take a submitted draft back. */
  async withdraw(viewer: User | null, pack: string) {
    this.requireEditor(viewer);
    const key = this.packKey(pack);
    return this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      if (!work || work.status !== "in_review") throw new ApiError(409, "যাচাইয়ের অপেক্ষায় কিছু নেই");
      const r = (await tx.contentRevision.update({
        where: { id: work.id },
        data: { status: "draft", submittedAt: null },
      })) as RevisionRow;
      return { id: r.id, version: r.version, status: r.status };
    });
  }

  // ── review ─────────────────────────────────────────────────────────────────

  /** POST /api/admin/cms/:pack/review — approve (publish) or reject. */
  async review(viewer: User | null, pack: string, body: { decision?: string; note?: string }) {
    const user = this.requireReviewer(viewer);
    const key = this.packKey(pack);
    const decision = body?.decision;
    const note = typeof body?.note === "string" ? body.note.trim().slice(0, 1000) : "";
    if (decision !== "approve" && decision !== "reject") throw new ApiError(400, "অনুমোদন না ফেরত — বেছে নিন");
    if (decision === "reject" && !note) throw new ApiError(400, "ফেরত দেওয়ার কারণ লিখুন — সম্পাদক যেন ঠিক করতে পারেন");

    const rev = await this.rls.system(async (tx) => {
      const work = await this.working(tx, key);
      if (!work || work.status !== "in_review") throw new ApiError(409, "যাচাইয়ের অপেক্ষায় কিছু নেই");
      if (work.authorId === user.id) {
        throw new ApiError(403, "নিজের লেখা নিজে অনুমোদন করা যায় না — অন্য যাচাইকারী দেখবেন");
      }
      const now = new Date();
      if (decision === "reject") {
        return (await tx.contentRevision.update({
          where: { id: work.id },
          data: { status: "rejected", reviewerId: user.id, reviewedAt: now, reviewNote: note },
        })) as RevisionRow;
      }
      const issues = validatePack(key, work.dataJson);
      if (issues.length) throw new ApiError(400, `খসড়ায় ঠিক করার বাকি আছে (${issues.length}টি)`);
      await tx.contentRevision.updateMany({ where: { pack: key, status: "published" }, data: { status: "archived" } });
      return (await tx.contentRevision.update({
        where: { id: work.id },
        data: {
          status: "published",
          reviewerId: user.id,
          reviewedAt: now,
          publishedAt: now,
          reviewNote: note || null,
        },
      })) as RevisionRow;
    });
    if (rev.status === "published") await this.writeLive(key, rev.dataJson);
    await this.guard.audit(user.id, decision === "approve" ? "content_publish" : "content_reject", "content_pack", key, {
      pack: key,
      version: rev.version,
      itemCount: rev.itemCount,
    });
    return { id: rev.id, version: rev.version, status: rev.status };
  }

  /** POST /api/admin/cms/:pack/rollback — republish an earlier version. */
  async rollback(viewer: User | null, pack: string, body: { revisionId?: string }) {
    const user = this.requireReviewer(viewer);
    const key = this.packKey(pack);
    const rev = await this.rls.system(async (tx) => {
      const src = (await tx.contentRevision.findFirst({
        where: { id: body?.revisionId ?? "", pack: key, status: { in: ["published", "archived"] } },
      })) as RevisionRow | null;
      if (!src) throw new ApiError(404, "ফেরানোর মতো সংস্করণটি পাওয়া যায়নি");
      const now = new Date();
      await tx.contentRevision.updateMany({ where: { pack: key, status: "published" }, data: { status: "archived" } });
      return (await tx.contentRevision.create({
        data: {
          pack: key,
          version: await this.nextVersion(tx, key),
          status: "published",
          dataJson: src.dataJson as Prisma.InputJsonValue,
          itemCount: src.itemCount,
          note: `সংস্করণ ${src.version}-এ ফেরানো হলো`,
          authorId: user.id,
          reviewerId: user.id,
          reviewedAt: now,
          publishedAt: now,
        },
      })) as RevisionRow;
    });
    await this.writeLive(key, rev.dataJson);
    await this.guard.audit(user.id, "content_rollback", "content_pack", key, { pack: key, version: rev.version });
    return { id: rev.id, version: rev.version, status: rev.status };
  }

  // ── who may edit ───────────────────────────────────────────────────────────

  /** PATCH /api/admin/cms/editors/:userId — full_admin sets a content role. */
  async setContentRole(viewer: User | null, userId: string, body: { contentRole?: string | null }) {
    const admin = this.guard.requireUser(viewer);
    this.guard.assertFullAdmin(admin);
    const role = body?.contentRole ?? null;
    if (role !== null && role !== "editor" && role !== "reviewer") {
      throw new ApiError(400, "ভূমিকা: সম্পাদক, যাচাইকারী, অথবা কিছু না");
    }
    const row = await this.rls.system(async (tx) => {
      const u = await tx.user.findUnique({ where: { id: userId } });
      if (!u || u.deletedAt) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      return tx.user.update({ where: { id: userId }, data: { contentRole: role as ContentRole | null } });
    });
    await this.guard.audit(admin.id, "content_role", "user", userId, { contentRole: role });
    return { id: row.id, name: row.name, contentRole: row.contentRole ?? null };
  }

  /** GET /api/admin/cms/editors — the content team. */
  async editors(viewer: User | null) {
    const admin = this.guard.requireUser(viewer);
    this.guard.assertFullAdmin(admin);
    return this.rls.system(async (tx) => {
      const rows = await tx.user.findMany({
        where: { contentRole: { not: null }, deletedAt: null },
        select: { id: true, name: true, phone: true, contentRole: true, gender: true },
        orderBy: { name: "asc" },
      });
      return { editors: rows };
    });
  }
}

export type { PackIssue };

@ApiTags("admin")
@Controller("admin/cms")
export class CmsController {
  constructor(private readonly service: CmsService) {}

  @Get()
  @ApiOperation({ summary: "Content workflow: every pack, its live version and working copy (editors)" })
  overview(@Req() req: AuthedRequest) {
    return this.service.overview(currentUser(req));
  }

  @Get("editors")
  @ApiOperation({ summary: "full_admin: the content team (editors / reviewers)" })
  editors(@Req() req: AuthedRequest) {
    return this.service.editors(currentUser(req));
  }

  @Patch("editors/:userId")
  @ApiOperation({ summary: "full_admin: set a member's content role (editor | reviewer | null)" })
  setContentRole(@Param("userId") userId: string, @Body() body: { contentRole?: string | null }, @Req() req: AuthedRequest) {
    return this.service.setContentRole(currentUser(req), userId, body);
  }

  @Get(":pack")
  @ApiOperation({ summary: "A pack: live content, the working copy (+ issues), version history" })
  pack(@Param("pack") pack: string, @Req() req: AuthedRequest) {
    return this.service.pack(currentUser(req), pack);
  }

  @Get(":pack/revisions/:id")
  @ApiOperation({ summary: "One version's content (preview / compare / rollback)" })
  revision(@Param("pack") pack: string, @Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.revision(currentUser(req), pack, id);
  }

  @Put(":pack/draft")
  @ApiOperation({ summary: "Editor: save the working draft (returns validation issues)" })
  saveDraft(@Param("pack") pack: string, @Body() body: { data?: unknown; note?: string }, @Req() req: AuthedRequest) {
    return this.service.saveDraft(currentUser(req), pack, body);
  }

  @Delete(":pack/draft")
  @ApiOperation({ summary: "Editor: discard the working draft" })
  discardDraft(@Param("pack") pack: string, @Req() req: AuthedRequest) {
    return this.service.discardDraft(currentUser(req), pack);
  }

  @Post(":pack/submit")
  @ApiOperation({ summary: "Editor: send the draft to review (must pass validation)" })
  submit(@Param("pack") pack: string, @Req() req: AuthedRequest) {
    return this.service.submit(currentUser(req), pack);
  }

  @Post(":pack/withdraw")
  @ApiOperation({ summary: "Editor: take a submitted draft back" })
  withdraw(@Param("pack") pack: string, @Req() req: AuthedRequest) {
    return this.service.withdraw(currentUser(req), pack);
  }

  @Post(":pack/review")
  @ApiOperation({ summary: "Reviewer: approve (publish) or reject (with a note) — never one's own draft" })
  review(@Param("pack") pack: string, @Body() body: { decision?: string; note?: string }, @Req() req: AuthedRequest) {
    return this.service.review(currentUser(req), pack, body);
  }

  @Post(":pack/rollback")
  @ApiOperation({ summary: "Reviewer: republish an earlier version" })
  rollback(@Param("pack") pack: string, @Body() body: { revisionId?: string }, @Req() req: AuthedRequest) {
    return this.service.rollback(currentUser(req), pack, body);
  }
}
