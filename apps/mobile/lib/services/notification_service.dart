/// Notification orchestration — flutter_local_notifications for waqt bells
/// and post-prayer prompts.
///
/// PUSH SEAM (documented for the push-delivery phase): FCM is NOT in this
/// round. Every push-related call site goes through [PushAdapter]; the
/// production FCM adapter is a drop-in swap behind [kFcmEnabled] and does NOT
/// change any call site. Do not call Firebase APIs outside this seam.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Flip to true when firebase_messaging lands in the push-delivery phase and
/// provide a real adapter — nothing else in the app changes.
const bool kFcmEnabled = false;

/// The push delivery seam. The local adapter is a no-op by design.
abstract class PushAdapter {
  Future<void> register({required void Function(String token) onToken});
  Future<void> show({required String title, required String body});
}

class _LocalOnlyPushAdapter implements PushAdapter {
  @override
  Future<void> register({required void Function(String token) onToken}) async {}
  @override
  Future<void> show({required String title, required String body}) async {}
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// The push adapter seam (FCM later, local no-op now).
  final PushAdapter push = _LocalOnlyPushAdapter();

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

  /// Immediate local notification.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channel = 'sunnah_life_general',
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
      payload: 'local',
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
