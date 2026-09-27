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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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

  /// Zoned schedule — used for the per-waqt bell and the 20-min post-prayer
  /// prompt. [when] must be a future tz datetime in the city timezone.
  Future<void> zoned({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String channel = 'sunnah_life_prayers',
    DateTimeComponents? matchComponents,
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: 'prayer',
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Notification IDs (stable, so re-scheduling replaces, never duplicates).
abstract final class Nid {
  static const int waqtBellBase = 1000; // + PrayerKey.index
  static const int postPrayerBase = 2000; // + PrayerKey.index
}
