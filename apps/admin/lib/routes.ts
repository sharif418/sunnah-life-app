// ─────────────────────────────────────────────────────────────────────────────
// W4h — route access map for the admin app.
//
// The nav FILTERS by role; this is the matching URL-level gate. A role that
// opens a URL outside its map is REDIRECTED to their dashboard (not a 403
// wall) — the layout consumes routeAllowed(). The map mirrors what the API
// actually lets each role DO (RolesGuard ranks + per-route service checks):
//   • usrah_head + invigilator share rank 2 — the API differentiates them only
//     by RLS data scope, never by route, so their page map is identical.
//   • the admin-only pages are the ones whose API surface is @Roles
//     ("full_admin") end-to-end (users/support/catalog/audit/settings).
//   • /content is the content workflow: full_admin and the content team
//     (editor / reviewer alim — possibly plain members) — nothing else for
//     a content-only member.
//   • the usrah JOIN queue is full_admin-only by design (W4d boundary: heads
//     never assign membership) — so it is NOT in any supervisor nav.
// ─────────────────────────────────────────────────────────────────────────────

/** Route prefixes whose whole API surface is full_admin-only. */
const FULL_ADMIN_PREFIXES = [
  "/users",
  "/support",
  "/catalog",
  "/audit",
  "/settings",
  "/level-rules", // W4h editor — GET/PUT/DELETE /api/admin/level-rules is full_admin-only
];

/** The content workflow (/api/admin/cms): full_admin and the content team
 * (editors, reviewing scholars) — whatever their tarbiyah role. */
const CONTENT_PREFIX = "/content";

interface RouteUser {
  role: string;
  contentRole?: string | null;
}

const onContentTeam = (u: RouteUser) => u.contentRole === "editor" || u.contentRole === "reviewer";
const supervisorRole = (role: string) => ["usrah_head", "invigilator", "full_admin"].includes(role);

/** Is this pathname accessible for the user? (Assumes a signed-in user the
 * session admitted: a supervisor, or a member of the content team.) */
export function routeAllowed(pathname: string, user: RouteUser | null | undefined): boolean {
  if (!user) return false;
  const seg = `/${pathname.split("/").filter(Boolean)[0] ?? ""}`;
  if (seg === CONTENT_PREFIX) return user.role === "full_admin" || onContentTeam(user);
  // the content team without a supervisor role sees the content pages only
  if (!supervisorRole(user.role)) return false;
  if (FULL_ADMIN_PREFIXES.includes(seg)) return user.role === "full_admin";
  // every other admin route (/, /usrah, /reviews, /assessments, /levels,
  // /broadcast, /live, /exports, /referrals, /members/…) is supervisor-floor
  return true;
}

/** Where a user lands (and is sent back to from a page outside their map). */
export function homeRoute(user: RouteUser | null | undefined): string {
  return user && !supervisorRole(user.role) && onContentTeam(user) ? CONTENT_PREFIX : "/";
}
