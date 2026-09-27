import { Req, Body, Controller, Get, Patch, Post, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";
import { addDays } from "../shared/calendars";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { toDomainUser } from "../common/mappers";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import {
  bdToday,
  completion7dForUsers,
  invalidateDefinitionCache,
  loadActiveDefinitions,
  mapDefinition,
  ownUsrahIds,
  type AmalDefRow,
} from "../shared/amal";
import { computeRequirements } from "../shared/levels";
import { LEVEL_LABELS_BN } from "../shared/domain";
import type {
  AmalCadence,
  AmalCategory,
  AmalInputType,
  AmalValue,
  AuditEntry,
  Gender,
  Level,
  MonthGrid,
  MonthGridCell,
  Role,
  UsrahHealth,
  User,
  UserCategory,
} from "../shared/domain";

const INACTIVE_DAYS = 3;
const REVIEW_WINDOW_DAYS = 27; // last 4 Saturday-started weeks

const ROLES: Role[] = ["user", "daee", "usrah_head", "invigilator", "full_admin"];
const GENDERS: Gender[] = ["M", "F"];
const CATEGORIES: UserCategory[] = ["general", "hafez", "alim"];
const LEVELS: Level[] = ["none", "muhibbus_sunnah", "farze_ain_1", "farze_ain_2"];
const INPUT_TYPES: AmalInputType[] = ["tristate", "boolean", "count", "quantity", "text"];
const CADENCES: AmalCadence[] = ["daily", "weekly:any", "weekly:fri", "weekly:mon_thu", "monthly:ayyam_beez"];
const AMAL_CATEGORIES: AmalCategory[] = [
  "salah", "quran", "dhikr", "akhlaq", "dawat", "lifestyle", "sunnah", "personal",
];

export class AdminUserPatchDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;

  @ApiProperty({ required: false, enum: ROLES })
  @IsOptional()
  @IsIn(ROLES as unknown as string[], { message: "ভূমিকা ঠিক নয়" })
  role?: Role;

  @ApiProperty({ required: false, enum: GENDERS })
  @IsOptional()
  @IsIn(GENDERS as unknown as string[], { message: "লিঙ্গ ঠিক নয়" })
  gender?: Gender;

  @ApiProperty({ required: false, nullable: true })
  @IsOptional()
  usrahId?: string | null;

  @ApiProperty({ required: false, enum: CATEGORIES })
  @IsOptional()
  @IsIn(CATEGORIES as unknown as string[], { message: "ক্যাটাগরি ঠিক নয়" })
  category?: UserCategory;
}

export class PromoteDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;

  @ApiProperty({ enum: LEVELS })
  @IsIn(LEVELS as unknown as string[], { message: "স্তর ঠিক নয়" })
  toLevel!: Level;
}

export class BroadcastDto {
  @ApiProperty({ required: false, nullable: true })
  @IsOptional()
  usrahId?: string | null;

  @ApiProperty({ required: false, enum: GENDERS, nullable: true })
  @IsOptional()
  @IsIn(GENDERS as unknown as string[], { message: "লিঙ্গ ঠিক নয়" })
  gender?: Gender | null;

  @ApiProperty({ example: "আগামী শুক্রবার মজলিস ইনশাআল্লাহ" })
  @IsString({ message: "ঘোষণার লেখা লিখুন" })
  @IsNotEmpty({ message: "ঘোষণার লেখা লিখুন" })
  @MaxLength(2000)
  body!: string;
}

export class AmalCatalogDto {
  @ApiProperty({ example: "tilawat" })
  @IsString({ message: "আমলের কী (key) দিন" })
  @IsNotEmpty({ message: "আমলের কী (key) দিন" })
  key!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  titleBn?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  titleEn?: string;

  @ApiProperty({ required: false, enum: AMAL_CATEGORIES })
  @IsOptional()
  @IsIn(AMAL_CATEGORIES as unknown as string[], { message: "ক্যাটাগরি ঠিক নয়" })
  category?: AmalCategory;

  @ApiProperty({ required: false, enum: INPUT_TYPES })
  @IsOptional()
  @IsIn(INPUT_TYPES as unknown as string[], { message: "ইনপুট ধরন ঠিক নয়" })
  inputType?: AmalInputType;

