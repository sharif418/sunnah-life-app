/// FCM push integration (Task B2) — the concrete adapter behind the
/// documented PushAdapter seam in notification_service.dart.
///
/// Lifecycle:
///   ensureInitialized()   — Firebase.initializeApp + message handlers
///                           (foreground → flutter_local_notifications via
///                           NotificationService; taps → deep-link navigation
///                           through [deepLinkToRoute] + go_router).
///   syncRegistration()    — called on every auth flip: requests permission
///                           (alert/badge/sound) when signed in, registers
///                           the FCM token with POST /api/push/token and
///                           re-registers on token refresh; signs the token
///                           out (DELETE) when the session ends.
///
/// Failure is always graceful: with placeholder firebase_options.dart (CI
/// builds) or without Play Services, Firebase throws — caught, push disabled,
/// local notifications keep working untouched.
library;

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../core/deep_links.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

/// `flutter test` sets FLUTTER_TEST=true in the process environment.
///
/// firebase_core's platform-channel calls NEVER RESOLVE under the test binding
/// (neither a value nor a MissingPluginException — the future just hangs), so
/// awaiting Firebase.initializeApp there would freeze the bootstrap splash
/// forever (found via smoke_test: 0 NavigationBar). Tests therefore skip
/// Firebase entirely; local notifications keep working unmocked.
bool get _runningInFlutterTest =>
    !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

/// Background/isolate handler — MUST be top-level. Notification-payload
/// messages are displayed by the system tray itself; the server always
/// sends notification payloads, so nothing is done here (kept for data-only
/// future use).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[push] background message ${message.messageId}');
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  FirebaseMessaging? _messaging;
  bool _initialized = false;
  bool _listeningRefresh = false;
  String? _currentToken;
  ApiClient? _api;

  /// Route navigation callback (go_router.go) — set by the bootstrap provider.
  void Function(String route)? _onNavigate;

  bool get enabled => _messaging != null;

  /// Initialize Firebase + handlers once. [onNavigate] receives a sanitized
  /// in-app route (already mapped from the sunnahlife:// deep link).
  Future<void> ensureInitialized({
    required void Function(String route) onNavigate,
  }) async {
    if (_initialized) return;
    _initialized = true; // never retry within a session — failure is final
    _onNavigate = onNavigate;

    if (_runningInFlutterTest) {
      debugPrint('[push] test environment — Firebase skipped');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('[push] Firebase unavailable — local notifications only: $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      // Background/isolate data messages (top-level handler — required by
      // the plugin; notification-payload messages are shown by the system).
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground: FCM does NOT display notifications itself on Android —
      // show them through the existing local-notification machinery so the
      // app keeps ONE channel ("sunnah_life_push") and ONE tap path.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Background tap → deep link.
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

      // Terminated-state launch from a notification tap.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFromMessage(initial, delay: true);

      // Local-notification taps (foreground messages are local
      // notifications; prayer bells route through the same callback).
      NotificationService.instance.onNotificationTap = _handlePayload;
    } catch (e) {
      debugPrint('[push] handler setup failed (push disabled): $e');
      _messaging = null;
    }
  }

  /// Register/unregister the device token with the API as the session
  /// changes. Called from the auth-state listener in app.dart.
  Future<void> syncRegistration({
    required ApiClient api,
    required bool signedIn,
  }) async {
    final messaging = _messaging;
    if (messaging == null) return;
    _api = api;

    if (!signedIn) {
      await _unregister(api);
      return;
    }

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok) return;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(api, token);

      // FCM rotates tokens (app update, invalidation) — keep the server row
      // fresh. One listener per process.
      if (!_listeningRefresh) {
        _listeningRefresh = true;
        messaging.onTokenRefresh.listen((newToken) async {
          final api = _api;
          if (api != null && newToken.isNotEmpty) {
            await _registerToken(api, newToken);
          }
        });
      }
    } catch (e) {
      debugPrint('[push] registration failed: $e');
    }
  }

  Future<void> _registerToken(ApiClient api, String token) async {
    _currentToken = token;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await api.registerPushToken(token: token, platform: platform);
    } catch (e) {
      debugPrint('[push] token POST failed: $e');
    }
  }

  Future<void> _unregister(ApiClient api) async {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    _currentToken = null;
    try {
      await api.unregisterPushToken(token);
    } catch (_) {
      // offline sign-out is fine — the server prunes stale tokens anyway
    }
  }

  // ── message → screen ──────────────────────────────────────────────────────

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final deepLink = message.data['deepLink'] as String?;
    NotificationService.instance.showNow(
      id: message.messageId?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch,
      title: n.title ?? 'সুন্নাহ লাইফ',
      body: n.body ?? '',
      channel: 'sunnah_life_push',
      payload: deepLink ?? 'push',
    );
  }

  void _openFromMessage(RemoteMessage message, {bool delay = false}) {
    final link = message.data['deepLink'] as String?;
    if (link == null) return;
    _handlePayload(link, delay: delay);
  }

  void _handlePayload(String payload, {bool delay = false}) {
    final route = deepLinkToRoute(payload);
    if (route == null) return;
    if (delay) {
      // Terminated-launch: give the router a frame to mount.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _onNavigate?.call(route);
      });
    } else {
      _onNavigate?.call(route);
    }
  }
}
