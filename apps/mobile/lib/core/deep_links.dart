/// Deep-link route table (Task B2 — push notifications).
///
/// Mirrors apps/api/src/push/deep-links.ts (the server embeds these into
/// FCM `data.deepLink`). KEEP BOTH TABLES IN SYNC — test/deep_links_test.dart
/// asserts the mapping behavior.
///
/// [deepLinkToRoute] converts a `sunnahlife://…` URI into the in-app
/// go_router path (the app's routes are plain paths, not scheme-URIs).
library;

/// The custom URL scheme the app owns (Android intent-filter + iOS
/// CFBundleURLTypes both register it).
const String kSunnahDeepLinkScheme = 'sunnahlife';

/// Known deep-link URIs — MUST match DEEP_LINKS in apps/api/src/push/deep-links.ts.
abstract final class DeepLinks {
  static const String home = 'sunnahlife://home';
  static const String amal = 'sunnahlife://amal';
  static const String amalMonth = 'sunnahlife://amal/month';
  static const String dawah = 'sunnahlife://dawah';
  static const String reviews = 'sunnahlife://reviews';
  static const String usrah = 'sunnahlife://usrah';
  static const String live = 'sunnahlife://live';
  static const String quran = 'sunnahlife://quran';
  static const String more = 'sunnahlife://more';
  static const String report = 'sunnahlife://report';

  /// A single live program (id from the API).
  static String liveProgram(String id) => 'sunnahlife://live/$id';
}

/// Map a push deep link (or in-app notification payload) to the go_router
/// path. Unknown/foreign links → `null` (the caller ignores them).
String? deepLinkToRoute(String? link) {
  if (link == null || link.isEmpty) return null;
  final uri = Uri.tryParse(link);
  if (uri == null) return null;

  // Already a router path (in-app payloads use plain paths).
  if (uri.hasScheme && uri.scheme != kSunnahDeepLinkScheme) return null;
  if (!uri.hasScheme) return _sanitizePath(uri.path);

  // sunnahlife://home        → host = "home",      path = ""
  // sunnahlife://amal/month  → host = "amal",      path = "/month"
  // sunnahlife://live/abc    → host = "live",      path = "/abc"
  final path = (uri.host.isEmpty ? '' : uri.host) + uri.path;
  switch (path) {
    case 'home':
      return '/';
    case 'amal':
      return '/amal';
    case 'amal/month':
      return '/amal/month';
    case 'dawah':
      return '/dawah';
    // Weekly reviews + usrah announcements both live in the Dawah tab.
    case 'reviews':
    case 'usrah':
      return '/dawah';
    case 'live':
      return '/more/live';
    case 'quran':
      return '/ilm/quran';
    case 'more':
      return '/more';
    case 'report':
      return '/more';
    default:
      // sunnahlife://live/{id} → the live list (no per-id route yet).
      if (path.startsWith('live/')) return '/more/live';
      return _sanitizePath(path);
  }
}

/// Whitelisted in-app paths only (never let a push navigate arbitrarily).
String? _sanitizePath(String raw) {
  final path = raw;
  if (path.isEmpty || !path.startsWith('/')) return null;
  const allowed = <String>[
    '/amal',
    '/dawah',
    '/ilm',
    '/more',
  ];
  for (final base in allowed) {
    if (path == base || path.startsWith('$base/')) return path;
  }
  return null;
}