  @ApiProperty({ required: false, enum: CADENCES })
  @IsOptional()
  @IsIn(CADENCES as unknown as string[], { message: "পর্যায়ক্রম ঠিক নয়" })
  cadence?: AmalCadence;

  @ApiProperty({ required: false, type: Object })
  @IsOptional()
  target?: Record<string, number> | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  unit?: string | null;

  @ApiProperty({ required: false, enum: LEVELS })
  @IsOptional()
  @IsIn(LEVELS as unknown as string[], { message: "স্তর ঠিক নয়" })
  minLevel?: Level;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  sortOrder?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  autoSource?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  active?: boolean;
}

@Injectable()
export class AdminService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /** GET /api/admin/overview — role-scoped dashboard. */
  async overview(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "অ্যাডমিন প্যানেল দেখার অনুমতি নেই");

    return this.rls.run(user, async (tx) => {
      const usrahRows =
        user.role === "full_admin"
          ? await tx.usrah.findMany({ include: { members: true }, orderBy: { name: "asc" } })
          : user.role === "invigilator"
            ? await tx.usrah.findMany({ where: { gender: user.gender }, include: { members: true }, orderBy: { name: "asc" } })
            : await tx.usrah.findMany({
                where: { OR: [{ headUserId: user.id }, ...(user.usrahId ? [{ id: user.usrahId }] : [])] },
                include: { members: true },
                orderBy: { name: "asc" },
              });

      const scopedUserIds = [...new Set(usrahRows.flatMap((u) => u.members.map((m) => m.id)))];
      const completions = await completion7dForUsers(
        tx,
        usrahRows.flatMap((u) => u.members.map((m) => ({ id: m.id, category: m.category })))
      );

      const now = Date.now();
      const inactiveBefore = new Date(now - INACTIVE_DAYS * 86_400_000);
      const weekStartCutoff = addDays(bdToday(), -REVIEW_WINDOW_DAYS);

      const usrahs: UsrahHealth[] = [];
      for (const u of usrahRows) {
        const members = u.members;
        const memberIds = members.map((m) => m.id);
        const doneReviews = memberIds.length
          ? await tx.weeklyReview.count({
              where: { userId: { in: memberIds }, status: "done", weekStart: { gte: weekStartCutoff } },
            })
          : 0;
        const expected = members.length * 4;
        const reviewPct = expected > 0 ? Math.min(100, Math.round((100 * doneReviews) / expected)) : 0;
        const avgCompletion = members.length
          ? Math.round(members.reduce((s, m) => s + (completions.get(m.id) ?? 0), 0) / members.length)
          : 0;
        const inactiveCount = members.filter((m) => m.lastActiveAt < inactiveBefore).length;

        usrahs.push({
          id: u.id,
          name: u.name,
          gender: u.gender as Gender,
          district: u.district,
          members: members.length,
          reviewPct,
          avgCompletion,
          inactiveCount,
        });
      }

      const totals = {
        users: scopedUserIds.length,
        daees: await tx.user.count({
          where: scopedUserIds.length ? { id: { in: scopedUserIds }, role: "daee" } : { id: "__none__" },
        }),
        usrahs: usrahRows.length,
        pendingReviews: scopedUserIds.length
          ? await tx.weeklyReview.count({ where: { userId: { in: scopedUserIds }, status: "pending" } })
          : 0,
      };

      const auditRows = await tx.auditLog.findMany({
        where: user.role === "full_admin" ? undefined : { actorId: user.id },
        orderBy: { createdAt: "desc" },
        take: 15,
      });
      const actorIds = [...new Set(auditRows.map((a) => a.actorId).filter((x): x is string => !!x))];
      const actors = actorIds.length
        ? await tx.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true } })
        : [];
      const actorNames = new Map(actors.map((a) => [a.id, a.name]));

      const recentAudit: AuditEntry[] = auditRows.map((a) => ({
        id: a.id,
        actorId: a.actorId,
        actorName: a.actorId ? actorNames.get(a.actorId) ?? null : null,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        meta: (a.metaJson as Record<string, unknown> | null) ?? null,
        createdAt: a.createdAt.toISOString(),
      }));

      return { role: user.role as Role, totals, usrahs, recentAudit };
    });
  }

  /** GET /api/admin/users?q= — gender-scoped user search with usrahName. */
  async users(viewer: User | null, q: string) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "অ্যাডমিন প্যানেল দেখার অনুমতি নেই");

    const like = searchFilter(q);
    return this.rls.run(user, async (tx) => {
      let where: Record<string, unknown>;
      if (user.role === "full_admin") {
        where = like;
      } else if (user.role === "invigilator") {
        where = { gender: user.gender, ...like };
      } else {
        const usrahIds = await ownUsrahIds(tx, user);
        where = usrahIds.length ? { usrahId: { in: usrahIds }, ...like } : { id: "__none__" };
      }

      const rows = await tx.user.findMany({
        where: where as never,
        include: { usrah: { select: { name: true } } },
        orderBy: { name: "asc" },
        take: 100,
      });

      const users: (import("../shared/domain").User & { usrahName?: string | null })[] = rows.map((r) => ({
        ...toDomainUser(r as never),
        usrahName: r.usrah?.name ?? null,
      }));
      return { users };
    });
  }

  /**
   * PATCH /api/admin/users — full_admin only. Change role / gender / usrah /
   * category. Gender & role changes are audit-logged; promoting to daee
   * assigns the next member code if the user has none.
   */
  async patchUser(viewer: User | null, dto: AdminUserPatchDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!dto.userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    return this.rls.run(user, async (tx) => {
      const target = await tx.user.findUnique({ where: { id: dto.userId } });
      if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");

      const data: Record<string, unknown> = {};

      if (dto.role !== undefined) {
        if (!ROLES.includes(dto.role as Role)) throw new ApiError(400, "ভূমিকা ঠিক নয়");
        if (dto.role !== target.role) {
          await this.guard.audit(user.id, "change_role", "user", target.id, {
            userId: target.id,
            from: target.role,
            to: dto.role,
          });
          if (dto.role === "daee" && !target.memberCode) {
            data.memberCode = await nextMemberCode(tx);
          }
          data.role = dto.role;
        }
      }

      if (dto.gender !== undefined) {
        if (!GENDERS.includes(dto.gender as Gender)) throw new ApiError(400, "লিঙ্গ ঠিক নয়");
        if (dto.gender !== target.gender) {
          await this.guard.audit(user.id, "change_gender", "user", target.id, {
            userId: target.id,
            from: target.gender,
            to: dto.gender,
          });
          data.gender = dto.gender;
        }
      }

      if (dto.usrahId !== undefined) {
        if (dto.usrahId === null) {
          data.usrahId = null;
        } else {
          const usrah = await tx.usrah.findUnique({ where: { id: dto.usrahId } });
          if (!usrah) throw new ApiError(400, "উসরা পাওয়া যায়নি");
          data.usrahId = dto.usrahId;
        }
      }

      if (dto.category !== undefined) {
        if (!CATEGORIES.includes(dto.category as UserCategory)) throw new ApiError(400, "ক্যাটাগরি ঠিক নয়");
        data.category = dto.category;
      }

      if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

      const updated = await tx.user.update({ where: { id: target.id }, data: data as never });
      return { user: toDomainUser(updated as never) };
    });
  }

  /** GET /api/admin/month-grid?userId&month — 31-column heatmap data. */
  async monthGrid(viewer: User | null, userId: string | undefined, month: string) {
    const user = this.guard.requireUser(viewer);
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw new ApiError(400, "মাস ঠিকভাবে দিন (YYYY-MM)");

    const target = await this.guard.assertCanAccess(user, userId);

    return this.rls.run(user, async (tx) => {
      const [y, m] = month.split("-").map(Number);
      const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
      const days = Array.from({ length: lastDay }, (_, i) => `${month}-${String(i + 1).padStart(2, "0")}`);

      const definitions = (await loadActiveDefinitions(tx)).map(mapDefinition);
      const entries = (await tx.amalEntry.findMany({
        where: { userId: target.id, date: { gte: days[0], lte: days[days.length - 1] } },
      })) as unknown as { amalKey: string; date: string; valueJson: unknown; source: string }[];
      const cellMap = new Map(entries.map((e) => [`${e.amalKey}|${e.date}`, e]));

      const amalKeys: string[] = [];
      const rows: Record<string, MonthGridCell[]> = {};
      for (const def of definitions) {
        amalKeys.push(def.key);
        rows[def.key] = days.map((date) => {
          const e = cellMap.get(`${def.key}|${date}`);
          if (!e) return { date, value: null, source: "none" };
          const value = (e.valueJson === null || e.valueJson === undefined ? 0 : e.valueJson) as AmalValue;
          return { date, value, source: e.source };
        });
      }

      const grid: MonthGrid = { amalKeys, definitions, days, rows };
      return { grid };
    });
  }

  /**
   * POST /api/admin/promote — full_admin promotes a user one level up. For the
   * muhibbus-sunnah promotion the tarbiyah requirements are validated; anything
   * unmet → 422 with the missing requirements in Bengali. Writes a
   * LevelTransition, an audit entry and a reminder for the user.
   */
  async promote(viewer: User | null, dto: PromoteDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!dto.userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    const toLevel = dto.toLevel;
    if (!toLevel || !LEVELS.includes(toLevel)) throw new ApiError(400, "স্তর ঠিক নয়");

    return this.rls.run(user, async (tx) => {
      const target = await tx.user.findUnique({ where: { id: dto.userId } });
      if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      if (target.level === toLevel) throw new ApiError(400, "ব্যবহারকারী ইতিমধ্যেই এই স্তরে আছেন");

      const fromLevel = target.level;
      const domainUser = toDomainUser(target as never);

      // requirement validation applies to the muhibbus-sunnah promotion
      if (toLevel === "muhibbus_sunnah") {
        const requirements = await computeRequirements(tx, domainUser);
        const missing = requirements.filter((r) => !r.done);
        if (missing.length) {
          throw new ApiError(422, `চাহিদা পূরণ হয়নি: ${missing.map((r) => r.label).join("; ")}`);
        }
      }

      const now = new Date();
      const updated = await tx.user.update({
        where: { id: target.id },
        data: { level: toLevel, levelStartedAt: now },
      });

      await tx.levelTransition.create({
        data: {
          userId: target.id,
          fromLevel,
          toLevel,
          evidenceJson: {
            requirements: (await computeRequirements(tx, toDomainUser(updated as never))).map((r) => ({
              key: r.key,
              done: r.done,
            })),
            promotedBy: user.id,
          } as never,
        },
      });

      await this.guard.audit(user.id, "promote_level", "user", target.id, {
        userId: target.id,
        fromLevel,
        toLevel,
      });

      await tx.reminder.create({
        data: {
          userId: target.id,
          kind: "review",
          title: "আপনি নতুন স্তরে উন্নীত হয়েছেন",
          body: `অভিনন্দন! আপনি এখন ${LEVEL_LABELS_BN[toLevel]} স্তরে আছেন।`,
        },
      });

      return { user: toDomainUser(updated as never) };
    });
  }

  /**
   * POST /api/admin/broadcast — usrah_head+. Creates an Announcement (usrah-
   * scoped or global) and fans out Reminders. Scoping: heads → own usrahs;
   * invigilator → own-gender usrahs/all own-gender users; full_admin → anything.
   */
  async broadcast(viewer: User | null, dto: BroadcastDto) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "ঘোষণা পাঠানোর অনুমতি নেই");

    const text = (dto.body ?? "").toString().trim().slice(0, 2000);
    if (!text) throw new ApiError(400, "ঘোষণার লেখা লিখুন");

    const usrahId = dto.usrahId ?? null;
    const gender = dto.gender ?? null;

    if (!usrahId && !gender && user.role !== "full_admin") {
      throw new ApiError(403, "সবার জন্য ঘোষণা শুধু প্রধান অ্যাডমিন পাঠাতে পারবেন");
    }

    return this.rls.run(user, async (tx) => {
      let targetUserIds: string[] = [];

      if (usrahId) {
        const usrah = await tx.usrah.findUnique({ where: { id: usrahId }, include: { members: true } });
        if (!usrah) throw new ApiError(400, "উসরা পাওয়া যায়নি");
        if (user.role !== "full_admin") {
          const own = await ownUsrahIds(tx, user);
          const sameGenderOk = user.role === "invigilator" && usrah.gender === user.gender;
          if (!own.includes(usrahId) && !sameGenderOk) {
            throw new ApiError(403, "শুধু নিজের উসরার জন্য ঘোষণা পাঠানো যাবে");
          }
        }
        targetUserIds = usrah.members.map((m) => m.id);
      } else if (gender) {
        if (user.role !== "full_admin" && gender !== user.gender) {
          throw new ApiError(403, "বিপরীত লিঙ্গের জন্য ঘোষণা পাঠানো যাবে না");
        }
        const users = await tx.user.findMany({ where: { gender }, select: { id: true } });
        targetUserIds = users.map((u) => u.id);
      } else {
        const users = await tx.user.findMany({ select: { id: true } });
        targetUserIds = users.map((u) => u.id);
      }

      const announcement = await tx.announcement.create({
        data: { usrahId, authorId: user.id, kind: "announcement", body: text, pinned: false },
      });

      if (targetUserIds.length) {
        await tx.reminder.createMany({
          data: targetUserIds.map((id) => ({
            userId: id,
            kind: "broadcast",
            title: "নতুন ঘোষণা",
            body: text.slice(0, 200),
          })),
        });
      }

      await this.guard.audit(user.id, "broadcast", "announcement", announcement.id, {
        usrahId,
        gender,
        recipients: targetUserIds.length,
      });

      return { ok: true };
    });
  }

  /**
   * POST /api/admin/amal-catalog — full_admin upserts an AmalDefinition by
   * key. Accepts `target` (object) or a raw `targetJson` string.
   */
  async upsertCatalog(viewer: User | null, dto: AmalCatalogDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    const key = (dto.key ?? "").trim();
    if (!key) throw new ApiError(400, "আমলের কী (key) দিন");

    await this.rls.run(user, async (tx) => {
      const existing = await tx.amalDefinition.findUnique({ where: { key } });

      const titleBn = (dto.titleBn ?? existing?.titleBn ?? "").trim();
      const titleEn = (dto.titleEn ?? existing?.titleEn ?? "").trim();
      if (!titleBn) throw new ApiError(400, "বাংলা শিরোনাম দিন");

      const category = (dto.category ?? (existing?.category as AmalCategory) ?? "sunnah");
      if (!AMAL_CATEGORIES.includes(category)) throw new ApiError(400, "ক্যাটাগরি ঠিক নয়");

      const inputType = (dto.inputType ?? (existing?.inputType as AmalInputType) ?? "tristate");
      if (!INPUT_TYPES.includes(inputType)) throw new ApiError(400, "ইনপুট ধরন ঠিক নয়");

      const cadence = (dto.cadence ?? (existing?.cadence as AmalCadence) ?? "daily");
      if (!CADENCES.includes(cadence)) throw new ApiError(400, "পর্যায়ক্রম ঠিক নয়");

      let targetJson: unknown = null;
      if (dto.target && typeof dto.target === "object") {
        targetJson = dto.target;
      } else if (dto.target === null) {
        targetJson = null;
      } else {
        targetJson = (existing?.targetJson as unknown) ?? null;
      }

      const minLevel = (dto.minLevel ?? (existing?.minLevel as Level) ?? "none");
      if (!LEVELS.includes(minLevel)) throw new ApiError(400, "স্তর ঠিক নয়");

      const sortOrder = Number.isFinite(Number(dto.sortOrder)) ? Number(dto.sortOrder) : (existing?.sortOrder ?? 0);
      const active = typeof dto.active === "boolean" ? dto.active : (existing?.active ?? true);

      await tx.amalDefinition.upsert({
        where: { key },
        create: {
          key,
          titleBn,
          titleEn,
          category,
          inputType,
          cadence,
          targetJson: targetJson as never,
          unit: dto.unit != null ? String(dto.unit) : (existing?.unit ?? null),
          minLevel,
          sortOrder,
          autoSource: dto.autoSource != null ? String(dto.autoSource) : (existing?.autoSource ?? null),
          active,
        },
        update: {
          titleBn,
          titleEn,
          category,
          inputType,
          cadence,
          targetJson: targetJson as never,
          unit: dto.unit != null ? String(dto.unit) : (existing?.unit ?? null),
          minLevel,
          sortOrder,
          autoSource: dto.autoSource != null ? String(dto.autoSource) : (existing?.autoSource ?? null),
          active,
        },
      });
    });

    invalidateDefinitionCache();
    const rows = (await this.rls.run(user, (tx) => loadActiveDefinitions(tx))) as AmalDefRow[];
    return { definitions: rows.map(mapDefinition) };
  }

  /** GET /api/admin/audit — full_admin: last 100 audit entries with actor names. */
  async audit(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const rows = await tx.auditLog.findMany({ orderBy: { createdAt: "desc" }, take: 100 });
      const actorIds = [...new Set(rows.map((a) => a.actorId).filter((x): x is string => !!x))];
      const actors = actorIds.length
        ? await tx.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true } })
        : [];
      const actorNames = new Map(actors.map((a) => [a.id, a.name]));

      const entries: AuditEntry[] = rows.map((a) => ({
        id: a.id,
        actorId: a.actorId,
        actorName: a.actorId ? actorNames.get(a.actorId) ?? null : null,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        meta: (a.metaJson as Record<string, unknown> | null) ?? null,
        createdAt: a.createdAt.toISOString(),
      }));
      return { entries };
    });
  }
}

