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
//     ("full_admin") end-to-end (users/support/catalog/audit/content/settings).
//   • the usrah JOIN queue is full_admin-only by design (W4d boundary: heads
//     never assign membership) — so it is NOT in any supervisor nav.
// ─────────────────────────────────────────────────────────────────────────────

/** Route prefixes whose whole API surface is full_admin-only. */
const FULL_ADMIN_PREFIXES = [
  "/users",
  "/support",
  "/catalog",
  "/audit",
  "/content",
  "/settings",
  "/level-rules", // W4h editor — GET/PUT/DELETE /api/admin/level-rules is full_admin-only
];

/** Is this pathname accessible for the role? (Assumes an authenticated
 * supervisor — the session layer refuses everyone below.) */
export function routeAllowed(pathname: string, role: string | null | undefined): boolean {
  if (!role) return false;
  const seg = `/${pathname.split("/").filter(Boolean)[0] ?? ""}`;
  if (FULL_ADMIN_PREFIXES.includes(seg)) return role === "full_admin";
  // every other admin route (/, /usrah, /reviews, /assessments, /levels,
  // /broadcast, /live, /exports, /referrals, /members/…) is supervisor-floor
  return true;
}
