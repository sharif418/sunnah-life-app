// ─────────────────────────────────────────────────────────────────────────────
// Deep-link route table (Task B2 — push notifications).
//
// Single source of truth for the `sunnahlife://` scheme used in push message
// data. The Flutter app mirrors these strings in
// apps/mobile/lib/core/deep_links.dart and maps them to go_router paths
// (deepLinkToRoute) — keep both tables in sync (mobile has a unit test on
// the mapping).
//
// FCM `data` values MUST be plain strings, so the payload always carries the
// rendered URI (e.g. "sunnahlife://live/abc123"), never this object.
// ─────────────────────────────────────────────────────────────────────────────

export const DEEP_LINK_SCHEME = "sunnahlife";

/** Canonical deep links (rendered as `sunnahlife://<path>`). */
export const DEEP_LINKS = {
  /** Home dashboard (prayer times). */
  home: "sunnahlife://home",
  /** Amal diary — today's sheet. */
  amal: "sunnahlife://amal",
  /** Amal month heatmap. */
  amalMonth: "sunnahlife://amal/month",
  /** Dawah tab (member identity, usrah, review queue). */
  dawah: "sunnahlife://dawah",
  /** Weekly-review flow inside the Dawah tab. */
  reviews: "sunnahlife://reviews",
  /** Usrah announcements (Dawah tab → usrah card). */
  usrah: "sunnahlife://usrah",
  /** Live programs list. */
  live: "sunnahlife://live",
  /** A single live program (deep link id). */
  liveProgram: (id: string) => `sunnahlife://live/${id}`,
  /** Quran reader. */
  quran: "sunnahlife://quran",
  /** More hub (profile, zakat, qibla, …). */
  more: "sunnahlife://more",
  /** Monthly Muhasaba report (More hub). */
  report: "sunnahlife://report",
} as const;

export type DeepLinkKey = keyof typeof DEEP_LINKS;

/** Build the FCM `data` payload for a deep link (string-only values). */
export function deepLinkData(
  link: string,
  extra?: Record<string, string>
): Record<string, string> {
  return { deepLink: link, ...(extra ?? {}) };
}