function searchFilter(q: string) {
  const term = (q ?? "").trim();
  if (!term) return {};
  // mode:"insensitive" — PostgreSQL contains is case-sensitive by default;
  // the web mirror (SQLite) searched case-insensitively.
  return {
    OR: [
      { name: { contains: term, mode: "insensitive" } },
      { phone: { contains: term, mode: "insensitive" } },
      { memberCode: { contains: term.toUpperCase(), mode: "insensitive" } },
    ],
  };
}

/** Next DS-XXXXXX member code: max numeric suffix + 1. */
async function nextMemberCode(tx: import("@prisma/client").Prisma.TransactionClient): Promise<string> {
  const rows = await tx.user.findMany({ where: { memberCode: { not: null } }, select: { memberCode: true } });
  let max = 0;
  for (const r of rows) {
    const m = /^DS-(\d+)$/.exec(r.memberCode ?? "");
    if (m) max = Math.max(max, Number(m[1]));
  }
  return `DS-${String(max + 1).padStart(6, "0")}`;
}

@ApiTags("admin")
@Controller("admin")
@UseGuards(RolesGuard)
// Supervisors and above (usrah_head / invigilator / full_admin); the services
// re-check finer scopes (assertFullAdmin, gender/usrah RLS) per route.
@Roles("usrah_head")
export class AdminController {
  constructor(private readonly service: AdminService) {}

