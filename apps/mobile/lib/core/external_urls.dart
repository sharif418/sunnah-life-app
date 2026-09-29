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
