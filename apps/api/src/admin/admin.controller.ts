import { Req, Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Put, Query, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiProperty, ApiTags } from "@nestjs/swagger";
import { Injectable } from "@nestjs/common";
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from "class-validator";
import { addDays } from "../shared/calendars";
import { RlsService } from "../common/rls.service";
import { PrismaService } from "../common/prisma.service";
import { invalidateAppConfigCache, mergeConfig } from "../config/config.controller";
import { GuardService } from "../common/guard.service";
import { PushService } from "../push/push.service";
import { DEEP_LINKS } from "../push/deep-links";
import { toDomainUser } from "../common/mappers";
import { currentUser } from "../common/auth.guard";
import type { AuthedRequest } from "../common/auth.guard";
import { ApiError } from "../common/api-error";
import { Roles } from "../common/roles.decorator";
import { RolesGuard } from "../common/roles.guard";
import { LevelsService, requireBengaliReason } from "../levels/levels.service";
import {
  invalidateLevelRulesCache,
  loadLevelRulesDoc,
  validateLevelRulesNode,
  LevelRulesValidationError,
  type LevelKey,
} from "../shared/levels";
import { SupportReplyDto } from "../support/support.controller";
import {
  bdToday,
  completion7dForUsers,
  invalidateDefinitionCache,
  loadActiveDefinitions,
  mapDefinition,
  ownUsrahIds,
  type AmalDefRow,
} from "../shared/amal";
import type {
  AmalCadence,
  AmalCategory,
  AmalInputType,
  AmalValue,
  AssessmentSection,
  AuditEntry,
  Gender,
  InvigilatorHealthItem,
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

  /** REQUIRED (Bengali) whenever gender actually changes. */
  @ApiProperty({ required: false, example: "ভুল তথ্য সংশোধন — সদস্য নিজে অনুরোধ করেছেন" })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

/** PATCH /api/admin/config — partial AppConfig update (CMS). */
export class AppConfigAdminDto {
  @ApiProperty({ required: false, example: "https://as-sunnah.org/donation" })
  @IsOptional()
  @IsString()
  donationUrl?: string;

  @ApiProperty({ required: false, example: "sunnahlife.app" })
  @IsOptional()
  @IsString()
  domain?: string;

  @ApiProperty({ required: false, example: -1, description: "Hijri ±adjust (−2..2)" })
  @IsOptional()
  @IsInt()
  hijriAdjust?: number;

  @ApiProperty({ required: false, type: Object })
  @IsOptional()
  nisab?: { goldPerGramBdt?: number; silverPerGramBdt?: number };

  @ApiProperty({ required: false, type: [Object] })
  @IsOptional()
  contacts?: unknown[];

  @ApiProperty({ required: false, type: [Object] })
  @IsOptional()
  groups?: unknown[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  audioBase?: string;

  @ApiProperty({ required: false, description: "gender-scoped leaderboard (scholars' decision pending)" })
  @IsOptional()
  @IsBoolean()
  leaderboardEnabled?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  detoxEnabled?: boolean;
}

export class PromoteDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;

  @ApiProperty({ enum: LEVELS })
  @IsIn(LEVELS as unknown as string[], { message: "স্তর ঠিক নয়" })
  toLevel!: Level;

  /** Required when the TARGET level's rules demand the usrah head's outline
   * review (Muhibbus Sunnah model, Phase C/D): the promoting admin attests
   * that the head has reviewed every outline goal item by item. */
  @ApiProperty({ required: false })
  @IsBoolean()
  outlineReviewed?: boolean;
  /** REQUIRED (Bengali) — recorded on the LevelTransition + audit entry. */
  @ApiProperty({ example: "তারবিয়াত পরিষদের সিদ্ধান্তে সকল শর্ত পূরণ হয়েছে" })
  @IsString({ message: "উন্নয়নের কারণ লিখুন" })
  @IsNotEmpty({ message: "উন্নয়নের কারণ লিখুন" })
  @MaxLength(500)
  reason!: string;
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

export class AmalCatalogPatchDto {
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
  @IsObject()
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
  @Min(0)
  sortOrder?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  autoSource?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class AmalCatalogReorderDto {
  @ApiProperty({ type: [String], example: ["salat_fajr", "tilawat"] })
  @IsArray()
  @IsString({ each: true, message: "আমলের কী তালিকা দিন" })
  keys!: string[];
}

export class TemplateCreateDto {
  @ApiProperty({ example: "farze_ain_v1" })
  @IsString({ message: "টেমপ্লেটের কী (key) দিন" })
  @IsNotEmpty({ message: "টেমপ্লেটের কী (key) দিন" })
  key!: string;

  @ApiProperty({ required: false, example: 2 })
  @IsOptional()
  @IsInt()
  @Min(1)
  version?: number;

  @ApiProperty({ example: "ফরযে আইন মূল্যায়ন (সংশোধিত)" })
  @IsString({ message: "বাংলা শিরোনাম দিন" })
  @IsNotEmpty({ message: "বাংলা শিরোনাম দিন" })
  titleBn!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  titleEn?: string;

  @ApiProperty({ type: Object })
  @IsObject({ message: "বিভাগসমূহ (sections) দিন" })
  sections!: unknown;
}

export class TemplatePatchDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  titleBn?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  titleEn?: string;

  @ApiProperty({ required: false, type: Object })
  @IsOptional()
  @IsObject()
  sections?: unknown;
}

export class UsrahCreateDto {
  @ApiProperty({ example: "উসরা আল-হুদা" })
  @IsString({ message: "উসরার নাম দিন" })
  @IsNotEmpty({ message: "উসরার নাম দিন" })
  @MaxLength(120)
  name!: string;

  @ApiProperty({ enum: GENDERS })
  @IsIn(GENDERS as unknown as string[], { message: "লিঙ্গ ঠিক নয়" })
  gender!: Gender;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  district?: string;
}

export class UsrahPatchDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiProperty({ required: false, nullable: true })
  @IsOptional()
  headUserId?: string | null;

  @ApiProperty({ required: false, nullable: true })
  @IsOptional()
  invigilatorUserId?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  district?: string | null;
}

export class UsrahMemberDto {
  @ApiProperty()
  @IsString({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  @IsNotEmpty({ message: "ব্যবহারকারী নির্বাচন করা হয়নি" })
  userId!: string;
}

export class LiveProgramDto {
  @ApiProperty({ example: "সাপ্তাহিক তাফসীর মজলিস" })
  @IsString({ message: "শিরোনাম দিন" })
  @IsNotEmpty({ message: "শিরোনাম দিন" })
  @MaxLength(200)
  titleBn!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  descBn?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  hostName?: string | null;

  @ApiProperty({ example: "2025-07-04T14:00:00.000Z" })
  @IsDateString({}, { message: "শুরুর সময় ঠিকভাবে দিন" })
  startsAt!: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsDateString({}, { message: "শেষের সময় ঠিকভাবে দিন" })
  endsAt?: string | null;

  /** YouTube video id OR a full watch/embed URL (id is extracted). */
  @ApiProperty({ required: false, example: "dQw4w9WgXcQ" })
  @IsOptional()
  @IsString()
  youtubeId?: string | null;

  @ApiProperty({ required: false, enum: GENDERS })
  @IsOptional()
  @IsIn(GENDERS as unknown as string[], { message: "লিঙ্গ ঠিক নয়" })
  gender?: Gender;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  recordingUrl?: string | null;
}

@Injectable()
export class AdminService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly push: PushService,
    private readonly levels: LevelsService,
    private readonly prisma: PrismaService
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
          // B6: gender changes are full_admin-only AND need a Bengali reason —
          // the audit entry must explain why the protected attribute moved.
          const reason = requireBengaliReason(dto.reason);
          await this.guard.audit(user.id, "change_gender", "user", target.id, {
            userId: target.id,
            from: target.gender,
            to: dto.gender,
            reason,
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
          // GENDER RULE on every path: an usrah is single-gender — a
          // cross-gender assignment is rejected even for full_admin (the
          // DB column guard would also block it; this gives a real message).
          const targetGender = (dto.gender ?? target.gender) as string;
          if (usrah.gender !== targetGender) {
            throw new ApiError(400, "উসরা এক-লিঙ্গ — বিপরীত লিঙ্গের সদস্য এই উসরায় নেওয়া যায় না");
          }
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
   * POST /api/admin/promote — full_admin promotes a user one level up
   * (manual override; a Bengali reason is REQUIRED and lands on the
   * LevelTransition + audit entry). For the muhibbus-sunnah promotion the
   * tarbiyah requirements are validated; anything unmet → 422 with the
   * missing requirements in Bengali. The nightly "levels" job runs the same
   * evaluation with method "auto".
   */
  async promote(viewer: User | null, dto: PromoteDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!dto.userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    const toLevel = dto.toLevel;
    if (!toLevel || !LEVELS.includes(toLevel)) throw new ApiError(400, "স্তর ঠিক নয়");
    const reason = requireBengaliReason(dto.reason);

    const result = await this.rls.run(user, async (tx) => {
      const target = await tx.user.findUnique({ where: { id: dto.userId } });
      if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      if (target.level === toLevel) throw new ApiError(400, "ব্যবহারকারী ইতিমধ্যেই এই স্তরে আছেন");

      const domainUser = toDomainUser(target as never);

      // Requirement validation applies to every target level that defines
      // rules in level-rules.json (Phase C/D ladder). Machine rows must be
      // met; head-attested rows demand the outlineReviewed flag.
      const { rules, checklist, nextLevel } = await this.levels.evaluate(tx, domainUser);
      if (nextLevel === toLevel) {
        const missing = checklist.rows.filter((r) => r.autoChecked && !r.met);
        if (missing.length) {
          throw new ApiError(422, `চাহিদা পূরণ হয়নি: ${missing.map((r) => r.labelBn).join("; ")}`);
        }
        if (rules.outlineReviewRequired && dto.outlineReviewed !== true) {
          throw new ApiError(
            422,
            "উসরা প্রধানের আউটলাইন পর্যালোচনা সম্পন্ন হয়নি — নিশ্চিত করতে outlineReviewed পাঠান (প্রতিটি লক্ষ্য আইটেম ধরে ধরে যাচাই করা হয়েছে কি না)"
          );
        }
      }

      const outcome = await this.levels.promoteInTx(tx, domainUser, {
        toLevel,
        method: "admin",
        reason,
        actorId: user.id,
        evidence: {
          promotedBy: user.id,
          reason,
          ...(rules.outlineReviewRequired && dto.outlineReviewed === true
            ? { outlineReviewed: true }
            : {}),
        },
      });
      if (outcome.skipped) {
        throw new ApiError(409, "এই স্তর থেকে ইতিমধ্যেই একটি উন্নয়ন রেকর্ড হয়েছে");
      }

      await this.guard.audit(user.id, "promote_level", "user", target.id, {
        userId: target.id,
        fromLevel: outcome.fromLevel,
        toLevel,
        method: "admin",
        reason,
      });

      const message = this.levels.promotionMessage(toLevel);
      await tx.reminder.create({
        data: {
          userId: target.id,
          kind: "review",
          title: message.title,
          body: message.body,
          link: "dawah",
        },
      });

      return { user: outcome.user, message, targetId: target.id };
    });

    // push fan-out AFTER the RLS transaction commits (never fails the promote)
    try {
      await this.push.send(
        [result.targetId],
        {
          title: result.message.title,
          body: result.message.body,
          deepLink: DEEP_LINKS.dawah,
        },
        { actor: user }
      );
    } catch {
      // push transport hiccup — the transition + reminder already landed
    }

    return { user: result.user };
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

    // resolved inside the RLS transaction, kept for the post-commit push
    let targetUserIds: string[] = [];

    await this.rls.run(user, async (tx) => {
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
    });

    // Push fan-out (B2) — AFTER the RLS transaction commits, under the acting
    // user's context: a male head's token resolution physically cannot see a
    // female member's DeviceToken rows (RLS on DeviceToken), and the no-op
    // transport keeps dev/sandbox observable without Firebase. Reminders are
    // the always-on fallback — push never fails the broadcast.
    let push: { sent: number; users: number } | undefined;
    try {
      const outcome = await this.push.send(
        targetUserIds,
        {
          title: "নতুন ঘোষণা",
          body: text.slice(0, 200),
          deepLink: usrahId ? DEEP_LINKS.usrah : DEEP_LINKS.more,
        },
        { actor: user }
      );
      push = { sent: outcome.sent, users: outcome.users };
    } catch {
      // push transport hiccup — the announcement + reminders already landed
    }

    return { ok: true, ...(push ? { push } : {}) };
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

      // all three branches assign before use
      let targetJson: unknown;
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

  /** GET /api/admin/amal-catalog — full_admin: ALL definitions incl. inactive. */
  async listCatalog(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const rows = (await this.rls.run(user, (tx) =>
      tx.amalDefinition.findMany({ orderBy: [{ sortOrder: "asc" }, { key: "asc" }] })
    )) as unknown as (AmalDefRow & { active: boolean })[];
    return {
      definitions: rows.map((r) => ({ ...mapDefinition(r), active: r.active })),
    };
  }

  /** PATCH /api/admin/amal-catalog/:key — full_admin: partial update (audited). */
  async patchCatalog(viewer: User | null, key: string, dto: AmalCatalogPatchDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const cleanKey = (key ?? "").trim();
    if (!cleanKey) throw new ApiError(400, "আমলের কী (key) দিন");

    const updated = await this.rls.run(user, async (tx) => {
      const existing = await tx.amalDefinition.findUnique({ where: { key: cleanKey } });
      if (!existing) throw new ApiError(404, "আমলটি পাওয়া যায়নি");

      const data: Record<string, unknown> = {};
      if (dto.titleBn !== undefined) {
        const t = dto.titleBn.trim();
        if (!t) throw new ApiError(400, "বাংলা শিরোনাম দিন");
        data.titleBn = t;
      }
      if (dto.titleEn !== undefined) data.titleEn = dto.titleEn.trim();
      if (dto.category !== undefined) {
        if (!AMAL_CATEGORIES.includes(dto.category)) throw new ApiError(400, "ক্যাটাগরি ঠিক নয়");
        data.category = dto.category;
      }
      if (dto.inputType !== undefined) {
        if (!INPUT_TYPES.includes(dto.inputType)) throw new ApiError(400, "ইনপুট ধরন ঠিক নয়");
        data.inputType = dto.inputType;
      }
      if (dto.cadence !== undefined) {
        if (!CADENCES.includes(dto.cadence)) throw new ApiError(400, "পর্যায়ক্রম ঠিক নয়");
        data.cadence = dto.cadence;
      }
      if (dto.target !== undefined) data.targetJson = dto.target as never;
      if (dto.unit !== undefined) data.unit = dto.unit != null ? String(dto.unit) : null;
      if (dto.minLevel !== undefined) {
        if (!LEVELS.includes(dto.minLevel)) throw new ApiError(400, "স্তর ঠিক নয়");
        data.minLevel = dto.minLevel;
      }
      if (dto.sortOrder !== undefined) {
        if (!Number.isFinite(dto.sortOrder) || dto.sortOrder < 0) throw new ApiError(400, "ক্রম ঠিক নয়");
        data.sortOrder = dto.sortOrder;
      }
      if (dto.autoSource !== undefined) data.autoSource = dto.autoSource != null ? String(dto.autoSource) : null;
      if (dto.active !== undefined) data.active = dto.active;

      if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

      const row = await tx.amalDefinition.update({ where: { key: cleanKey }, data: data as never });
      await this.guard.audit(user.id, "update_amal_definition", "amal_definition", row.id, {
        key: cleanKey,
        changes: data,
      });
      return row;
    });

    invalidateDefinitionCache();
    return { definition: mapDefinition(updated as unknown as AmalDefRow) };
  }

  /**
   * PATCH /api/admin/amal-catalog — full_admin: reorder. `keys` lists the
   * definitions in the desired order; each gets sortOrder = its index.
   * Keys not in the list keep their relative order after the listed ones.
   */
  async reorderCatalog(viewer: User | null, dto: AmalCatalogReorderDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const keys = [...new Set((dto.keys ?? []).map((k) => String(k).trim()).filter(Boolean))];
    if (!keys.length) throw new ApiError(400, "আমলের কী তালিকা দিন");

    await this.rls.run(user, async (tx) => {
      const rows = await tx.amalDefinition.findMany({ select: { key: true } });
      const known = new Set(rows.map((r) => r.key));
      const unknown = keys.filter((k) => !known.has(k));
      if (unknown.length) throw new ApiError(404, `আমল পাওয়া যায়নি: ${unknown.join(", ")}`);

      await Promise.all(
        keys.map((key, i) =>
          tx.amalDefinition.update({ where: { key }, data: { sortOrder: i } })
        )
      );
      await this.guard.audit(user.id, "reorder_amal_catalog", "amal_definition", null, {
        keys,
      });
    });

    invalidateDefinitionCache();
    const rows = (await this.rls.run(user, (tx) =>
      tx.amalDefinition.findMany({ orderBy: [{ sortOrder: "asc" }, { key: "asc" }] })
    )) as unknown as (AmalDefRow & { active: boolean })[];
    return { definitions: rows.map((r) => ({ ...mapDefinition(r), active: r.active })) };
  }

  // ── Versioned assessment templates (B6) ──────────────────────────────

  /** GET /api/admin/assessment-templates — full_admin: ALL versions. */
  async listTemplates(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const rows = (await this.rls.run(user, (tx) =>
      tx.assessmentTemplate.findMany({ orderBy: [{ key: "asc" }, { version: "desc" }] })
    )) as unknown as {
      id: string; key: string; version: number; titleBn: string; titleEn: string;
      sectionsJson: unknown; active: boolean; createdAt: Date;
    }[];
    return {
      templates: rows.map((r) => ({
        id: r.id,
        key: r.key,
        version: r.version,
        titleBn: r.titleBn,
        titleEn: r.titleEn,
        active: r.active,
        sections: sanitizeSections(r.sectionsJson),
        createdAt: r.createdAt.toISOString(),
      })),
    };
  }

  /**
   * POST /api/admin/assessment-templates — full_admin: create a new version.
   * A brand-new key is born ACTIVE; an extra version of an existing key starts
   * INACTIVE (activate it with PATCH after review — activation is exclusive).
   */
  async createTemplate(viewer: User | null, dto: TemplateCreateDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const key = (dto.key ?? "").trim();
    if (!key) throw new ApiError(400, "টেমপ্লেটের কী (key) দিন");
    const titleBn = (dto.titleBn ?? "").trim();
    if (!titleBn) throw new ApiError(400, "বাংলা শিরোনাম দিন");
    const sections = sanitizeSections(dto.sections);
    if (!sections.length) throw new ApiError(400, "অন্তত একটি বিভাগ (section) দিন");

    const created = await this.rls.run(user, async (tx) => {
      const family = await tx.assessmentTemplate.findMany({ where: { key } });
      const version =
        dto.version ?? (family.length ? Math.max(...family.map((t) => t.version)) + 1 : 1);
      if (family.some((t) => t.version === version)) {
        throw new ApiError(409, `এই সংস্করণটি আগেই আছে (${key} v${version})`);
      }
      const active = family.length === 0;

      const row = await tx.assessmentTemplate.create({
        data: {
          key,
          version,
          titleBn,
          titleEn: (dto.titleEn ?? "").trim() || key,
          sectionsJson: sections as never,
          active,
        },
      });
      await this.guard.audit(user.id, "create_assessment_template", "assessment_template", row.id, {
        key,
        version,
        active,
      });
      return row;
    });

    return {
      template: {
        id: created.id,
        key: created.key,
        version: created.version,
        titleBn: created.titleBn,
        titleEn: created.titleEn,
        active: created.active,
        sections,
        createdAt: created.createdAt.toISOString(),
      },
    };
  }

  /**
   * PATCH /api/admin/assessment-templates/:id — full_admin: activate/
   * deactivate (exclusive per key) or edit title/sections of an INACTIVE
   * version (active versions are immutable — create a new version instead).
   */
  async patchTemplate(viewer: User | null, id: string, dto: TemplatePatchDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const row = await tx.assessmentTemplate.findUnique({ where: { id } });
      if (!row) throw new ApiError(404, "টেমপ্লেট পাওয়া যায়নি");

      const data: Record<string, unknown> = {};
      if (dto.titleBn !== undefined) {
        const t = dto.titleBn.trim();
        if (!t) throw new ApiError(400, "বাংলা শিরোনাম দিন");
        data.titleBn = t;
      }
      if (dto.titleEn !== undefined) data.titleEn = dto.titleEn.trim() || row.key;
      if (dto.sections !== undefined) {
        const sections = sanitizeSections(dto.sections);
        if (!sections.length) throw new ApiError(400, "অন্তত একটি বিভাগ (section) দিন");
        data.sectionsJson = sections as never;
      }

      if (dto.active !== undefined && dto.active !== row.active) {
        if (dto.active) {
          // exclusive activation — deactivate the siblings of the same key
          await tx.assessmentTemplate.updateMany({
            where: { key: row.key, id: { not: row.id } },
            data: { active: false },
          });
        } else {
          const siblings = await tx.assessmentTemplate.count({
            where: { key: row.key, active: true, id: { not: row.id } },
          });
          if (!siblings) throw new ApiError(400, "সক্রিয় সংস্করণ বাদ দেওয়া যাবে না — আগে অন্যটি সক্রিয় করুন");
        }
        data.active = dto.active;
      }

      if (Object.keys(data).some((k) => k !== "active") && row.active) {
        throw new ApiError(400, "সক্রিয় সংস্করণ সম্পাদনা করা যাবে না — নতুন সংস্করণ তৈরি করুন");
      }
      if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

      const updated = await tx.assessmentTemplate.update({ where: { id }, data: data as never });
      await this.guard.audit(user.id, "update_assessment_template", "assessment_template", row.id, {
        key: row.key,
        version: row.version,
        changes: data,
      });
      return {
        template: {
          id: updated.id,
          key: updated.key,
          version: updated.version,
          titleBn: updated.titleBn,
          titleEn: updated.titleEn,
          active: updated.active,
          sections: sanitizeSections(updated.sectionsJson),
          createdAt: updated.createdAt.toISOString(),
        },
      };
    });
  }

  // ── Usrah management (B6) ─────────────────────────────────────────────

  /** POST /api/admin/usrah — full_admin: create (name + gender). */
  async createUsrah(viewer: User | null, dto: UsrahCreateDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const name = (dto.name ?? "").trim();
    if (!name) throw new ApiError(400, "উসরার নাম দিন");
    if (!GENDERS.includes(dto.gender)) throw new ApiError(400, "লিঙ্গ ঠিক নয়");

    return this.rls.run(user, async (tx) => {
      const usrah = await tx.usrah.create({
        data: {
          name,
          gender: dto.gender,
          district: (dto.district ?? "").trim() || null,
        },
      });
      await this.guard.audit(user.id, "create_usrah", "usrah", usrah.id, {
        name,
        gender: dto.gender,
      });
      return { usrah: { ...usrah, memberCount: 0 } };
    });
  }

  /**
   * PATCH /api/admin/usrah/:id — full_admin: rename and/or assign head +
   * invigilator. Assignees must match the usrah's gender; a head cannot head
   * a second usrah (unique headUserId).
   */
  async patchUsrah(viewer: User | null, id: string, dto: UsrahPatchDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const usrah = await tx.usrah.findUnique({ where: { id } });
      if (!usrah) throw new ApiError(404, "উসরা পাওয়া যায়নি");

      const data: Record<string, unknown> = {};
      if (dto.name !== undefined) {
        const n = dto.name.trim();
        if (!n) throw new ApiError(400, "উসরার নাম দিন");
        data.name = n;
      }
      if (dto.district !== undefined) data.district = dto.district?.trim() || null;

      if (dto.headUserId !== undefined) {
        if (dto.headUserId === null) {
          data.headUserId = null;
        } else {
          const head = await tx.user.findUnique({ where: { id: dto.headUserId } });
          if (!head) throw new ApiError(404, "উসরা প্রধান পাওয়া যায়নি");
          if (head.gender !== usrah.gender) {
            throw new ApiError(400, "উসরা প্রধানের লিঙ্গ উসরার লিঙ্গের সাথে মিলতে হবে");
          }
          const other = await tx.usrah.findFirst({
            where: { headUserId: dto.headUserId, id: { not: usrah.id } },
          });
          if (other) throw new ApiError(400, "এই সদস্য ইতিমধ্যেই অন্য উসরার প্রধান");
          data.headUserId = dto.headUserId;
        }
      }

      if (dto.invigilatorUserId !== undefined) {
        if (dto.invigilatorUserId === null) {
          data.invigilatorUserId = null;
        } else {
          const inv = await tx.user.findUnique({ where: { id: dto.invigilatorUserId } });
          if (!inv) throw new ApiError(404, "পরিদর্শক পাওয়া যায়নি");
          if (inv.gender !== usrah.gender) {
            throw new ApiError(400, "পরিদর্শকের লিঙ্গ উসরার লিঙ্গের সাথে মিলতে হবে");
          }
          data.invigilatorUserId = dto.invigilatorUserId;
        }
      }

      if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

      const updated = await tx.usrah.update({ where: { id }, data: data as never });
      await this.guard.audit(user.id, "update_usrah", "usrah", id, { changes: data });
      return { usrah: updated };
    });
  }

  /**
   * POST /api/admin/usrah/:id/members {userId} — full_admin: add or MOVE a
   * member into the usrah (gender must match; RLS re-checks visibility of the
   * user row). Every move is audited.
   */
  async addUsrahMember(viewer: User | null, id: string, dto: UsrahMemberDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!dto.userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    return this.rls.run(user, async (tx) => {
      const usrah = await tx.usrah.findUnique({ where: { id } });
      if (!usrah) throw new ApiError(404, "উসরা পাওয়া যায়নি");

      const member = await tx.user.findUnique({ where: { id: dto.userId } });
      if (!member) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      if (member.gender !== usrah.gender) {
        throw new ApiError(400, "সদস্যের লিঙ্গ উসরার লিঙ্গের সাথে মিলতে হবে");
      }
      if (member.usrahId === usrah.id) {
        throw new ApiError(400, "সদস্য ইতিমধ্যেই এই উসরায় আছেন");
      }

      await tx.user.update({ where: { id: member.id }, data: { usrahId: usrah.id } });
      await this.guard.audit(user.id, "move_usrah_member", "usrah", usrah.id, {
        userId: member.id,
        fromUsrahId: member.usrahId ?? null,
        toUsrahId: usrah.id,
      });
      return { ok: true, usrahId: usrah.id };
    });
  }

  /** DELETE /api/admin/usrah/:id/members/:userId — full_admin: remove member. */
  async removeUsrahMember(viewer: User | null, id: string, userId: string) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    return this.rls.run(user, async (tx) => {
      const usrah = await tx.usrah.findUnique({ where: { id } });
      if (!usrah) throw new ApiError(404, "উসরা পাওয়া যায়নি");

      const member = await tx.user.findUnique({ where: { id: userId } });
      if (!member) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      if (member.usrahId !== usrah.id) {
        throw new ApiError(400, "সদস্য এই উসরায় নেই");
      }

      await tx.user.update({ where: { id: member.id }, data: { usrahId: null } });
      await this.guard.audit(user.id, "move_usrah_member", "usrah", usrah.id, {
        userId: member.id,
        fromUsrahId: usrah.id,
        toUsrahId: null,
      });
      return { ok: true };
    });
  }

  // ── Level transitions history (B6) ────────────────────────────────────

  /**
   * GET /api/admin/level-transitions — usrah_head+: promotion history,
   * scoped by RLS (member sees own, head+ sees their usrah, full_admin sees
   * all) with user names + Bengali level labels.
   */
  async levelTransitions(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) throw new ApiError(403, "অ্যাডমিন প্যানেল দেখার অনুমতি নেই");

    return this.rls.run(user, async (tx) => {
      const rows = await tx.levelTransition.findMany({
        orderBy: { at: "desc" },
        take: 100,
      });
      const userIds = [...new Set(rows.map((r) => r.userId))];
      const users = userIds.length
        ? await tx.user.findMany({ where: { id: { in: userIds } }, select: { id: true, name: true, memberCode: true, gender: true } })
        : [];
      const byId = new Map(users.map((u) => [u.id, u]));

      return {
        transitions: rows
          .filter((r) => byId.has(r.userId))
          .map((r) => {
            const u = byId.get(r.userId)!;
            return {
              id: r.id,
              userId: r.userId,
              userName: u.name,
              memberCode: u.memberCode,
              gender: u.gender as Gender,
              fromLevel: r.fromLevel as Level,
              toLevel: r.toLevel as Level,
              method: r.method as "auto" | "admin",
              reason: r.reason,
              actorId: r.actorId,
              at: r.at.toISOString(),
            };
          }),
      };
    });
  }

  // ── Live program CRUD (B6) ─────────────────────────────────────────────

  /** POST /api/admin/live — full_admin: schedule a program (audited). */
  async createLive(viewer: User | null, dto: LiveProgramDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const startsAt = new Date(dto.startsAt);
      if (isNaN(startsAt.getTime())) throw new ApiError(400, "শুরুর সময় ঠিকভাবে দিন");
      const endsAt = dto.endsAt ? new Date(dto.endsAt) : null;
      if (endsAt && isNaN(endsAt.getTime())) throw new ApiError(400, "শেষের সময় ঠিকভাবে দিন");

      const row = await tx.liveProgram.create({
        data: {
          titleBn: dto.titleBn.trim(),
          descBn: dto.descBn?.trim() || null,
          hostName: dto.hostName?.trim() || null,
          startsAt,
          endsAt,
          youtubeId: extractYoutubeId(dto.youtubeId ?? null),
          gender: dto.gender ?? "M",
          status: startsAt.getTime() > Date.now() ? "upcoming" : "live",
          recordingUrl: dto.recordingUrl?.trim() || null,
        },
      });
      await this.guard.audit(user.id, "create_live_program", "live_program", row.id, {
        titleBn: row.titleBn,
        gender: row.gender,
        startsAt: row.startsAt.toISOString(),
      });
      return { program: mapLiveProgram(row) };
    });
  }

  /** PATCH /api/admin/live/:id — full_admin: update (audited, old→new). */
  async patchLive(viewer: User | null, id: string, dto: LiveProgramDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const row = await tx.liveProgram.findUnique({ where: { id } });
      if (!row) throw new ApiError(404, "প্রোগ্রাম পাওয়া যায়নি");

      const data: Record<string, unknown> = {};
      if (dto.titleBn !== undefined) {
        const t = dto.titleBn.trim();
        if (!t) throw new ApiError(400, "শিরোনাম দিন");
        data.titleBn = t;
      }
      if (dto.descBn !== undefined) data.descBn = dto.descBn?.trim() || null;
      if (dto.hostName !== undefined) data.hostName = dto.hostName?.trim() || null;
      if (dto.startsAt !== undefined) {
        const d = new Date(dto.startsAt);
        if (isNaN(d.getTime())) throw new ApiError(400, "শুরুর সময় ঠিকভাবে দিন");
        data.startsAt = d;
      }
      if (dto.endsAt !== undefined) {
        const d = dto.endsAt ? new Date(dto.endsAt) : null;
        if (d && isNaN(d.getTime())) throw new ApiError(400, "শেষের সময় ঠিকভাবে দিন");
        data.endsAt = d;
      }
      if (dto.youtubeId !== undefined) data.youtubeId = extractYoutubeId(dto.youtubeId);
      if (dto.gender !== undefined) {
        if (!GENDERS.includes(dto.gender)) throw new ApiError(400, "লিঙ্গ ঠিক নয়");
        data.gender = dto.gender;
      }
      if (dto.recordingUrl !== undefined) data.recordingUrl = dto.recordingUrl?.trim() || null;

      if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

      const updated = await tx.liveProgram.update({ where: { id }, data: data as never });
      await this.guard.audit(user.id, "update_live_program", "live_program", id, {
        changes: data,
      });
      return { program: mapLiveProgram(updated) };
    });
  }

  /** DELETE /api/admin/live/:id — full_admin: remove (audited). */
  async deleteLive(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    await this.rls.run(user, async (tx) => {
      const row = await tx.liveProgram.findUnique({ where: { id } });
      if (!row) throw new ApiError(404, "প্রোগ্রাম পাওয়া যায়নি");
      await tx.liveProgram.delete({ where: { id } });
      await this.guard.audit(user.id, "delete_live_program", "live_program", id, {
        titleBn: row.titleBn,
      });
    });
    return { ok: true };
  }

  /**
   * GET /api/admin/config — full_admin: the live app configuration
   * (GET /api/config's source after merging with defaults).
   */
  async appConfig(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const row = await this.prisma.appConfigRow.findUnique({ where: { key: "app" } });
    return mergeConfig(row?.valueJson);
  }

  /**
   * PATCH /api/admin/config — full_admin CMS write. Merges over the stored
   * value (partial update), runs the same validation as the public read
   * path (mergeConfig), invalidates the public cache and audits the diff.
   */
  async updateAppConfig(viewer: User | null, dto: AppConfigAdminDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    const row = await this.prisma.appConfigRow.findUnique({ where: { key: "app" } });
    const before = mergeConfig(row?.valueJson);
    const after = mergeConfig({ ...before, ...(dto as unknown as Record<string, unknown>) });

    await this.prisma.appConfigRow.upsert({
      where: { key: "app" },
      create: { key: "app", valueJson: after as never },
      update: { valueJson: after as never },
    });
    invalidateAppConfigCache();

    // audit the changed top-level keys only (contacts/groups diffs are long).
    // Canonical stringify (sorted keys) so key ORDER differences don't read
    // as value changes (the optional contact fields have no fixed order).
    const canon = (v: unknown): string =>
      JSON.stringify(v, (_k, val) =>
        val && typeof val === "object" && !Array.isArray(val)
          ? Object.keys(val as Record<string, unknown>).sort().reduce<Record<string, unknown>>((acc, kk) => {
              (acc as Record<string, unknown>)[kk] = (val as Record<string, unknown>)[kk];
              return acc;
            }, {})
          : val
      );
    const changed = Object.keys(after).filter(
      (k) =>
        canon((before as unknown as Record<string, unknown>)[k]) !==
        canon((after as unknown as Record<string, unknown>)[k])
    );
    await this.guard.audit(user.id, "update_app_config", "app_config", "app", { changed });

    return after;
  }

  // ── W4h: level-rules editor (DB override over the pack) ─────────────────

  /**
   * GET /api/admin/level-rules — full_admin: the effective level-rules
   * document. Per level: the raw merged node, where it comes from
   * (db override | pack | default) and the parsed rules the engine sees.
   */
  async levelRules(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    const { nodes, sources, packNote } = await loadLevelRulesDoc(this.prisma);
    const levels: Record<string, { node: Record<string, unknown>; source: string }> = {};
    for (const key of ["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"] as LevelKey[]) {
      const node = nodes[key];
      if (node) {
        levels[key] = { node, source: sources[key] ?? "default" };
      }
    }
    return { levels, packNote };
  }

  /**
   * PUT /api/admin/level-rules/:level — full_admin. MERGE semantics: the
   * validated fields layer over the level's current effective node (pack or
   * previous override); unmentioned fields keep their values. Persists to
   * AppConfigRow (key "level_rules"), busts the engine cache and audits the
   * changed keys (action level_rules_update).
   */
  async updateLevelRules(viewer: User | null, level: string, body: unknown) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const key = this.requireLevelKey(level);

    let patch: Record<string, unknown>;
    try {
      patch = validateLevelRulesNode(body);
    } catch (err) {
      if (err instanceof LevelRulesValidationError) throw new ApiError(400, err.message);
      throw err;
    }

    const { nodes } = await loadLevelRulesDoc(this.prisma);
    const before = nodes[key] ?? {};
    const after = { ...before, ...patch };

    const row = await this.prisma.appConfigRow.findUnique({ where: { key: "level_rules" } });
    const doc = (row?.valueJson ?? {}) as { levels?: Record<string, unknown> };
    const levelsDoc = { ...(doc.levels ?? {}), [key]: after };
    await this.prisma.appConfigRow.upsert({
      where: { key: "level_rules" },
      create: { key: "level_rules", valueJson: { levels: levelsDoc } as never },
      update: { valueJson: { levels: levelsDoc } as never },
    });
    invalidateLevelRulesCache();

    const changed = Object.keys(after).filter(
      (k) => JSON.stringify(before[k] ?? null) !== JSON.stringify(after[k] ?? null)
    );
    await this.guard.audit(user.id, "level_rules_update", "level_rules", key, {
      level: key,
      changed,
    });

    return { level: key, node: after, changed };
  }

  /**
   * DELETE /api/admin/level-rules/:level — full_admin. Drops the DB override
   * for one level so the engine falls back to the pack file (the seed
   * default). Audited (action level_rules_update, meta.reset = true).
   */
  async resetLevelRules(viewer: User | null, level: string) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const key = this.requireLevelKey(level);

    const row = await this.prisma.appConfigRow.findUnique({ where: { key: "level_rules" } });
    const doc = (row?.valueJson ?? {}) as { levels?: Record<string, unknown> };
    if (!doc.levels || !(key in doc.levels)) {
      // nothing overridden — idempotent no-op
      return { level: key, reset: false };
    }
    const levelsDoc = { ...doc.levels };
    delete levelsDoc[key];
    await this.prisma.appConfigRow.upsert({
      where: { key: "level_rules" },
      create: { key: "level_rules", valueJson: { levels: levelsDoc } as never },
      update: { valueJson: { levels: levelsDoc } as never },
    });
    invalidateLevelRulesCache();
    await this.guard.audit(user.id, "level_rules_update", "level_rules", key, {
      level: key,
      reset: true,
    });
    return { level: key, reset: true };
  }

  private requireLevelKey(level: string): LevelKey {
    if (!["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"].includes(level)) {
      throw new ApiError(404, "স্তর পাওয়া যায়নি");
    }
    return level as LevelKey;
  }

  // ── W4h: invigilator health score ───────────────────────────────────────

  /**
   * GET /api/admin/invigilator-health — one invigilator, or all of them.
   *
   * SCOPE: full_admin sees every invigilator; an invigilator sees ONLY their
   * own score (self view); usrah_head gets 403. Every invigilator's members =
   * the members of all usrahs of the invigilator's gender (the supervision
   * scope the overview + reviews queue already use for the role).
   *
   * FORMULA (all components 0..100, bounded windows — nothing unbounded):
   *   score = round(0.35·reviewPct + 0.35·amalPct + 0.20·activePct + 0.10·onTimePct)
   *     reviewPct — done weekly reviews ÷ expected (members × 4 weeks) over
   *                 the last 27 days (the 4 Saturday-started weeks the
   *                 overview already uses)
   *     amalPct   — mean of the members' 7-day amal completion (the shared
   *                 completion7dForUsers rule over active daily definitions)
   *     activePct — members active in the last 3 days ÷ members (the
   *                 overview's INACTIVE_DAYS definition of inactive)
   *     onTimePct — 100·(1 − overdue reviews ÷ members) — each overdue
   *                 (stale pending) review drags the red-flag component
   *                 proportionally, floored at 0
   * Reviews and amal completion are the core supervision work (0.35 each);
   * inactive members a moderate signal (0.20); overdue flags a red-flag
   * signal (0.10). An empty scope (no usrahs of that gender) scores null.
   */
  async invigilatorHealth(viewer: User | null) {
    const user = this.guard.requireUser(viewer);
    if (user.role === "usrah_head") {
      throw new ApiError(403, "এই রিপোর্ট শুধুমাত্র পরিদর্শক ও প্রধান অ্যাডমিনের জন্য");
    }
    if (user.role !== "full_admin" && user.role !== "invigilator") {
      throw new ApiError(403, "এই রিপোর্ট শুধুমাত্র পরিদর্শক ও প্রধান অ্যাডমিনের জন্য");
    }

    return this.rls.run(user, async (tx) => {
      const invigilators =
        user.role === "full_admin"
          ? await tx.user.findMany({
              where: { role: "invigilator" },
              orderBy: { name: "asc" },
            })
          : [await tx.user.findUnique({ where: { id: user.id } })].filter(
              (x): x is NonNullable<typeof x> => !!x
            );
      if (!invigilators.length) return { invigilators: [] };

      const now = Date.now();
      const reviewCutoff = addDays(bdToday(), -REVIEW_WINDOW_DAYS);
      const assessmentCutoff = new Date(now - 30 * 86_400_000);
      const inactiveBefore = new Date(now - INACTIVE_DAYS * 86_400_000);

      const items: InvigilatorHealthItem[] = [];
      for (const inv of invigilators) {
        const usrahRows = await tx.usrah.findMany({
          where: { gender: inv.gender },
          select: { id: true, name: true, members: { select: { id: true, category: true, lastActiveAt: true } } },
        });
        const memberIds = usrahRows.flatMap((u) => u.members.map((m) => m.id));
        const memberCount = memberIds.length;

        if (!memberCount) {
          items.push({
            id: inv.id,
            name: inv.name,
            memberCode: inv.memberCode,
            gender: inv.gender as Gender,
            usrahNames: usrahRows.map((u) => u.name),
            memberCount: 0,
            reviewPct: null,
            amalPct: null,
            activePct: null,
            overdueCount: 0,
            assessments30d: 0,
            unsignedAssessments: 0,
            score: null,
          });
          continue;
        }

        const [doneReviews, overdue, assessments30d] = await Promise.all([
          tx.weeklyReview.count({
            where: { userId: { in: memberIds }, status: "done", weekStart: { gte: reviewCutoff } },
          }),
          tx.weeklyReview.count({
            where: { userId: { in: memberIds }, status: "overdue" },
          }),
          tx.assessment.count({
            where: { assesseeId: { in: memberIds }, createdAt: { gte: assessmentCutoff } },
          }),
        ]);
        const unsignedAssessments = await tx.assessment.count({
          where: {
            assesseeId: { in: memberIds },
            createdAt: { gte: assessmentCutoff },
            OR: [{ assessorSignedAt: null }, { assesseeSignedAt: null }],
          },
        });

        const completions = await completion7dForUsers(
          tx,
          usrahRows.flatMap((u) => u.members)
        );
        const amalPct = Math.round(
          memberIds.reduce((s, id) => s + (completions.get(id) ?? 0), 0) / memberCount
        );

        const expected = memberCount * 4;
        const reviewPct = Math.min(100, Math.round((100 * doneReviews) / expected));
        const activePct = Math.round(
          (100 *
            usrahRows
              .flatMap((u) => u.members)
              .filter((m) => m.lastActiveAt >= inactiveBefore).length) /
            memberCount
        );
        const onTimePct = Math.max(0, Math.round(100 * (1 - overdue / memberCount)));

        const score = Math.round(0.35 * reviewPct + 0.35 * amalPct + 0.2 * activePct + 0.1 * onTimePct);

        items.push({
          id: inv.id,
          name: inv.name,
          memberCode: inv.memberCode,
          gender: inv.gender as Gender,
          usrahNames: usrahRows.map((u) => u.name),
          memberCount,
          reviewPct,
          amalPct,
          activePct,
          overdueCount: overdue,
          assessments30d,
          unsignedAssessments,
          score,
        });
      }
      return { invigilators: items };
    });
  }

  // ── W4h: referral tree, server-side cursor-paginated ─────────────────────

  /**
   * GET /api/admin/referral-tree?userId=&cursor=&limit= — full_admin.
   *
   * One PAGE of one parent's children (or of the roots when userId is
   * omitted), keyset-paginated by id (orderBy id asc, cursor = the last
   * node's id), so a 1000-node usrah never has to arrive in one response.
   * Every node carries childCount — the expander badge — from ONE groupBy
   * over the page's ids. Supervisors keep their depth-bounded own-downline
   * view (GET /api/dawah); the whole-forest browser is a full_admin tool.
   */
  async referralTree(
    viewer: User | null,
    opts: { userId?: string; cursor?: string; limit?: string }
  ) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    const limitRaw = parseInt(opts.limit ?? "50", 10);
    if (!Number.isInteger(limitRaw) || limitRaw < 1 || limitRaw > 100) {
      throw new ApiError(400, "প্রতি পাতায় ১ থেকে ১০০টি নোড দেখা যাবে");
    }

    // existence pre-read in the system context → honest 404 (assertCanAccess
    // pattern); RLS is bypassed for full_admin anyway.
    let parentId: string | null = null;
    if (opts.userId) {
      const parent = await this.rls.system((tx) =>
        tx.user.findUnique({ where: { id: opts.userId }, select: { id: true } })
      );
      if (!parent) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
      parentId = opts.userId;
    }

    return this.rls.run(user, async (tx) => {
      const where: Record<string, unknown> = {
        ...(parentId ? { referredById: parentId } : { referredById: null }),
        ...(opts.cursor ? { id: { gt: opts.cursor } } : {}),
      };
      // the count uses the SAME where (cursor applied) so "remaining" is
      // exact — an exact-fit last page yields nextCursor null
      const [rows, remaining] = await Promise.all([
        tx.user.findMany({
          where: where as never,
          orderBy: { id: "asc" },
          take: limitRaw,
        }),
        tx.user.count({ where: where as never }),
      ]);

      const ids = rows.map((r) => r.id);
      const childCounts = new Map<string, number>();
      if (ids.length) {
        const grouped = await tx.user.groupBy({
          by: ["referredById"],
          where: { referredById: { in: ids } },
          _count: { _all: true },
        });
        for (const g of grouped) {
          if (g.referredById) childCounts.set(g.referredById, g._count._all);
        }
      }

      const nodes = rows.map((r) => ({
        id: r.id,
        name: r.name,
        gender: r.gender as Gender,
        level: r.level as Level,
        memberCode: r.memberCode,
        role: r.role as Role,
        lastActiveAt: r.lastActiveAt.toISOString(),
        joinedAt: r.createdAt.toISOString(),
        childCount: childCounts.get(r.id) ?? 0,
      }));
      const nextCursor =
        rows.length === limitRaw && remaining > limitRaw && rows.length > 0
          ? rows[rows.length - 1].id
          : null;
      // remaining = rows still to fetch AFTER this page (the count query has
      // the cursor applied, minus what this page just returned)
      return { nodes, nextCursor, remaining: Math.max(0, remaining - rows.length) };
    });
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

  // ── Live support threads (W4d) — full_admin support inbox ──────────────

  /**
   * GET /api/admin/support — full_admin: every support thread (optionally
   * ?status=open|answered|closed), OPEN ones first, then answered, then
   * closed; within a group by last activity (updatedAt) desc.
   */
  async supportThreads(viewer: User | null, status: string | undefined) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const filter = status && ["open", "answered", "closed"].includes(status) ? status : undefined;

    return this.rls.run(user, async (tx) => {
      const rows = (await tx.supportThread.findMany({
        ...(filter ? { where: { status: filter } } : {}),
        orderBy: { updatedAt: "desc" },
        take: 200,
      })) as unknown as (import("../support/support.controller").SupportThreadItem & {
        createdAt: Date;
        updatedAt: Date;
        closedAt: Date | null;
      })[];
      if (!rows.length) return { threads: [] };

      const userIds = [...new Set(rows.map((r) => r.userId))];
      const users = await tx.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, name: true, memberCode: true, gender: true },
      });
      const names = new Map(users.map((u) => [u.id, u]));

      const messages = (await tx.supportMessage.findMany({
        where: { threadId: { in: rows.map((r) => r.id) } },
        orderBy: { createdAt: "asc" },
      })) as unknown as (import("../support/support.controller").SupportMessageItem & {
        createdAt: Date;
      })[];
      const byThread = new Map<string, typeof messages>();
      for (const m of messages) {
        const list = byThread.get(m.threadId) ?? [];
        list.push(m);
        byThread.set(m.threadId, list);
      }

      const RANK: Record<string, number> = { open: 0, answered: 1, closed: 2 };
      const threads = rows
        .map((r) => {
          const msgs = byThread.get(r.id) ?? [];
          const last = msgs.length ? msgs[msgs.length - 1] : null;
          const member = names.get(r.userId);
          return {
            id: r.id,
            userId: r.userId,
            userName: member?.name ?? "সদস্য",
            userMemberCode: member?.memberCode ?? null,
            userGender: (member?.gender ?? "M") as Gender,
            subject: r.subject,
            status: r.status,
            messageCount: msgs.length,
            lastMessageAt: last ? last.createdAt.toISOString() : r.createdAt.toISOString(),
            lastPreview: last ? last.body.slice(0, 120) : null,
            lastFromAdmin: !!last?.isAdmin,
            createdAt: r.createdAt.toISOString(),
            closedAt: r.closedAt ? r.closedAt.toISOString() : null,
          };
        })
        .sort((a, b) =>
          filter
            ? 0 // already single-status; keep the updatedAt desc order
            : (RANK[a.status] ?? 3) - (RANK[b.status] ?? 3) ||
              new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime()
        );
      return { threads };
    });
  }

  /**
   * GET /api/admin/support/:id — full_admin: one thread + its full message
   * history (authorName resolved — the admin context may read every author).
   */
  async supportThreadDetail(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const thread = await tx.supportThread.findUnique({ where: { id } });
      if (!thread) throw new ApiError(404, "আলাপনাটি পাওয়া যায়নি");

      const messages = await tx.supportMessage.findMany({
        where: { threadId: id },
        orderBy: { createdAt: "asc" },
        take: 200,
        include: { author: { select: { name: true } } },
      });
      return {
        thread: {
          id: thread.id,
          userId: thread.userId,
          subject: thread.subject,
          status: thread.status,
          createdAt: thread.createdAt.toISOString(),
          updatedAt: thread.updatedAt.toISOString(),
          closedAt: thread.closedAt ? thread.closedAt.toISOString() : null,
        },
        messages: messages.map((m) => ({
          id: m.id,
          threadId: m.threadId,
          authorId: m.authorId,
          authorName: m.author?.name ?? null,
          isAdmin: m.isAdmin,
          body: m.body,
          createdAt: m.createdAt.toISOString(),
        })),
      };
    });
  }

  /**
   * POST /api/admin/support/:id/messages — full_admin: reply (isAdmin=true,
   * status → answered, audited as support_reply). Replying to a CLOSED thread
   * is refused — reopen deliberately (a new thread) instead.
   */
  async supportReply(viewer: User | null, id: string, dto: SupportReplyDto) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);
    const body = (dto.message ?? "").trim();
    if (body.length < 3) throw new ApiError(400, "বার্তা কমপক্ষে ৩ অক্ষরের হতে হবে");

    return this.rls.run(user, async (tx) => {
      const thread = await tx.supportThread.findUnique({ where: { id } });
      if (!thread) throw new ApiError(404, "আলাপনাটি পাওয়া যায়নি");
      if (thread.status === "closed") throw new ApiError(400, "এই আলাপনা বন্ধ করা হয়েছে");

      const message = await tx.supportMessage.create({
        data: { threadId: id, authorId: user.id, body, isAdmin: true },
      });
      await tx.supportThread.update({ where: { id }, data: { status: "answered" } });
      await this.guard.audit(user.id, "support_reply", "support_thread", id, { userId: thread.userId });
      return {
        message: {
          id: message.id,
          threadId: message.threadId,
          authorId: message.authorId,
          isAdmin: message.isAdmin,
          body: message.body,
          createdAt: message.createdAt.toISOString(),
        },
      };
    });
  }

  /** POST /api/admin/support/:id/close — full_admin (idempotent, audited). */
  async supportClose(viewer: User | null, id: string) {
    const user = this.guard.requireUser(viewer);
    await this.guard.assertFullAdmin(user);

    return this.rls.run(user, async (tx) => {
      const thread = await tx.supportThread.findUnique({ where: { id } });
      if (!thread) throw new ApiError(404, "আলাপনাটি পাওয়া যায়নি");
      if (thread.status === "closed") return { thread }; // idempotent re-close

      const updated = await tx.supportThread.update({
        where: { id },
        data: { status: "closed", closedAt: new Date(), closedById: user.id },
      });
      await this.guard.audit(user.id, "support_close", "support_thread", id, { userId: thread.userId });
      return {
        thread: {
          id: updated.id,
          userId: updated.userId,
          subject: updated.subject,
          status: updated.status,
          createdAt: updated.createdAt.toISOString(),
          updatedAt: updated.updatedAt.toISOString(),
          closedAt: updated.closedAt ? updated.closedAt.toISOString() : null,
        },
      };
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
async function nextMemberCode(tx: import("../common/prisma-client").Prisma.TransactionClient): Promise<string> {
  const rows = await tx.user.findMany({ where: { memberCode: { not: null } }, select: { memberCode: true } });
  let max = 0;
  for (const r of rows) {
    const m = /^DS-(\d+)$/.exec(r.memberCode ?? "");
    if (m) max = Math.max(max, Number(m[1]));
  }
  return `DS-${String(max + 1).padStart(6, "0")}`;
}

/** Sanitize a template body into typed sections (same rule as mapTemplate). */
function sanitizeSections(raw: unknown): AssessmentSection[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((s): s is Record<string, unknown> => !!s && typeof s === "object")
    .map((s) => ({
      key: String(s.key ?? "").trim(),
      titleBn: String(s.titleBn ?? "").trim(),
      criteria: Array.isArray(s.criteria)
        ? (s.criteria as unknown[])
            .filter((c): c is Record<string, unknown> => !!c && typeof c === "object")
            .map((c) => ({
              key: String(c.key ?? "").trim(),
              titleBn: String(c.titleBn ?? "").trim(),
              ...(c.hintBn != null && String(c.hintBn).trim() ? { hintBn: String(c.hintBn) } : {}),
            }))
            .filter((c) => c.key && c.titleBn)
        : [],
    }))
    .filter((s) => s.key && s.titleBn && s.criteria.length > 0);
}

/** Accept a bare YouTube id OR a watch/youtu.be/short URL — returns the id. */
function extractYoutubeId(input: string | null | undefined): string | null {
  const raw = (input ?? "").trim();
  if (!raw) return null;
  if (/^[A-Za-z0-9_-]{11}$/.test(raw)) return raw;
  const m =
    /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/.exec(raw);
  return m ? m[1] : null;
}

/** Map a LiveProgram row to the member-facing shape (same fields as /api/live). */
function mapLiveProgram(row: {
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
}) {
  return {
    id: row.id,
    titleBn: row.titleBn,
    descBn: row.descBn,
    hostName: row.hostName,
    startsAt: row.startsAt.toISOString(),
    endsAt: row.endsAt?.toISOString() ?? null,
    youtubeId: row.youtubeId,
    gender: row.gender as Gender,
    status: row.status as "upcoming" | "live" | "past",
    recordingUrl: row.recordingUrl,
  };
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
  @ApiOperation({ summary: "full_admin: change role/gender/usrah/category (audited; gender needs reason)" })
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

  @Get("level-transitions")
  @ApiOperation({ summary: "Level promotion history (RLS-scoped: own/usrah/all)" })
  levelTransitions(@Req() req: AuthedRequest) {
    return this.service.levelTransitions(currentUser(req));
  }

  @Post("promote")
  @ApiOperation({ summary: "full_admin: promote a level (reason required, validates requirements)" })
  @Roles("full_admin")
  promote(@Body() dto: PromoteDto, @Req() req: AuthedRequest) {
    return this.service.promote(currentUser(req), dto);
  }

  @Post("broadcast")
  @ApiOperation({ summary: "usrah_head+: announcement + reminder fan-out" })
  broadcast(@Body() dto: BroadcastDto, @Req() req: AuthedRequest) {
    return this.service.broadcast(currentUser(req), dto);
  }

  @Get("amal-catalog")
  @ApiOperation({ summary: "full_admin: whole amal catalog incl. inactive" })
  @Roles("full_admin")
  listCatalog(@Req() req: AuthedRequest) {
    return this.service.listCatalog(currentUser(req));
  }

  @Post("amal-catalog")
  @ApiOperation({ summary: "full_admin: upsert an amal definition by key" })
  @Roles("full_admin")
  upsertCatalog(@Body() dto: AmalCatalogDto, @Req() req: AuthedRequest) {
    return this.service.upsertCatalog(currentUser(req), dto);
  }

  @Patch("amal-catalog")
  @ApiOperation({ summary: "full_admin: reorder the catalog (array of keys)" })
  @Roles("full_admin")
  reorderCatalog(@Body() dto: AmalCatalogReorderDto, @Req() req: AuthedRequest) {
    return this.service.reorderCatalog(currentUser(req), dto);
  }

  @Patch("amal-catalog/:key")
  @ApiOperation({ summary: "full_admin: partial update of one definition" })
  @Roles("full_admin")
  patchCatalog(@Param("key") key: string, @Body() dto: AmalCatalogPatchDto, @Req() req: AuthedRequest) {
    return this.service.patchCatalog(currentUser(req), key, dto);
  }

  @Get("assessment-templates")
  @ApiOperation({ summary: "full_admin: all template versions (active flag included)" })
  @Roles("full_admin")
  listTemplates(@Req() req: AuthedRequest) {
    return this.service.listTemplates(currentUser(req));
  }

  @Post("assessment-templates")
  @ApiOperation({ summary: "full_admin: create a new template version" })
  @Roles("full_admin")
  createTemplate(@Body() dto: TemplateCreateDto, @Req() req: AuthedRequest) {
    return this.service.createTemplate(currentUser(req), dto);
  }

  @Patch("assessment-templates/:id")
  @ApiOperation({ summary: "full_admin: activate/deactivate or edit an inactive version" })
  @Roles("full_admin")
  patchTemplate(@Param("id") id: string, @Body() dto: TemplatePatchDto, @Req() req: AuthedRequest) {
    return this.service.patchTemplate(currentUser(req), id, dto);
  }

  @Post("usrah")
  @ApiOperation({ summary: "full_admin: create an usrah (name + gender)" })
  @Roles("full_admin")
  createUsrah(@Body() dto: UsrahCreateDto, @Req() req: AuthedRequest) {
    return this.service.createUsrah(currentUser(req), dto);
  }

  @Patch("usrah/:id")
  @ApiOperation({ summary: "full_admin: rename / assign head + invigilator (gender-validated)" })
  @Roles("full_admin")
  patchUsrah(@Param("id") id: string, @Body() dto: UsrahPatchDto, @Req() req: AuthedRequest) {
    return this.service.patchUsrah(currentUser(req), id, dto);
  }

  @Post("usrah/:id/members")
  @ApiOperation({ summary: "full_admin: add/move a member into the usrah (audited)" })
  @Roles("full_admin")
  addUsrahMember(@Param("id") id: string, @Body() dto: UsrahMemberDto, @Req() req: AuthedRequest) {
    return this.service.addUsrahMember(currentUser(req), id, dto);
  }

  @Delete("usrah/:id/members/:userId")
  @ApiOperation({ summary: "full_admin: remove a member from the usrah (audited)" })
  @Roles("full_admin")
  removeUsrahMember(
    @Param("id") id: string,
    @Param("userId") userId: string,
    @Req() req: AuthedRequest
  ) {
    return this.service.removeUsrahMember(currentUser(req), id, userId);
  }

  @Post("live")
  @ApiOperation({ summary: "full_admin: schedule a live program (gender visibility)" })
  @Roles("full_admin")
  createLive(@Body() dto: LiveProgramDto, @Req() req: AuthedRequest) {
    return this.service.createLive(currentUser(req), dto);
  }

  @Patch("live/:id")
  @ApiOperation({ summary: "full_admin: update a live program (audited)" })
  @Roles("full_admin")
  patchLive(@Param("id") id: string, @Body() dto: LiveProgramDto, @Req() req: AuthedRequest) {
    return this.service.patchLive(currentUser(req), id, dto);
  }

  @Delete("live/:id")
  @ApiOperation({ summary: "full_admin: delete a live program (audited)" })
  @Roles("full_admin")
  deleteLive(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.deleteLive(currentUser(req), id);
  }

  @Get("config")
  @ApiOperation({ summary: "full_admin: the live app configuration (CMS)" })
  @Roles("full_admin")
  appConfig(@Req() req: AuthedRequest) {
    return this.service.appConfig(currentUser(req));
  }

  @Patch("config")
  @ApiOperation({ summary: "full_admin: update the app configuration (audited)" })
  @Roles("full_admin")
  updateAppConfig(@Body() dto: AppConfigAdminDto, @Req() req: AuthedRequest) {
    return this.service.updateAppConfig(currentUser(req), dto);
  }

  @Get("audit")
  @ApiOperation({ summary: "full_admin: last 100 audit entries" })
  @Roles("full_admin")
  audit(@Req() req: AuthedRequest) {
    return this.service.audit(currentUser(req));
  }

  // ── W4h: level-rules editor (DB override over the pack seed) ────────────

  @Get("level-rules")
  @ApiOperation({ summary: "full_admin: effective level rules (db override | pack) per level" })
  @Roles("full_admin")
  levelRules(@Req() req: AuthedRequest) {
    return this.service.levelRules(currentUser(req));
  }

  @Put("level-rules/:level")
  @ApiOperation({ summary: "full_admin: edit one level's rules (merge, validated, audited)" })
  @Roles("full_admin")
  updateLevelRules(
    @Param("level") level: string,
    @Body() body: Record<string, unknown>,
    @Req() req: AuthedRequest
  ) {
    return this.service.updateLevelRules(currentUser(req), level, body);
  }

  @Delete("level-rules/:level")
  @ApiOperation({ summary: "full_admin: reset one level to the pack default (audited)" })
  @Roles("full_admin")
  resetLevelRules(@Param("level") level: string, @Req() req: AuthedRequest) {
    return this.service.resetLevelRules(currentUser(req), level);
  }

  // ── W4h: invigilator health score ────────────────────────────────────────

  @Get("invigilator-health")
  @ApiOperation({ summary: "full_admin: all invigilators; invigilator: own score" })
  @Roles("invigilator") // floor: invigilator, usrah_head, full_admin (service splits)
  invigilatorHealth(@Req() req: AuthedRequest) {
    return this.service.invigilatorHealth(currentUser(req));
  }

  // ── W4h: referral tree, server-side cursor-paginated ─────────────────────

  @Get("referral-tree")
  @ApiOperation({ summary: "full_admin: one cursor-paged level of the referral forest (roots or one parent's children)" })
  @Roles("full_admin")
  referralTree(
    @Query("userId") userId: string | undefined,
    @Query("cursor") cursor: string | undefined,
    @Query("limit") limit: string | undefined,
    @Req() req: AuthedRequest
  ) {
    return this.service.referralTree(currentUser(req), { userId, cursor, limit });
  }

  @Get("support")
  @ApiOperation({ summary: "full_admin: support inbox — open threads first (filter ?status=)" })
  @Roles("full_admin")
  supportThreads(@Query("status") status: string | undefined, @Req() req: AuthedRequest) {
    return this.service.supportThreads(currentUser(req), status);
  }

  @Post("support/:id/messages")
  @ApiOperation({ summary: "full_admin: reply to a support thread (status → answered, audited)" })
  @Roles("full_admin")
  supportReply(@Param("id") id: string, @Body() dto: SupportReplyDto, @Req() req: AuthedRequest) {
    return this.service.supportReply(currentUser(req), id, dto);
  }

  @Get("support/:id")
  @ApiOperation({ summary: "full_admin: one support thread + full message history" })
  @Roles("full_admin")
  supportThreadDetail(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.supportThreadDetail(currentUser(req), id);
  }

  @Post("support/:id/close")
  @HttpCode(HttpStatus.OK) // decision action, not a resource creation
  @ApiOperation({ summary: "full_admin: close a support thread (idempotent, audited)" })
  @Roles("full_admin")
  supportClose(@Param("id") id: string, @Req() req: AuthedRequest) {
    return this.service.supportClose(currentUser(req), id);
  }
}
