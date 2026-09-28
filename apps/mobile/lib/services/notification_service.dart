/// Notification orchestration — flutter_local_notifications for waqt bells
/// and post-prayer prompts.
///
/// PUSH (B2): the FCM integration lives in services/push_service.dart
/// (firebase_messaging). It routes foreground messages through [showNow] on
/// this service's "sunnah_life_push" channel and taps through
/// [onNotificationTap], so local + push notifications share ONE surface.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/bell_schedule.dart';
import '../core/prayer_engine.dart';
import '../db/database.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Tap handler — set by PushService (B2). Receives the notification
  /// payload; push payloads carry the sunnahlife:// deep link, local ones
  /// ('local'/'prayer') are ignored by the mapper.
  void Function(String payload)? onNotificationTap;

  /// Foreground amal-action handler — set by the app bootstrap (app.dart):
  /// routes post-prayer জামাতে/একা/কাযা taps through the SAME Riverpod
  /// flow the in-app prompt uses (optimistic state + shared DB + sync
  /// flush). When null (app headless), the standalone background write in
  /// [handleAmalNotificationAction] covers it.
  Future<void> Function(String actionId, PostPrayerActionPayload payload)?
      onAmalAction;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _initLocalTimeZone();
    // Monochrome small icon for EVERY local notification (colored launcher
    // mipmaps render as a white square in the status bar).
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationResponse(response);
      },
      // Post-prayer action buttons tapped while the app is DEAD arrive
      // here, on the plugin's background isolate — the top-level handler
      // below writes the diary from a fresh Drift connection.
      onDidReceiveBackgroundNotificationResponse: amalActionBackgroundResponse,
    );
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Foreground taps: amal action buttons go through [onAmalAction] (the
  /// in-app Riverpod flow); everything else keeps the push deep-link path.
  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      final payload = PostPrayerActionPayload.decode(response.payload);
      if (payload != null && kAmalActionValues.containsKey(actionId)) {
        final hook = onAmalAction;
        if (hook != null) {
          hook(actionId, payload);
          return;
        }
        // No app wiring (e.g. very early tap) — the standalone write.
        handleAmalNotificationAction(
          actionId: actionId,
          payload: response.payload,
        );
        return;
      }
    }
    debugPrint('notification tap: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call(payload);
    }
  }

  /// zonedSchedule() interprets its trigger in [tz.local]; leaving it at the
  /// package default (UTC) shifts every bell by the city offset on a real
  /// device. The app's model assumes the device clock is in the city
  /// timezone, so the device zone is the correct [tz.local].
  Future<void> _initLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Plugin unavailable (tests, stubbed platforms) — fall back to the
      // app's home market so Bangladeshi devices stay correct.
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }
  }

  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidImpl?.requestNotificationsPermission() ?? true;
  }

  Future<void> _channel(String id, String name, Importance importance) async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(id, name, importance: importance),
    );
  }

  /// Immediate local notification. [payload] rides along to the tap
  /// handler — push messages pass their deep link here.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channel = 'sunnah_life_general',
    String payload = 'local',
  }) async {
    await _channel(channel, 'সুন্নাহ লাইফ', Importance.high);
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          'সুন্নাহ লাইফ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Zoned schedule — used for the per-waqt bell and the post-prayer
  /// prompt. [when] must be a future tz datetime in the city timezone.
  /// [actions] renders as the post-prayer জামাতে/একা/কাযা buttons.
  ///
  /// Android 12+/14 exact-alarm policy: SCHEDULE_EXACT_ALARM is denied by
  /// default, so query [AndroidFlutterLocalNotificationsPlugin
  /// .canScheduleExactAlarms] and fall back to inexact-allow-while-idle —
  /// a slightly-delayed bell beats a thrown exception (and the permission
  /// card on Home asks the user to upgrade it to exact).
  Future<void> zoned({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String channel = 'sunnah_life_prayers',
    DateTimeComponents? matchComponents,
    String payload = 'prayer',
    List<AndroidNotificationAction>? actions,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await _channel(channel, 'নামাজের সময়', Importance.high);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          'নামাজের সময়',
          importance: Importance.high,
          priority: Priority.high,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _resolveScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: payload,
    );
  }

  /// Exact when the OS granted SCHEDULE_EXACT_ALARM, inexact otherwise.
  /// Never throws — every failure path degrades to the inexact mode.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null &&
          await androidImpl.canScheduleExactNotifications() == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint('canScheduleExactAlarms probe failed: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

// ── Post-prayer diary actions (background-safe) ──────────────────────

/// Background-isolate entry point — flutter_local_notifications invokes
/// this when a post-prayer action button is tapped while the app is not
/// running. MUST stay top-level with the vm:entry-point pragma.
@pragma('vm:entry-point')
Future<void> amalActionBackgroundResponse(NotificationResponse response) async {
  await handleAmalNotificationAction(
    actionId: response.actionId,
    payload: response.payload,
  );
}

/// Standalone diary write for a post-prayer action tap: decodes the
/// payload + action id, opens a FRESH Drift connection to the same sqlite
/// file (no Riverpod in a background isolate), writes the AmalEntry +
/// outbox row exactly like the in-app prompt (writeEntry does both), then
/// posts a small confirmation on the general channel. The outbox drains
/// through the 60s sync flush the next time the app is alive. Failure is
/// always swallowed — a broken button must never crash a headless app.
Future<void> handleAmalNotificationAction({
  required String? actionId,
  required String? payload,
}) async {
  try {
    final value = actionId == null ? null : kAmalActionValues[actionId];
    final data = PostPrayerActionPayload.decode(payload);
    if (value == null || data == null) return;

    final source = autoSourceFromAmalKey(data.amalKey) ?? 'manual';
    final db = AppDatabase();
    try {
      await db.writeEntry(
        amalKey: data.amalKey,
        date: data.dateKey,
        value: value,
        source: source,
        clientUpdatedAt: DateTime.now(),
      );
    } finally {
      try {
        await db.close();
      } catch (_) {}
    }

    // ছোট্ট কনফার্মেশন — "আমলনামায় দাখিল হয়েছে"।
    final waqtName = data.amalKey.startsWith('salat_')
        ? data.amalKey.substring(6)
        : '';
    PrayerKey? key;
    for (final k in PrayerKey.values) {
      if (k.name == waqtName) key = k;
    }
    final label = key == null
        ? data.amalKey
        : (prayerLabelsBn[key] ?? data.amalKey);
    await NotificationService.instance.showNow(
      id: key == null ? Nid.amalConfirmBase : Nid.amalConfirm(key),
      title: 'আমলনামায় দাখিল হয়েছে',
      body: '$label নামাজ — ${kAmalValueLabelsBn[value] ?? value} ✓',
    );
  } catch (e) {
    debugPrint('amal notification action failed: $e');
  }
}
