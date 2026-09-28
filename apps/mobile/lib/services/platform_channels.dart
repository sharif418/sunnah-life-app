/// Platform channels — Kotlin implements the real behaviour on Android;
/// iOS Swift stubs no-op with TODO-noted entitlements (no macOS here).
///
///  · sunnahlife/prayer — (a) exact alarms (AlarmManager.setExactAndAllowWhileIdle
///    + canScheduleExactAlarms + ACTION_REQUEST_SCHEDULE_EXACT_ALARM),
///    (b) DND/auto-silent (NotificationManager.setInterruptionFilter).
///  · sunnahlife/widget — home-widget text updates (RemoteViews).
///  · sunnahlife/system — share sheet (ACTION_SEND) without a plugin.
library;

import 'package:flutter/services.dart';

class PrayerChannel {
  const PrayerChannel._();

  static const MethodChannel _ch = MethodChannel('sunnahlife/prayer');

  /// Schedule an exact alarm. Returns false when the OS denied exact alarms.
  static Future<bool> scheduleExactAlarm({
    required int id,
    required int epochMillis,
    required String title,
    required String body,
  }) async {
    try {
      final ok = await _ch.invokeMethod<bool>('scheduleExactAlarm', {
        'id': id,
        'epochMillis': epochMillis,
        'title': title,
        'body': body,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false; // iOS stub / tests
    }
  }

  static Future<void> cancelExactAlarm(int id) async {
    try {
      await _ch.invokeMethod<void>('cancelExactAlarm', {'id': id});
    } on PlatformException {
      // ignore — best effort
    } on MissingPluginException {
      // iOS stub / tests
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      return await _ch.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system "allow exact alarms" screen. Returns false if already
  /// granted (nothing to open).
  static Future<bool> requestExactAlarmPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestExactAlarmPermission') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isDndGranted() async {
    try {
      return await _ch.invokeMethod<bool>('isDndGranted') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the DND access settings screen so the user can grant it.
  static Future<bool> requestDndAccess() async {
    try {
      return await _ch.invokeMethod<bool>('requestDndAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Auto-silent during prayer windows (priority-only). Returns false when
  /// permission is missing.
  static Future<bool> setAutoSilent(bool enabled) async {
    try {
      return await _ch.invokeMethod<bool>('setAutoSilent', {
            'enabled': enabled,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class WidgetChannel {
  const WidgetChannel._();

  static const MethodChannel _ch = MethodChannel('sunnahlife/widget');

  /// Push next-prayer name + countdown to the Android home widget.
  static Future<void> updateNextPrayer({
    required String prayerName,
    required String countdown,
  }) async {
    try {
      await _ch.invokeMethod<void>('updateNextPrayer', {
        'prayerName': prayerName,
        'countdown': countdown,
      });
    } on PlatformException {
      // ignore — widget optional
    } on MissingPluginException {
      // iOS stub / tests
    }
  }
}

class SystemChannel {
  const SystemChannel._();

  static const MethodChannel _ch = MethodChannel('sunnahlife/system');

  /// Native share sheet (Android ACTION_SEND) — zero plugins.
  static Future<void> shareText(String text) async {
    try {
      await _ch.invokeMethod<void>('shareText', {'text': text});
    } on MissingPluginException {
      // Web/desktop/test fallback: the UI layer also copies to clipboard.
    } on PlatformException {
      // ignore
    }
  }
}
