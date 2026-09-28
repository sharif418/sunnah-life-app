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
        debugPrint('notification tap: ${response.payload}');
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    _initialized = true;
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

/// Notification IDs (stable, so re-scheduling replaces, never duplicates).
abstract final class Nid {
  static const int waqtBellBase = 1000; // + PrayerKey.index
  static const int postPrayerBase = 2000; // + PrayerKey.index
}
