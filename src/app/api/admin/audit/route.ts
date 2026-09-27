import { db } from "@/lib/db";
import { requireUser } from "@/lib/server/auth";
import { assertFullAdmin, errorResponse, json } from "@/lib/server/guard";
import type { AuditEntry } from "@/types/domain";

/** GET /api/admin/audit — full_admin: last 100 audit entries with actor names. */
export async function GET() {
  try {
    const viewer = await requireUser();
    await assertFullAdmin(viewer);

    const rows = await db.auditLog.findMany({ orderBy: { createdAt: "desc" }, take: 100 });
    const actorIds = [...new Set(rows.map((a) => a.actorId).filter((x): x is string => !!x))];
    const actors = actorIds.length
      ? await db.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true } })
      : [];
    const actorNames = new Map(actors.map((a) => [a.id, a.name]));

    const entries: AuditEntry[] = rows.map((a) => {
      let meta: Record<string, unknown> | null = null;
      if (a.metaJson) {
        try {
          meta = JSON.parse(a.metaJson);
        } catch {
          meta = null;
        }
      }
      return {
        id: a.id,
        actorId: a.actorId,
        actorName: a.actorId ? actorNames.get(a.actorId) ?? null : null,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        meta,
        createdAt: a.createdAt.toISOString(),
      };
    });

    return json({ entries });
  } catch (e) {
    return errorResponse(e);
  }
}
