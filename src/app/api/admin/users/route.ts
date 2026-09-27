import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, audit, requireUser, toDomainUser } from "@/lib/server/auth";
import { assertFullAdmin, errorResponse, isSupervisor, json } from "@/lib/server/guard";
import { ownUsrahIds } from "@/lib/server/amal";
import type { Gender, Role, User, UserCategory } from "@/types/domain";

const ROLES: Role[] = ["user", "daee", "usrah_head", "invigilator", "full_admin"];
const GENDERS: Gender[] = ["M", "F"];
const CATEGORIES: UserCategory[] = ["general", "hafez", "alim"];

function searchFilter(q: string) {
  const term = q.trim();
  if (!term) return {};
  return {
    OR: [
      { name: { contains: term } },
      { phone: { contains: term } },
      { memberCode: { contains: term.toUpperCase() } },
    ],
  };
}

/** Next DS-XXXXXX member code: max numeric suffix + 1. */
async function nextMemberCode(): Promise<string> {
  const rows = await db.user.findMany({ where: { memberCode: { not: null } }, select: { memberCode: true } });
  let max = 0;
  for (const r of rows) {
    const m = /^DS-(\d+)$/.exec(r.memberCode ?? "");
    if (m) max = Math.max(max, Number(m[1]));
  }
  return `DS-${String(max + 1).padStart(6, "0")}`;
}

/**
 * GET /api/admin/users?q= — scoped search: full_admin all, invigilator own
 * gender, usrah_head own-usrah members. Includes usrahName.
 */
export async function GET(req: NextRequest) {
  try {
    const viewer = await requireUser();
    if (!isSupervisor(viewer)) throw new ApiError(403, "অ্যাডমিন প্যানেল দেখার অনুমতি নেই");

    const q = req.nextUrl.searchParams.get("q") ?? "";
    const like = searchFilter(q);

    let where: Record<string, unknown>;
    if (viewer.role === "full_admin") {
      where = like;
    } else if (viewer.role === "invigilator") {
      where = { gender: viewer.gender, ...like };
    } else {
      const usrahIds = await ownUsrahIds(viewer);
      where = usrahIds.length ? { usrahId: { in: usrahIds }, ...like } : { id: "__none__" };
    }

    const rows = await db.user.findMany({
      where,
      include: { usrah: { select: { name: true } } },
      orderBy: { name: "asc" },
      take: 100,
    });

    const users: (User & { usrahName?: string | null })[] = rows.map((r) => ({
      ...toDomainUser(r),
      usrahName: r.usrah?.name ?? null,
    }));
    return json({ users });
  } catch (e) {
    return errorResponse(e);
  }
}

/**
 * PATCH /api/admin/users — full_admin only. Change role / gender / usrah /
 * category. Gender & role changes are audit-logged; promoting to daee assigns
 * the next member code if the user has none.
 */
export async function PATCH(req: NextRequest) {
  try {
    const viewer = await requireUser();
    await assertFullAdmin(viewer);

    const body = (await req.json().catch(() => null)) as {
      userId?: string;
      role?: string;
      gender?: string;
      usrahId?: string | null;
      category?: string;
    } | null;
    const userId = body?.userId;
    if (!userId) throw new ApiError(400, "ব্যবহারকারী নির্বাচন করা হয়নি");

    const target = await db.user.findUnique({ where: { id: userId } });
    if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");

    const data: Record<string, unknown> = {};

    if (body?.role !== undefined) {
      if (!ROLES.includes(body.role as Role)) throw new ApiError(400, "ভূমিকা ঠিক নয়");
      if (body.role !== target.role) {
        await audit(viewer.id, "change_role", "user", target.id, {
          userId: target.id,
          from: target.role,
          to: body.role,
        });
        if (body.role === "daee" && !target.memberCode) {
          data.memberCode = await nextMemberCode();
        }
        data.role = body.role;
      }
    }

    if (body?.gender !== undefined) {
      if (!GENDERS.includes(body.gender as Gender)) throw new ApiError(400, "লিঙ্গ ঠিক নয়");
      if (body.gender !== target.gender) {
        await audit(viewer.id, "change_gender", "user", target.id, {
          userId: target.id,
          from: target.gender,
          to: body.gender,
        });
        data.gender = body.gender;
      }
    }

    if (body?.usrahId !== undefined) {
      if (body.usrahId === null) {
        data.usrahId = null;
      } else {
        const usrah = await db.usrah.findUnique({ where: { id: body.usrahId } });
        if (!usrah) throw new ApiError(400, "উসরা পাওয়া যায়নি");
        data.usrahId = body.usrahId;
      }
    }

    if (body?.category !== undefined) {
      if (!CATEGORIES.includes(body.category as UserCategory)) throw new ApiError(400, "ক্যাটাগরি ঠিক নয়");
      data.category = body.category;
    }

    if (!Object.keys(data).length) throw new ApiError(400, "কোনো পরিবর্তন দেওয়া হয়নি");

    const updated = await db.user.update({ where: { id: target.id }, data });
    return json({ user: toDomainUser(updated) });
  } catch (e) {
    return errorResponse(e);
  }
}
