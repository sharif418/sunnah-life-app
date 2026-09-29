/// Platform channels — Kotlin implements the real behaviour on Android;
/// iOS Swift stubs no-op with TODO-noted entitlements (no macOS here).
///
///  · sunnahlife/prayer — (a) exact alarms (AlarmManager.setExactAndAllowWhileIdle
///    + canScheduleExactAlarms + ACTION_REQUEST_SCHEDULE_EXACT_ALARM),
///    (b) DND/auto-silent (NotificationManager.setInterruptionFilter).
///  · sunnahlife/widget — home-widget text updates (RemoteViews).
///  · sunnahlife/system — share sheet (ACTION_SEND) without a plugin.
///  · sunnahlife/usage — UsageStatsManager screen-time (Guard-module
///    detox seed, W4d): permission probe + today's totals.
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

  /// Arm one auto-silent ringer alarm (Kotlin AlarmManager →
  /// AutoSilentReceiver). [id] is the deterministic request code
  /// ([Nid.autoSilentOn]/[Nid.autoSilentOff]); [on] flips the ringer to
  /// priority-only at [epochMillis], false restores it. Returns false when
  /// the platform can't (iOS stub / tests).
  static Future<bool> scheduleAutoSilent({
    required int id,
    required int epochMillis,
    required bool on,
  }) async {
    try {
      return await _ch.invokeMethod<bool>('scheduleAutoSilent', {
            'id': id,
            'epochMillis': epochMillis,
            'on': on,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Cancel the armed auto-silent alarms by id (the deterministic full set
  /// from [Nid.autoSilentAllIds] — one call, ids are Dart-owned).
  static Future<void> cancelAutoSilent(List<int> ids) async {
    try {
      await _ch.invokeMethod<void>('cancelAutoSilent', {'ids': ids});
    } on PlatformException {
      // ignore — best effort
    } on MissingPluginException {
      // iOS stub / tests
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

/// One app row of today's screen-time report (label resolved via the
/// PackageManager — falls back to the package name when unavailable).
class UsageApp {
  const UsageApp({required this.label, required this.minutes});
  final String label;
  final int minutes;
}

/// Today's UsageStats snapshot (W4d Guard-module seed): total foreground
/// minutes + the top apps (the list excludes the app itself).
class UsageToday {
  const UsageToday({required this.totalMinutes, required this.apps});
  final int totalMinutes;
  final List<UsageApp> apps;
}

/// sunnahlife/usage — Android UsageStatsManager reads for the social-media
/// detox screen. iOS/desktop/tests have no handler: [hasPermission] returns
/// null there so the UI can render its "supported on Android only" state.
class UsageChannel {
  const UsageChannel._();

  static const MethodChannel _ch = MethodChannel('sunnahlife/usage');

  /// Usage-access (AppOps) state: true = granted, false = denied,
  /// null = no platform handler (iOS / desktop / tests).
  static Future<bool?> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission');
    } on MissingPluginException {
      return null; // unsupported platform — the screen shows Android-only
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system "apps with usage access" screen. Returns whether an
  /// intent was actually fired.
  static Future<bool> openSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Today's screen-time report. Null when the platform has no handler OR
  /// usage access is missing — the caller decides which (via
  /// [hasPermission] first).
  static Future<UsageToday?> todayStats() async {
    try {
      final raw = await _ch.invokeMethod<Map>('todayStats');
      if (raw == null) return null;
      return UsageToday(
        totalMinutes: (raw['totalMinutes'] as num?)?.toInt() ?? 0,
        apps: ((raw['apps'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (e) => UsageApp(
                label: e['label'] as String? ?? '',
                minutes: (e['minutes'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
