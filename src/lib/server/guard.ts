import "server-only";
import { db } from "@/lib/db";
import { ApiError, toDomainUser } from "@/lib/server/auth";
import type { User } from "@/types/domain";
import { ROLE_RANK } from "@/types/domain";

// ─────────────────────────────────────────────────────────────────────────────
// Gender & scope guard — the application-layer equivalent of the production
// PostgreSQL RLS policies. EVERY read/write of another user's data must pass
// through assertCanAccess. Full Admin sees both genders; everyone else is
// strictly gender-scoped:
//   • usrah_head → members of usrahs they head
//   • invigilator → any user of own gender (oversight role)
//   • daee → self + own downline (same gender, enforced by referral closure)
// ─────────────────────────────────────────────────────────────────────────────

export async function assertCanAccess(viewer: User, targetId: string): Promise<User> {
  const target = await db.user.findUnique({ where: { id: targetId } });
  if (!target) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
  const t = toDomainUser(target);

  if (viewer.id === targetId) return t;
  if (viewer.role === "full_admin") return t;

  if (viewer.gender !== t.gender) {
    throw new ApiError(403, "বিপরীত লিঙ্গের তথ্য দেখার অনুমতি নেই");
  }

  if (viewer.role === "invigilator") return t;

  if (viewer.role === "usrah_head") {
    if (t.usrahId && t.usrahId === viewer.usrahId) return t;
    // heads may also view users in usrahs they head (headUserId set on usrah)
    const usrah = t.usrahId ? await db.usrah.findUnique({ where: { id: t.usrahId } }) : null;
    if (usrah?.headUserId === viewer.id) return t;
    throw new ApiError(403, "শুধুমাত্র নিজের উসরার সদস্যদের দেখা যাবে");
  }

  if (viewer.role === "daee") {
    const link = await db.referralClosure.findUnique({
      where: { ancestorId_descendantId: { ancestorId: viewer.id, descendantId: targetId } },
    });
    if (link) return t;
    throw new ApiError(403, "শুধুমাত্র নিজের মাদউ দেখা যাবে");
  }

  throw new ApiError(403, "অনুমতি নেই");
}

/** Role floor check: viewer must be usrah_head or above (heads, invigilators, admins). */
export function isSupervisor(user: User): boolean {
  return ROLE_RANK[user.role] >= ROLE_RANK["usrah_head"];
}

/** Only full admin may change gender / roles / levels arbitrarily. */
export async function assertFullAdmin(viewer: User): Promise<void> {
  if (viewer.role !== "full_admin") throw new ApiError(403, "শুধুমাত্র প্রধান অ্যাডমিন এই কাজ করতে পারবেন");
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function errorResponse(e: unknown): Response {
  if (e instanceof ApiError) return json({ error: e.message }, e.status);
  console.error("[api]", e instanceof Error ? e.message : e);
  return json({ error: "সার্ভারে সমস্যা হয়েছে" }, 500);
}
