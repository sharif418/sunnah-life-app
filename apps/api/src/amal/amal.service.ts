import { Injectable } from "@nestjs/common";
import { promises as fs } from "fs";
import path from "path";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { GuardService } from "../common/guard.service";
import { PushService } from "../push/push.service";
import { Prisma } from "../common/prisma-client";
import {
  todayForUser,
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
import { decideEntry, MAX_BATCH, REJECT_REASONS, type IncomingEntry } from "../shared/conflict";
import type { AmalValue, User } from "../shared/domain";

type EntryRow = {
  id: string; userId: string; amalKey: string; date: string; valueJson: unknown;
  source: string; clientUpdatedAt: Date; serverUpdatedAt: Date;
};

@Injectable()
export class AmalService {
  constructor(
    private readonly rls: RlsService,
    private readonly guard: GuardService,
    private readonly push: PushService
  ) {}

  /**
   * GET /api/amal/definitions — active catalog (public: guests keep a local
   * diary). The AmalDefinition table IS the storage (admin-configurable per
   * PLAN.md §9); if it is empty (fresh install / wiped catalog) it is seeded
   * once from the content pack (amal-catalog.json, 35 items) so the pack
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

      let pack: { definitions?: unknown[] };
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
      const defTypes = new Map(definitions.map((d) => [d.key, d.inputType] as const));
      const today = todayForUser(user);
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
      const rejected: { date: string; amalKey: string; reason: string; serverValue?: AmalValue }[] = [];

      for (const e of incoming) {
        // (a) read for the DECISION only — the write below re-checks the
        // conflict atomically, so a concurrent writer between here and the
        // write can never be overwritten by this (older) decision (W2g).
        const existing = await tx.amalEntry.findUnique({
          where: { userId_amalKey_date: { userId: user.id, amalKey: String(e?.amalKey ?? ""), date: String(e?.date ?? "") } },
        });
        const decision = decideEntry(
          e,
          defKeys,
          defTypes,
          today,
          lockedByDate,
          existing && {
            amalKey: existing.amalKey,
            date: existing.date,
            clientUpdatedAt: existing.clientUpdatedAt,
            value: existing.valueJson,
          },
          now
        );
        if (!decision.ok) {
          rejected.push(
            decision.serverValue === undefined
              ? { date: decision.date, amalKey: decision.amalKey, reason: decision.reason }
              : { date: decision.date, amalKey: decision.amalKey, reason: decision.reason, serverValue: decision.serverValue }
          );
          continue;
        }
        // (b) CONDITIONAL ATOMIC WRITE: only overwrite when the stored row is
        // strictly OLDER (lt) — "newest clientUpdatedAt wins" re-checked at
        // write time, closing the findUnique→upsert race (W2g).
        const updated = await tx.amalEntry.updateMany({
          where: {
            userId: user.id,
            amalKey: decision.amalKey,
            date: decision.date,
            clientUpdatedAt: { lt: decision.clientUpdatedAt },
          },
          data: {
            valueJson: decision.value as never,
            source: decision.source,
            clientUpdatedAt: decision.clientUpdatedAt,
            serverUpdatedAt: now,
          },
        });
        if (updated.count === 0) {
          // No row updated (absent, or a concurrent writer landed a newer
          // one since the findUnique) → create. SAVEPOINT-wrapped: a P2002
          // from a lost race must not abort the whole batch's transaction
          // (Postgres aborts the tx on an uncaught constraint violation and
          // Prisma adds no per-statement savepoints).
          await tx.$executeRawUnsafe("SAVEPOINT w2g_amal_create");
          try {
            const row = await tx.amalEntry.create({
              data: {
                userId: user.id,
                amalKey: decision.amalKey,
                date: decision.date,
                valueJson: decision.value as never,
                source: decision.source,
                clientUpdatedAt: decision.clientUpdatedAt,
                serverUpdatedAt: now,
              },
            });
            await tx.$executeRawUnsafe("RELEASE SAVEPOINT w2g_amal_create");
            accepted.push(mapEntry(row as unknown as EntryRow));
          } catch (err) {
            await tx.$executeRawUnsafe("ROLLBACK TO SAVEPOINT w2g_amal_create");
            await tx.$executeRawUnsafe("RELEASE SAVEPOINT w2g_amal_create");
            if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
              // a concurrent writer created the row first → they won (W2g)
              rejected.push({ date: decision.date, amalKey: decision.amalKey, reason: REJECT_REASONS.newerVersion });
            } else {
              throw err;
            }
          }
        } else {
          const row = await tx.amalEntry.findUnique({
            where: { userId_amalKey_date: { userId: user.id, amalKey: decision.amalKey, date: decision.date } },
          });
          accepted.push(mapEntry(row as unknown as EntryRow));
        }
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

  /**
   * POST /api/amal/unlock-request — a member asks their usrah head to open a
   * locked diary day. The day itself is opened by the head (POST
   * /api/amal/unlock, or the admin panel's member page); this only tells
   * them, in their inbox and as a push. One message per member and day.
   * (The app's "আনলক চাই" called /unlock directly, which only heads may —
   * a member got 403 and the head never heard.)
   */
  async requestUnlock(viewer: User | null, date: string) {
    const user = this.guard.requireUser(viewer);
    if (!date || !isValidDateKey(date)) throw new ApiError(400, "তারিখ ঠিকভাবে দিন (YYYY-MM-DD)");
    if (date >= todayForUser(user)) throw new ApiError(400, "আজকের বা সামনের দিন লক হয় না");
    if (!user.usrahId) throw new ApiError(400, "উসরায় যুক্ত হলে উসরা প্রধানকে অনুরোধ পাঠানো যাবে");

    const headId = await this.rls.system(async (tx) => {
      const usrah = await tx.usrah.findUnique({ where: { id: user.usrahId! }, select: { headUserId: true } });
      return usrah?.headUserId ?? null;
    });
    if (!headId || headId === user.id) throw new ApiError(400, "আপনার উসরায় এখনো কোনো উসরা প্রধান নেই");

    const title = "ডায়েরির দিন খোলার অনুরোধ";
    const body = `${user.name} ${date} তারিখের ডায়েরি খুলে দিতে অনুরোধ করেছেন — অ্যাডমিন প্যানেলে সদস্যের পাতা থেকে খুলুন।`;
    const created = await this.rls.system(async (tx) => {
      const existing = await tx.reminder.findFirst({
        where: { userId: headId, kind: "unlock_request", body, read: false },
        select: { id: true },
      });
      if (existing) return false;
      await tx.reminder.create({
        data: { userId: headId, kind: "unlock_request", title, body, link: "dawah" },
      });
      return true;
    });
    if (created) {
      await this.push
        .send([headId], { title, body: `${user.name} — ${date}`, deepLink: "/dawah" }, { actor: user })
        .catch(() => undefined);
    }
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
