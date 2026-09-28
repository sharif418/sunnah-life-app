import { Injectable } from "@nestjs/common";
import { promises as fs } from "fs";
import path from "path";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import {
  bdToday,
  isDateLocked,
  isValidDateKey,
  loadActiveDefinitions,
  mapDefinition,
  mapEntry,
  ownUsrahIds,
  completion7dForUsers,
  invalidateDefinitionCache,
  type AmalDefRow,
} from "../shared/amal";
import { decideEntry, MAX_BATCH, type IncomingEntry } from "../shared/conflict";
import type { User } from "../shared/domain";

type EntryRow = {
  id: string; userId: string; amalKey: string; date: string; valueJson: unknown;
  source: string; clientUpdatedAt: Date; serverUpdatedAt: Date;
};

@Injectable()
export class AmalService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService
  ) {}

  /**
   * GET /api/amal/definitions — active catalog (public: guests keep a local
   * diary). The AmalDefinition table IS the storage (admin-configurable per
   * PLAN.md §9); if it is empty (fresh install / wiped catalog) it is seeded
   * once from the content pack (amal-catalog.json, 31 items) so the pack
   * remains the fallback of record.
   */
  async definitions(): Promise<{ definitions: ReturnType<typeof mapDefinition>[] }> {
    let rows = await this.rls.run(null, (tx) => loadActiveDefinitions(tx));
    if (!rows.length) {
      rows = await this.seedDefinitionsFromPack();
    }
    return { definitions: rows.map(mapDefinition) };
  }

  /** Seed the (empty) AmalDefinition table from the content pack (B6). */
  private async seedDefinitionsFromPack(): Promise<AmalDefRow[]> {
    return this.rls.system(async (tx) => {
      // re-check under the write context (another request may have seeded)
      const existing = await tx.amalDefinition.findMany({
        where: { active: true },
        orderBy: [{ sortOrder: "asc" }, { key: "asc" }],
      });
      if (existing.length) return existing as unknown as AmalDefRow[];

      let pack: { definitions?: unknown[] } = {};
      try {
        const contentDir =
          process.env.CONTENT_DIR || path.resolve(process.cwd(), "..", "..", "packages", "content");
        pack = JSON.parse(
          await fs.readFile(path.join(contentDir, "amal-catalog.json"), "utf8")
        );
      } catch {
        return [];
      }
      const items = (pack.definitions ?? []).filter(
        (d): d is Record<string, unknown> => !!d && typeof d === "object"
      );
      if (!items.length) return [];

      await tx.amalDefinition.createMany({
        data: items.map((d) => ({
          key: String(d.key ?? "").trim(),
          titleBn: String(d.titleBn ?? ""),
          titleEn: String(d.titleEn ?? ""),
          category: String(d.category ?? "sunnah"),
          inputType: String(d.inputType ?? "tristate"),
          cadence: String(d.cadence ?? "daily"),
          targetJson: (d.targetJson ?? undefined) as object | undefined,
          unit: d.unit != null ? String(d.unit) : null,
          minLevel: String(d.minLevel ?? "none"),
          sortOrder: Number.isFinite(Number(d.sortOrder)) ? Number(d.sortOrder) : 0,
          autoSource: d.autoSource != null ? String(d.autoSource) : null,
          active: true,
        }))
        .filter((d) => d.key && d.titleBn) as never[],
      });

      invalidateDefinitionCache();
      return (await tx.amalDefinition.findMany({
        where: { active: true },
        orderBy: [{ sortOrder: "asc" }, { key: "asc" }],
      })) as unknown as AmalDefRow[];
    });
  }

  /**
   * GET /api/amal/entries?from&to[&userId] — own diary, or another user's via
   * the gender/scope guard.
   */
  async entries(viewer: User | null, from: string, to: string, targetParam?: string) {
    const user = this.guard.requireUser(viewer);
    if (!isValidDateKey(from) || !isValidDateKey(to)) {
      throw new ApiError(400, "তারিখের পরিসর (from ও to) ঠিকভাবে দিন");
    }
    if (from > to) throw new ApiError(400, "শুরুর তারিখ শেষের তারিখের পরে হতে পারে না");

    const target = targetParam ? await this.guard.assertCanAccess(user, targetParam) : user;

    const rows = (await this.rls.run(user, (tx) =>
      tx.amalEntry.findMany({
        where: { userId: target.id, date: { gte: from, lte: to } },
        orderBy: [{ date: "asc" }, { amalKey: "asc" }],
      })
    )) as unknown as EntryRow[];
    return { entries: rows.map(mapEntry) };
  }

  /**
   * POST /api/amal/entries — batch offline-first sync for the signed-in user's
   * own diary. Rules: future dates rejected; a day locks after Ishraq of the
   * next day (unless a DayUnlock row exists); conflict rule = latest
   * clientUpdatedAt wins. Per-entry outcomes returned as {accepted, rejected}
   * with HTTP 200 (client reconciles individual entries).
   */
  async upsertEntries(viewer: User | null, incoming: IncomingEntry[]) {
    const user = this.guard.requireUser(viewer);
    if (!Array.isArray(incoming) || incoming.length === 0) {
      throw new ApiError(400, "কোনো এন্ট্রি পাওয়া যায়নি");
    }
    if (incoming.length > MAX_BATCH) {
      throw new ApiError(400, "একবারে সর্বোচ্চ ৫০০টি এন্ট্রি পাঠানো যায়");
    }

    const result = await this.rls.run(user, async (tx) => {
      const definitions = (await loadActiveDefinitions(tx)) as AmalDefRow[];
      const defKeys = new Set(definitions.map((d) => d.key));
      const today = bdToday();
      const now = new Date();

      // pre-compute lock status per distinct date (Ishraq rule + DayUnlock override)
      const dates = [
        ...new Set(incoming.map((e) => (typeof e?.date === "string" ? e.date : "")).filter(Boolean)),
      ];
      const unlocks = dates.length
        ? await tx.dayUnlock.findMany({ where: { userId: user.id, date: { in: dates } }, select: { date: true } })
        : [];
      const unlocked = new Set(unlocks.map((u) => u.date));
      const lockedByDate = new Map<string, boolean>();
      for (const d of dates) {
        lockedByDate.set(d, !unlocked.has(d) && d <= today && isValidDateKey(d) && isDateLocked(user, d));
      }

      const accepted: ReturnType<typeof mapEntry>[] = [];
      const rejected: { date: string; amalKey: string; reason: string }[] = [];

      for (const e of incoming) {
        const existing = await tx.amalEntry.findUnique({
          where: { userId_amalKey_date: { userId: user.id, amalKey: String(e?.amalKey ?? ""), date: String(e?.date ?? "") } },
        });
        const decision = decideEntry(e, defKeys, today, lockedByDate, existing, now);
        if (!decision.ok) {
          rejected.push({ date: decision.date, amalKey: decision.amalKey, reason: decision.reason });
          continue;
        }
        const row = (await tx.amalEntry.upsert({
          where: { userId_amalKey_date: { userId: user.id, amalKey: decision.amalKey, date: decision.date } },
          create: {
            userId: user.id,
            amalKey: decision.amalKey,
            date: decision.date,
            valueJson: decision.value as never,
            source: decision.source,
            clientUpdatedAt: decision.clientUpdatedAt,
            serverUpdatedAt: now,
          },
          update: {
            valueJson: decision.value as never,
            source: decision.source,
            clientUpdatedAt: decision.clientUpdatedAt,
            serverUpdatedAt: now,
          },
        })) as unknown as EntryRow;
        accepted.push(mapEntry(row));
      }

      if (accepted.length) {
        await tx.user.update({ where: { id: user.id }, data: { lastActiveAt: now } }).catch(() => undefined);
      }
      return { accepted, rejected };
    });

    return result;
  }

  /** POST /api/amal/unlock — usrah_head+ unlocks a locked diary day (audit-logged). */
  async unlock(viewer: User | null, userId: string, date: string, reason?: string) {
    const user = this.guard.requireUser(viewer);
    if (!this.guard.isSupervisor(user)) {
      throw new ApiError(403, "উসরা প্রধান বা তদের ঊর্ধ্বতনদের অনুমতি আছে");
    }
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");
    if (!date || !isValidDateKey(date)) throw new ApiError(400, "তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");

    const target = await this.guard.assertCanAccess(user, userId);
    const cleanReason =
      typeof reason === "string" && reason.trim() ? reason.trim().slice(0, 500) : null;

    await this.rls.run(user, (tx) =>
      tx.dayUnlock.upsert({
        where: { userId_date: { userId: target.id, date } },
        create: { userId: target.id, date, byUserId: user.id, reason: cleanReason },
        update: { byUserId: user.id, reason: cleanReason },
      })
    );

    await this.guard.audit(user.id, "unlock_day", "user", target.id, {
      userId: target.id,
      date,
      reason: cleanReason,
    });

    return { ok: true };
  }

  // ── shared helpers for other modules ─────────────────────────────────────

  /** Usrahs the viewer may manage (headed or member). */
  async ownUsrahs(user: User): Promise<string[]> {
    return this.rls.run(user, (tx) => ownUsrahIds(tx, user));
  }

  /** Batch 7-day completion for usrah member lists. */
  async completion7d(users: { id: string; category: string }[]): Promise<Map<string, number>> {
    return this.rls.system((tx) => completion7dForUsers(tx, users));
  }
}
