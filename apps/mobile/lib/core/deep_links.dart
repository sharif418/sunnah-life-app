/// Deep-link route table (Task B2 — push notifications).
///
/// Mirrors apps/api/src/push/deep-links.ts (the server embeds these into
/// FCM `data.deepLink`). KEEP BOTH TABLES IN SYNC — test/deep_links_test.dart
/// asserts the mapping behavior.
///
/// [deepLinkToRoute] converts a `sunnahlife://…` URI into the in-app
/// go_router path (the app's routes are plain paths, not scheme-URIs).
/// [referralCodeFromLink] (C-W3h) extracts the referral member code from a
/// /join deep link — the one link shape that does NOT navigate but stores a
/// pending referral instead.
library;

/// The custom URL scheme the app owns (Android intent-filter + iOS
/// CFBundleURLTypes both register it).
const String kSunnahDeepLinkScheme = 'sunnahlife';

/// The https host the app owns (App Links verify against it —
/// apps/web/public/.well-known/assetlinks.json).
const String kSunnahDeepLinkHost = 'sunnahlife.app';

/// Member-code shape: DS-XXXXXX — see apps/api admin.controller.ts
/// nextMemberCode (six zero-padded digits, uppercase). Typed/tapped input
/// may arrive lowercase; compared case-insensitively and normalized to
/// upper. The `\d{6,}` floor rejects garbage without rejecting a grown
/// (7+ digit) code space.
final RegExp _memberCodeRe = RegExp(r'^ds-\d{6,}$', caseSensitive: false);

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

/// Extract the referral member code from a /join deep link (C-W3h).
///
/// Accepted shapes (both registered in the Android manifest; iOS handles
/// both via the URL scheme + associated domains):
///   · https://sunnahlife.app/join/DS-000123   (App Link, autoVerified)
///   · https://www.sunnahlife.app/join/DS-000123
///   · sunnahlife://join/DS-000123             (custom scheme)
///
/// Returns the normalized UPPERCASE code when the link is a /join link
/// AND the code matches the DS-XXXXXX member-code shape; null otherwise
/// (foreign hosts, other paths, missing/garbage codes, other schemes).
/// The caller stores the code as the pending referral (SharedPreferences
/// 'pending_referral') and surfaces it during onboarding/sign-in.
String? referralCodeFromLink(String? link) {
  if (link == null || link.isEmpty) return null;
  final uri = Uri.tryParse(link);
  if (uri == null || !uri.hasScheme) return null;

  final segments = _joinCodeSegments(uri);
  if (segments == null) return null;
  if (segments.length != 1) return null; // no code, or trailing junk
  final code = segments.single.toUpperCase();
  return _memberCodeRe.hasMatch(code) ? code : null;
}

/// The [CODE] path segment(s) of a /join link, or null when [uri] is not
/// one of our /join shapes. [referralCodeFromLink] does the shape check.
List<String>? _joinCodeSegments(Uri uri) {
  if (uri.scheme == kSunnahDeepLinkScheme) {
    // sunnahlife://join/CODE → host = "join", pathSegments = [CODE]
    if (uri.host != 'join') return null;
    return _withoutTrailingEmpty(uri.pathSegments);
  }
  if (uri.scheme != 'https') return null;
  if (uri.host != kSunnahDeepLinkHost &&
      uri.host != 'www.$kSunnahDeepLinkHost') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.isEmpty || segments.first != 'join') return null;
  return _withoutTrailingEmpty(segments.sublist(1));
}

/// A trailing slash (…/join/DS-000123/) yields one trailing empty segment —
/// tolerated once, anything else is junk.
List<String> _withoutTrailingEmpty(List<String> segments) =>
    segments.isNotEmpty && segments.last.isEmpty
        ? segments.sublist(0, segments.length - 1)
        : segments;
