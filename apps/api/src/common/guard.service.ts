import { Injectable } from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import { ApiError } from "./api-error";
import { RlsService } from "./rls.service";
import type { User } from "../shared/domain";
import { ROLE_RANK } from "../shared/domain";

// ─────────────────────────────────────────────────────────────────────────────
// Gender & scope guard — the application-layer equivalent of the PostgreSQL
// RLS policies (both layers agree; RLS is the safety net). EVERY read/write of
// another user's data must pass through assertCanAccess.
//   • usrah_head → members of usrahs they head (headUserId or own membership)
//   • invigilator → any user of own gender (oversight role)
//   • daee → self + own downline (same gender, enforced by referral closure)
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class GuardService {
  constructor(private readonly rls: RlsService) {}

  /** Throws 401 unless a user is attached. */
  requireUser(user: User | null): User {
    if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");
    return user;
  }

  /** Role floor check: usrah_head and above (heads, invigilators, admins). */
  isSupervisor(user: User): boolean {
    return ROLE_RANK[user.role] >= ROLE_RANK["usrah_head"];
  }

  requireSupervisor(user: User | null): User {
    const u = this.requireUser(user);
    if (!this.isSupervisor(u)) throw new ApiError(403, "এই কাজের অনুমতি নেই");
    return u;
  }

  /** Only full admin may change gender / roles / levels arbitrarily. */
  assertFullAdmin(viewer: User): void {
    if (viewer.role !== "full_admin") {
      throw new ApiError(403, "শুধুমাত্র প্রধান অ্যাডমিন এই কাজ করতে পারবেন");
    }
  }

  async assertCanAccess(viewer: User, targetId: string): Promise<User> {
    // Existence + metadata first (system context) so the caller gets the
    // CORRECT error: 404 when the user truly does not exist, 403 with the
    // gender message when the target is of the opposite gender. Returning
    // the target from here does NOT bypass RLS — the caller's own
    // rls.run(viewer, …) context still gates every actual data read, and the
    // DB-level refusal is proven by test/rls.e2e.spec.ts.
    const row = await this.rls.system((tx) => tx.user.findUnique({ where: { id: targetId } }));
    if (!row) throw new ApiError(404, "ব্যবহারকারী পাওয়া যায়নি");
    const t: User = {
      ...row,
      gender: row.gender as User["gender"],
      role: row.role as User["role"],
      category: row.category as User["category"],
      level: row.level as User["level"],
      language: row.language as User["language"],
      madhhab: row.madhhab as User["madhhab"],
      calcMethod: row.calcMethod as User["calcMethod"],
      levelStartedAt: row.levelStartedAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
      lastActiveAt: row.lastActiveAt.toISOString(),
    };

    if (viewer.id === t.id) return t;
    if (viewer.role === "full_admin") return t;
    if (viewer.gender !== t.gender) {
      throw new ApiError(403, "বিপরীত লিঙ্গের তথ্য দেখার অনুমতি নেই");
    }

    // Same-gender scoping (usrah membership / head / downline) — checked in
    // the viewer's own RLS context so even these lookups obey the policies.
    return this.rls.run(viewer, async (tx) => {
      if (viewer.role === "invigilator") return t;

      if (viewer.role === "usrah_head") {
        if (t.usrahId && t.usrahId === viewer.usrahId) return t;
        const usrah = t.usrahId ? await tx.usrah.findUnique({ where: { id: t.usrahId } }) : null;
        if (usrah?.headUserId === viewer.id) return t;
        throw new ApiError(403, "শুধুমাত্র নিজের উসরার সদস্যদের দেখা যাবে");
      }

      if (viewer.role === "daee") {
        const link = await tx.referralClosure.findUnique({
          where: { ancestorId_descendantId: { ancestorId: viewer.id, descendantId: targetId } },
        });
        if (link) return t;
        throw new ApiError(403, "শুধুমাত্র নিজের মাদউ দেখা যাবে");
      }

      throw new ApiError(403, "অনুমতি নেই");
    });
  }

  /** Write an audit entry (AuditLog is RLS-exempt; system context is fine). */
  async audit(
    actorId: string | null,
    action: string,
    targetType: string,
    targetId?: string | null,
    meta?: Record<string, unknown>
  ): Promise<void> {
    await this.rls.system((tx: Prisma.TransactionClient) =>
      tx.auditLog.create({
        data: {
          actorId,
          action,
          targetType,
          targetId: targetId ?? null,
          metaJson: meta ? (meta as object) : undefined,
        },
      })
    );
  }
}
