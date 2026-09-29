/// app_links wrapper (C-W3h) — incoming https://sunnahlife.app/join/* and
/// sunnahlife://join/* deep links, cold start + warm stream.
///
/// Mirrors PushService's lifecycle rules: never awaits a platform channel
/// under `flutter test` (the future would hang the bootstrap splash), never
/// retries within a session, and every failure is swallowed — a referral
/// link is an enhancement, never a boot dependency.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../core/deep_links.dart';

/// `flutter test` sets FLUTTER_TEST=true in the process environment.
bool get _runningInFlutterTest =>
    !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

class AppLinkService {
  AppLinkService._();
  static final AppLinkService instance = AppLinkService._();

  AppLinks? _appLinks;
  bool _started = false;
  StreamSubscription<Uri>? _sub;

  /// Start listening once. [onReferralCode] receives an already-VALIDATED
  /// member code (referralCodeFromLink) — the caller persists it as the
  /// pending referral. Non-join links are ignored here (push deep links
  /// route through deepLinkToRoute + PushService instead).
  ///
  /// Note: on Android the cold-start link can be delivered BOTH by
  /// getInitialLink() and the stream — the write is idempotent (same value),
  /// so no de-dup is needed.
  Future<void> ensureInitialized({
    required Future<void> Function(String code) onReferralCode,
  }) async {
    if (_started) return;
    _started = true; // never retry within a session — failure is final

    if (_runningInFlutterTest) {
      debugPrint('[app-links] test environment — plugin skipped');
      return;
    }

    try {
      _appLinks = AppLinks();
    } catch (e) {
      debugPrint('[app-links] unavailable: $e');
      return;
    }
    final links = _appLinks;
    if (links == null) return;

    // Cold start (app was launched by the link).
    try {
      final initial = await links.getInitialLink();
      final code = referralCodeFromLink(initial?.toString());
      if (code != null) await onReferralCode(code);
    } catch (e) {
      debugPrint('[app-links] initial link failed: $e');
    }

    // Warm (app resumed / already running).
    try {
      _sub = links.uriLinkStream.listen(
        (uri) async {
          final code = referralCodeFromLink(uri.toString());
          if (code != null) await onReferralCode(code);
        },
        onError: (Object e) => debugPrint('[app-links] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[app-links] stream listen failed: $e');
    }
  }

  /// Test/teardown hook.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
    _appLinks = null;
  }
}
