import { Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { promises as fs } from "fs";
import path from "path";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { StorageService } from "../storage/storage.service";
import { loadActiveDefinitions, bdToday, type AmalDefRow } from "../shared/amal";
import { toBn } from "../shared/calendars";
import { contentDir } from "../shared/levels";
import { renderMonthlyReport } from "./report-renderer";
import {
  dayRangeLabelBn,
  monthDays,
  monthLabelBn,
  monthWeeks,
  bdDateKey,
  type MonthlyReportData,
  type PaperGroup,
  type ReportAmalDef,
  type ReportWeekComment,
} from "./report-data";
import type { User } from "../shared/domain";

/**
 * The paper monthly sheet's layout (packages/content/diary-instructions.json
 * → paperLayout). Missing or unreadable → null: the renderer falls back to
 * the catalog-grouped grid instead of failing the report.
 */
async function loadPaperLayout(): Promise<PaperGroup[] | null> {
  try {
    const raw = JSON.parse(await fs.readFile(path.join(contentDir(), "diary-instructions.json"), "utf8")) as {
      paperLayout?: PaperGroup[];
    };
    return Array.isArray(raw.paperLayout) && raw.paperLayout.length ? raw.paperLayout : null;
  } catch {
    return null;
  }
}

/** Rendered-row shape returned by the endpoints (storage key + status). */
export interface ReportRow {
  id: string;
  userId: string;
  userName: string | null;
  memberCode: string | null;
  month: string;
  storageKey: string;
  byteSize: number;
  status: string;
  errorBn: string | null;
  generatedAt: string;
}

interface DbReportRow {
  id: string;
  userId: string;
  month: string;
  storageKey: string;
  byteSize: number;
  status: string;
  errorBn: string | null;
  generatedAt: Date;
  user?: { name: string; memberCode: string | null } | null;
}

export const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

function mapRow(r: DbReportRow): ReportRow {
  return {
    id: r.id,
    userId: r.userId,
    userName: r.user?.name ?? null,
    memberCode: r.user?.memberCode ?? null,
    month: r.month,
    storageKey: r.storageKey,
    byteSize: r.byteSize,
    status: r.status,
    errorBn: r.errorBn,
    generatedAt: r.generatedAt.toISOString(),
  };
}

/**
 * Monthly Muhasaba report — data loading, rendering, storage, listing.
 *
 * RLS path (the important part): the amal entries, weekly reviews and usrah
 * name for the report are read inside `rls.run(target)` — the MEMBER's own
 * Row-Level-Security context — so the database itself enforces that the
 * report contains exactly what the member may see of their own diary. The
 * caller (admin manual trigger or the queue worker) has already proven,
 * via GuardService.assertCanAccess or the worker's system context, that the
 * generation itself is authorized. Nothing bypasses RLS.
 */
@Injectable()
export class ReportsService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly storage: StorageService
  ) {}

  /** POST /api/admin/reports/generate — synchronous render + store + row. */
  async generate(viewer: User | null, userId: string, month: string): Promise<ReportRow> {
    const user = this.guard.requireUser(viewer);
    this.assertMonth(month);
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    // full_admin only (route floor) — assertCanAccess is belt+suspenders for
    // any future supervisor callers: gender/usrah/downline rules apply.
    const target = await this.guard.assertCanAccess(user, userId);
    return this.generateForUser(target, month, user);
  }

  /**
   * Render + store one member's report. `actor` is the context that writes
   * the MonthlyReport row + reminder: the admin viewer (manual) or the
   * member themselves (worker path — the RLS policy allows self writes).
   */
  async generateForUser(target: User, month: string, actor?: User): Promise<ReportRow> {
    this.assertMonth(month);
    const writer = actor ?? target;

    const existing = await this.rls.run(writer, (tx) =>
      tx.monthlyReport.findUnique({ where: { userId_month: { userId: target.id, month } } })
    );
    const reportId = existing?.id ?? randomUUID();
    const storageKey = `reports/${target.id}/${month}.pdf`;

    const paperLayout = await loadPaperLayout();

    // ── load everything THROUGH RLS AS THE MEMBER ─────────────────────────────
    const data = await this.rls.run(target, async (tx) => {
      const days = monthDays(month);
      const weeks = monthWeeks(days);

      const defRows = (await loadActiveDefinitions(tx)) as AmalDefRow[];
      const definitions: ReportAmalDef[] = defRows.map((d) => ({
        key: d.key,
        titleBn: d.titleBn,
        category: d.category,
        inputType: d.inputType,
        cadence: d.cadence,
        unit: d.unit,
      }));

      const entries = (await tx.amalEntry.findMany({
        where: { userId: target.id, date: { gte: days[0], lte: days[days.length - 1] } },
        select: { amalKey: true, date: true, valueJson: true },
      })) as unknown as { amalKey: string; date: string; valueJson: unknown }[];

      const usrah = target.usrahId
        ? await tx.usrah.findUnique({ where: { id: target.usrahId }, select: { name: true } })
        : null;

      const reviews = await tx.weeklyReview.findMany({
        where: { userId: target.id, weekStart: { in: weeks.map((w) => w.start) } },
        orderBy: { weekStart: "asc" },
      });
      const reviewerIds = [...new Set(reviews.map((r) => r.reviewerId))];
      const reviewers = reviewerIds.length
        ? await tx.user.findMany({ where: { id: { in: reviewerIds } }, select: { id: true, name: true } })
        : [];
      const reviewerNames = new Map(reviewers.map((r) => [r.id, r.name]));

      const comments: ReportWeekComment[] = reviews.map((r) => {
        const week = weeks.find((w) => w.start === r.weekStart);
        const range = week ? dayRangeLabelBn(week.days) : r.weekStart;
        return {
          weekLabel: `সপ্তাহ ${toBn(week?.index ?? 1)} (${range})`,
          reviewerName: reviewerNames.get(r.reviewerId) ?? null,
          comment: r.comment,
          rating: r.rating,
          nextGoals: r.nextGoals,
        };
      });

      const payload: MonthlyReportData = {
        reportId,
        member: {
          name: target.name,
          memberCode: target.memberCode,
          district: target.district,
          usrahName: usrah?.name ?? null,
          joinedOn: bdDateKey(new Date(target.createdAt)),
        },
        month,
        days,
        definitions,
        entries: entries.map((e) => ({ amalKey: e.amalKey, date: e.date, value: e.valueJson })),
        reviews: comments,
        generatedAt: new Date(),
        paperLayout: paperLayout ?? undefined,
      };
      return payload;
    });

    // ── render + store (failures recorded on the row, never thrown away) ─────
    try {
      const pdf = await renderMonthlyReport(data);
      await this.storage.put(storageKey, pdf, "application/pdf");

      return await this.rls.run(writer, async (tx) => {
        const row = await tx.monthlyReport.upsert({
          where: { userId_month: { userId: target.id, month } },
          create: {
            id: reportId,
            userId: target.id,
            month,
            storageKey,
            byteSize: pdf.length,
            status: "ready",
            generatedAt: new Date(),
          },
          update: {
            storageKey,
            byteSize: pdf.length,
            status: "ready",
            errorBn: null,
            generatedAt: new Date(),
          },
        });
        // first generation → tell the member the report exists
        if (!existing) {
          await tx.reminder.create({
            data: {
              userId: target.id,
              kind: "report",
              title: "মাসিক মুহাসাবা রিপোর্ট প্রস্তুত",
              body: `${monthLabelBn(month)} মাসের মুহাসাবা রিপোর্ট (PDF) তৈরি হয়েছে। উসরা প্রধানের সাথে মুহাসাবা মজলিসে যাচাই করুন।`,
              link: "dawah",
            },
          });
        }
        return mapRow(row as unknown as DbReportRow);
      });
    } catch (e) {
      const errorBn = e instanceof Error ? e.message : "অজানা ত্রুটি";
      await this.rls
        .run(writer, (tx) =>
          tx.monthlyReport.upsert({
            where: { userId_month: { userId: target.id, month } },
            create: {
              id: reportId,
              userId: target.id,
              month,
              storageKey,
              byteSize: 0,
              status: "failed",
              errorBn: errorBn.slice(0, 500),
            },
            update: { status: "failed", errorBn: errorBn.slice(0, 500) },
          })
        )
        .catch(() => undefined);
      // the failed row keeps the detail for diagnosis; the response carries
      // only our own (Bengali) messages, never an internal error text
      throw new ApiError(500, e instanceof ApiError ? `রিপোর্ট তৈরি করা যায়নি: ${errorBn}` : "রিপোর্ট তৈরি করা যায়নি — একটু পরে আবার চেষ্টা করুন");
    }
  }

  /** GET /api/admin/reports?userId&month&take — RLS-scoped list. */
  async list(
    viewer: User | null,
    filters: { userId?: string; month?: string; take?: number }
  ): Promise<{ reports: ReportRow[] }> {
    const user = this.guard.requireUser(viewer);
    if (filters.month && !MONTH_RE.test(filters.month)) {
      throw new ApiError(400, "মাস ঠিকভাবে দিন (YYYY-MM)");
    }
    const take = Math.min(Math.max(filters.take ?? 100, 1), 500);

    const rows = (await this.rls.run(user, (tx) =>
      tx.monthlyReport.findMany({
        where: {
          ...(filters.userId ? { userId: filters.userId } : {}),
          ...(filters.month ? { month: filters.month } : {}),
        },
        include: { user: { select: { name: true, memberCode: true } } },
        orderBy: [{ month: "desc" }, { generatedAt: "desc" }],
        take,
      })
    )) as unknown as DbReportRow[];
    return { reports: rows.map(mapRow) };
  }

  /** GET /api/admin/reports/:id/download — loads through RLS then streams. */
  async download(viewer: User | null, id: string): Promise<{ row: ReportRow; pdf: Buffer }> {
    const user = this.guard.requireUser(viewer);
    if (!id) throw new ApiError(400, "রিপোর্ট আইডি দিন");

    const row = (await this.rls.run(user, (tx) =>
      tx.monthlyReport.findUnique({ where: { id }, include: { user: { select: { name: true, memberCode: true } } } })
    )) as unknown as DbReportRow | null;
    if (!row) throw new ApiError(404, "রিপোর্ট পাওয়া যায়নি");
    if (row.status !== "ready" || row.byteSize === 0) {
      throw new ApiError(409, "রিপোর্টটি এখনো প্রস্তুত হয়নি");
    }

    let pdf: Buffer;
    try {
      pdf = await this.storage.get(row.storageKey);
    } catch {
      throw new ApiError(410, "রিপোর্ট ফাইলটি স্টোরেজে পাওয়া যায়নি — আবার তৈরি করুন");
    }
    return { row: mapRow(row), pdf };
  }

  /** Validate the month key; future months have no data yet. */
  private assertMonth(month: string): void {
    if (!MONTH_RE.test(month)) throw new ApiError(400, "মাস ঠিকভাবে দিন (YYYY-MM)");
    if (month > bdToday().slice(0, 7)) throw new ApiError(400, "ভবিষ্যতের মাসের রিপোর্ট তৈরি করা যায় না");
  }
}
