import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, requireUser } from "@/lib/server/auth";
import { assertFullAdmin, errorResponse, json } from "@/lib/server/guard";
import { invalidateDefinitionCache, loadActiveDefinitions, mapDefinition } from "@/lib/server/amal";
import type { AmalCadence, AmalCategory, AmalInputType, Level } from "@/types/domain";

const INPUT_TYPES: AmalInputType[] = ["tristate", "boolean", "count", "quantity", "text"];
const CADENCES: AmalCadence[] = ["daily", "weekly:any", "weekly:fri", "weekly:mon_thu", "monthly:ayyam_beez"];
const CATEGORIES: AmalCategory[] = ["salah", "quran", "dhikr", "akhlaq", "dawat", "lifestyle", "sunnah", "personal"];
const LEVELS: Level[] = ["none", "muhibbus_sunnah", "farze_ain_1", "farze_ain_2"];

/**
 * POST /api/admin/amal-catalog — full_admin upserts an AmalDefinition by key.
 * Accepts `target` (object → serialized) or a raw `targetJson` string.
 * Returns the full active catalog (same shape as GET /api/amal/definitions).
 */
export async function POST(req: NextRequest) {
  try {
    const viewer = await requireUser();
    await assertFullAdmin(viewer);

    const body = (await req.json().catch(() => null)) as {
      key?: string;
      titleBn?: string;
      titleEn?: string;
      category?: string;
      inputType?: string;
      cadence?: string;
      target?: Record<string, number> | null;
      targetJson?: string | null;
      unit?: string | null;
      minLevel?: string;
      sortOrder?: number;
      autoSource?: string | null;
      active?: boolean;
    } | null;

    const key = (body?.key ?? "").trim();
    if (!key) throw new ApiError(400, "আমলের কী (key) দিন");

    const existing = await db.amalDefinition.findUnique({ where: { key } });

    const titleBn = (body?.titleBn ?? existing?.titleBn ?? "").trim();
    const titleEn = (body?.titleEn ?? existing?.titleEn ?? "").trim();
    if (!titleBn) throw new ApiError(400, "বাংলা শিরোনাম দিন");

    const category = (body?.category ?? existing?.category ?? "sunnah") as AmalCategory;
    if (!CATEGORIES.includes(category)) throw new ApiError(400, "ক্যাটাগরি ঠিক নয়");

    const inputType = (body?.inputType ?? existing?.inputType ?? "tristate") as AmalInputType;
    if (!INPUT_TYPES.includes(inputType)) throw new ApiError(400, "ইনপুট ধরন ঠিক নয়");

    const cadence = (body?.cadence ?? existing?.cadence ?? "daily") as AmalCadence;
    if (!CADENCES.includes(cadence)) throw new ApiError(400, "পর্যায়ক্রম ঠিক নয়");

    let targetJson: string | null = null;
    if (typeof body?.targetJson === "string") {
      targetJson = body.targetJson;
    } else if (body?.target && typeof body.target === "object") {
      targetJson = JSON.stringify(body.target);
    } else if (body?.target === null) {
      targetJson = null;
    } else {
      targetJson = existing?.targetJson ?? null;
    }

    const minLevel = (body?.minLevel ?? existing?.minLevel ?? "none") as Level;
    if (!LEVELS.includes(minLevel)) throw new ApiError(400, "স্তর ঠিক নয়");

    const sortOrder = Number.isFinite(Number(body?.sortOrder))
      ? Number(body?.sortOrder)
      : (existing?.sortOrder ?? 0);
    const active = typeof body?.active === "boolean" ? body.active : (existing?.active ?? true);

    await db.amalDefinition.upsert({
      where: { key },
      create: {
        key,
        titleBn,
        titleEn,
        category,
        inputType,
        cadence,
        targetJson,
        unit: body?.unit != null ? String(body.unit) : (existing?.unit ?? null),
        minLevel,
        sortOrder,
        autoSource: body?.autoSource != null ? String(body.autoSource) : (existing?.autoSource ?? null),
        active,
      },
      update: {
        titleBn,
        titleEn,
        category,
        inputType,
        cadence,
        targetJson,
        unit: body?.unit != null ? String(body.unit) : (existing?.unit ?? null),
        minLevel,
        sortOrder,
        autoSource: body?.autoSource != null ? String(body.autoSource) : (existing?.autoSource ?? null),
        active,
      },
    });

    invalidateDefinitionCache();
    const rows = await loadActiveDefinitions();
    return json({ definitions: rows.map(mapDefinition) });
  } catch (e) {
    return errorResponse(e);
  }
}
