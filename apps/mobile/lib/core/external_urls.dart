/// External-URL opening (C-W3g): the donation link's launch policy.
///
/// The pure predicate [isLaunchableHttpUrl] is the decision function (unit
/// tested, no plugin); [openInAppBrowser] is the thin url_launcher wrapper
/// used by the zakat CTA and the More-tab "দান করুন" tile. Android's
/// LaunchMode.inAppBrowserView IS Chrome Custom Tabs (the PLAN's ask);
/// iOS gets SFSafariViewController.
library;

import 'package:url_launcher/url_launcher.dart';

/// May [url] be opened in a browser surface? http/https only — an empty
/// string, a scheme-less string and every other scheme (intent:,
/// javascript:, sunnahlife:, ftp:…) are rejected. Callers use this both to
/// gate the affordance (hidden when the config has no usable URL) and to
/// keep the launch call itself honest.
bool isLaunchableHttpUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// The website that belongs to an API base: production serves both from one
/// origin (https://sunnahlife.app), staging puts the API on an `api-` / `api.`
/// host beside the site (api-staging.example → staging.example).
String webBaseFor(String apiBase) {
  final uri = Uri.tryParse(apiBase.trim());
  if (uri == null || uri.host.isEmpty) return apiBase;
  var host = uri.host;
  if (host.startsWith('api-') || host.startsWith('api.')) host = host.substring(4);
  return '${uri.scheme}://$host';
}

/// Open [url] in the in-app browser view (Chrome Custom Tabs on Android,
/// SFSafariViewController on iOS) with the external browser as the fallback
/// when the in-app view throws (no Custom Tabs provider, WebView missing…).
///
/// Returns whether SOME browser surface opened; callers surface a friendly
/// message when this is false. Never throws.
Future<bool> openInAppBrowser(String url) async {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {
    // in-app view unavailable — fall through to the external browser
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The URL that plays a live program or its recording: the recording link
/// when there is one, else the YouTube video/stream id. Null when there is
/// nothing to play (the card then shows no watch button).
String? livePlaybackUrl({String? youtubeId, String? recordingUrl}) {
  final rec = recordingUrl?.trim() ?? '';
  if (isLaunchableHttpUrl(rec)) return rec;
  final id = youtubeId?.trim() ?? '';
  if (id.isEmpty) return null;
  // a full YouTube link pasted into the id field still plays
  if (isLaunchableHttpUrl(id)) return id;
  return 'https://www.youtube.com/watch?v=${Uri.encodeComponent(id)}';
}

/// Open [url] in the app that owns it (YouTube for a stream — the native
/// player is lighter on low-end phones than an embedded WebView), falling
/// back to the in-app browser. Never throws.
Future<bool> openExternalApp(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {
    // no handler — fall through to a browser surface
  }
  return openInAppBrowser(url);
}

/// Walking/driving directions to a point in Google Maps (the app when
/// installed, the browser otherwise). Pure — unit tested.
String mapsDirectionsUrl(double lat, double lng) =>
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

/// "Mosques near here" in Google Maps — finds the ones the bundled pack
/// does not list. Pure — unit tested.
String mapsNearbySearchUrl(String query, double lat, double lng) =>
    'https://www.google.com/maps/search/${Uri.encodeComponent(query)}/@$lat,$lng,14z';