  @Get("overview")
  @ApiOperation({ summary: "Role-scoped admin overview (usrah health)" })
  overview(@Req() req: AuthedRequest) {
    return this.service.overview(currentUser(req));
  }

  @Get("users")
  @ApiOperation({ summary: "Scoped user search" })
  users(@Query("q") q: string | undefined, @Req() req: AuthedRequest) {
    return this.service.users(currentUser(req), q ?? "");
  }

  @Patch("users")
  @ApiOperation({ summary: "full_admin: change role/gender/usrah/category (audited)" })
  @Roles("full_admin")
  patchUser(@Body() dto: AdminUserPatchDto, @Req() req: AuthedRequest) {
    return this.service.patchUser(currentUser(req), dto);
  }

  @Get("month-grid")
  @ApiOperation({ summary: "31-column month heatmap data (guard-checked)" })
  monthGrid(
    @Query("userId") userId: string | undefined,
    @Query("month") month: string,
    @Req() req: AuthedRequest
  ) {
    return this.service.monthGrid(currentUser(req), userId, month);
  }

  @Post("promote")
  @ApiOperation({ summary: "full_admin: promote a level (validates requirements)" })
  @Roles("full_admin")
  promote(@Body() dto: PromoteDto, @Req() req: AuthedRequest) {
    return this.service.promote(currentUser(req), dto);
  }

  @Post("broadcast")
  @ApiOperation({ summary: "usrah_head+: announcement + reminder fan-out" })
  broadcast(@Body() dto: BroadcastDto, @Req() req: AuthedRequest) {
    return this.service.broadcast(currentUser(req), dto);
  }

  @Post("amal-catalog")
  @ApiOperation({ summary: "full_admin: upsert an amal definition by key" })
  @Roles("full_admin")
  upsertCatalog(@Body() dto: AmalCatalogDto, @Req() req: AuthedRequest) {
    return this.service.upsertCatalog(currentUser(req), dto);
  }

  @Get("audit")
  @ApiOperation({ summary: "full_admin: last 100 audit entries" })
  @Roles("full_admin")
  audit(@Req() req: AuthedRequest) {
    return this.service.audit(currentUser(req));
  }
}
