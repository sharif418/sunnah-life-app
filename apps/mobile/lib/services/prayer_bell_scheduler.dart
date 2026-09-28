/// Rolling prayer-bell scheduling engine — the ONE implementation shared by
/// the app (Riverpod foreground path in state/prayer_state.dart) and the
/// background re-arm paths (daily WorkManager task, notification-action
/// isolate). Pure logic — deterministic ids, minute clamps, payloads —
/// lives in core/bell_schedule.dart + core/auto_silent.dart; this file owns
/// the plugin calls.
///
/// Scheduling model:
///  · bells + post-prayer prompts for TODAY and the next 2 days
///    (flutter_local_notifications zonedSchedule, ids from [Nid]);
///  · auto-silent jama'at windows for the same 3 days (Kotlin
///    AlarmManager ringer alarms via PrayerChannel, ids from [Nid]);
///  · idempotent per dateKey (Sets of already-armed days);
///  · a profile change (city / method / madhhab) cancels everything armed
///    and re-arms from scratch;
///  · one exact AlarmManager alarm for the NEXT farz waqt via the Kotlin
///    PrayerChannel (kept alongside the plugin path).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidNotificationAction;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/bn_digits.dart';
import '../core/auto_silent.dart';
import '../core/bell_schedule.dart';
import '../core/date_keys.dart';
import '../core/prayer_engine.dart';
import '../db/database.dart';
import '../models/domain.dart';
import 'notification_service.dart';
import 'platform_channels.dart';

class PrayerBellScheduler {
  PrayerBellScheduler._();

  /// dateKeys whose bells + prompts are already armed.
  static final Set<String> _armedDays = <String>{};

  /// dateKeys whose auto-silent windows are already armed (C-W3e — its own
  /// bookkeeping so bell toggles never thrash the ringer arms and
  /// vice-versa).
  static final Set<String> _armedSilentDays = <String>{};

  /// Every local-notification id we armed (for the clean cancel on
  /// settings change).
  static final Set<int> _armedIds = <int>{};

  /// Profile signature the current armed schedule was computed with.
  static String _armedScheduleKey = '';

  /// Cancel everything armed and forget the bookkeeping. Called when
  /// prayer-affecting settings change; the next [refresh] re-arms from
  /// scratch with the new times.
  static Future<void> reset() async {
    for (final id in _armedIds) {
      try {
        await NotificationService.instance.cancel(id);
      } catch (e) {
        debugPrint('bell cancel failed for $id: $e');
      }
    }
    for (final key in farzPrayers) {
      await PrayerChannel.cancelExactAlarm(Nid.exactAlarm(key));
    }
    await cancelAutoSilentWindows();
    // A mid-window profile change cancels the active window's restore edge
    // — clear our silence too (safe no-op when we didn't silence; the
    // Kotlin engaged-flag never clobbers a user's own DND).
    await PrayerChannel.setAutoSilent(false);
    _armedIds.clear();
    _armedDays.clear();
    _armedScheduleKey = '';
  }

  /// Force the next [refresh] to re-arm every day in the window (used after
  /// a bell toggle or a per-waqt minute change — ids are stable, so
  /// re-scheduling replaces in place).
  static void forceReschedule() => _armedDays.clear();

  /// Same for the auto-silent windows (settings change / re-enable).
  static void forceSilentReschedule() => _armedSilentDays.clear();

  /// Cancel every pending auto-silent alarm and forget the bookkeeping.
  /// Called when the feature is turned off (also restores the ringer —
  /// see the settings screen) and from [reset] (profile change).
  static Future<void> cancelAutoSilentWindows() async {
    await PrayerChannel.cancelAutoSilent(Nid.autoSilentAllIds());
    _armedSilentDays.clear();
  }

  /// Cancel the armed bells of one waqt across the window (bell disabled).
  static Future<void> disableBell(PrayerKey key) async {
    for (var offset = 0; offset < kRollingWindowDays; offset++) {
      final id = Nid.bell(offset, key);
      _armedIds.remove(id);
      try {
        await NotificationService.instance.cancel(id);
      } catch (_) {}
    }
  }

  /// (Re)arm the rolling window. Idempotent per dateKey: days already
  /// armed under the same profile are skipped, so the once-per-minute
  /// ticker, the resume hook and the daily background task can all call
  /// this cheaply.
  static Future<void> refresh(
    PrayerBellConfig config, {
    DateTime? now,
  }) async {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      // Plugin unavailable (tests / stubbed platforms) — nothing to arm.
      debugPrint('notification init failed: $e');
      return;
    }

    now ??= DateTime.now();
    final today = dateKey(now);
    // Yesterday's bookkeeping is stale — its notifications already fired.
    _armedDays.removeWhere((d) => d.compareTo(today) < 0);

    // City / madhhab / method change → the armed schedule is wrong.
    if (_armedScheduleKey.isNotEmpty &&
        _armedScheduleKey != config.scheduleKey) {
      await reset();
    }
    _armedScheduleKey = config.scheduleKey;

    final prefs = await SharedPreferences.getInstance();
    final bells = <String>{
      for (final k in prefs.getKeys())
        if (k.startsWith('bell_') && prefs.getString(k) == '1') k.substring(5),
    };

    PrayerTimesBundle? todayTimes;
    for (var offset = 0; offset < kRollingWindowDays; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final dayKey = dateKey(day);
      if (_armedDays.contains(dayKey)) continue;
      final times = PrayerEngine.compute(
        dayKey,
        lat: config.lat,
        lng: config.lng,
        tz: config.tz,
        method: config.method,
        madhhab: config.madhhab,
      );
      if (offset == 0) todayTimes = times;

      for (final key in farzPrayers) {
        final minutes = times.byKey(key);
        final waqtAt = DateTime(
          day.year,
          day.month,
          day.day,
          minutes ~/ 60,
          (minutes % 60).round(),
        );

        if (bells.contains(key.name) && waqtAt.isAfter(now)) {
          final lead = bellMinutesFor(
            key,
            stored: prefs.getInt(bellMinutesPrefKey(key)),
          );
          final bellAt = waqtAt.subtract(Duration(minutes: lead));
          if (bellAt.isAfter(now)) {
            final id = Nid.bell(offset, key);
            final label = prayerLabelsBn[key] ?? key.name;
            await NotificationService.instance.zoned(
              id: id,
              title: '$label — ওয়াক্ত হচ্ছে',
              body: lead == 0
                  ? 'এখনই $label-এর সময় হবে — প্রস্তুত হোন'
                  : '${toBn(lead)} মিনিট পরে $label-এর সময় হবে — প্রস্তুত হোন',
              when: bellAt,
            );
            _armedIds.add(id);
          }
        }

        final lag = postPrayerMinutesFor(
          key,
          stored: prefs.getInt(postPrayerMinutesPrefKey(key)),
        );
        final promptAt = waqtAt.add(Duration(minutes: lag));
        if (promptAt.isAfter(now)) {
          final id = Nid.postPrayer(offset, key);
          await NotificationService.instance.zoned(
            id: id,
            title: '${prayerLabelsBn[key]} — জামাতে / একা / কাযা?',
            body: 'নামাজ হয়ে গেলে আমলনামায় লিখে ফেলুন',
            when: promptAt,
            payload: PostPrayerActionPayload(
              dateKey: dayKey,
              amalKey: salatAmalKey(key),
            ).encode(),
            // Diary write buttons — tapped from the notification without
            // opening the app; handled by the background isolate (see
            // amalActionBackgroundResponse in notification_service.dart).
            actions: [
              const AndroidNotificationAction(
                'amal_jamaat',
                'জামাতে',
              ),
              const AndroidNotificationAction('amal_ekai', 'একা'),
              const AndroidNotificationAction('amal_qaza', 'কাযা'),
            ],
          );
          _armedIds.add(id);
        }
      }
      _armedDays.add(dayKey);
    }

    // Exact alarm for the upcoming farz waqt (Kotlin AlarmManager — the
    // dedicated high-priority path; the plugin bells above carry the
    // inexact fallback for the Android 14 permission-denied case).
    final times = todayTimes;
    if (times != null) {
      final nowMinutes = now.hour * 60.0 + now.minute + now.second / 60.0;
      final (nextKey, _) = PrayerEngine.nextPrayer(times, nowMinutes);
      final minutes = times.byKey(nextKey);
      final nextAt = DateTime(
        now.year,
        now.month,
        now.day,
        minutes ~/ 60,
        (minutes % 60).round(),
      );
      if (nextAt.isAfter(now)) {
        await PrayerChannel.scheduleExactAlarm(
          id: Nid.exactAlarm(nextKey),
          epochMillis: nextAt.millisecondsSinceEpoch,
          title: '${prayerLabelsBn[nextKey]} — ওয়াক্ত',
          body: '${prayerLabelsBn[nextKey]}-এর সময় হয়েছে',
        );
      }
    }

    // Auto-silent jama'at windows (C-W3e) — parallel to the bells, same
    // rolling-window triggers, own idempotency per dateKey.
    await _scheduleAutoSilentWindows(config, now);
  }

  /// Arm the auto-silent windows for the rolling window (idempotent per
  /// dateKey via [_armedSilentDays]). Skips everything when the feature is
  /// off or the OS has not granted DND access — the settings screen owns
  /// the cancel+restore path for those cases.
  static Future<void> _scheduleAutoSilentWindows(
    PrayerBellConfig config,
    DateTime now,
  ) async {
    final today = dateKey(now);
    // Yesterday's bookkeeping is stale — its alarms already fired.
    _armedSilentDays.removeWhere((d) => d.compareTo(today) < 0);

    final prefs = await SharedPreferences.getInstance();
    final settings = AutoSilentPrefs.fromStorage(
      boolAt: prefs.getBool,
      intAt: prefs.getInt,
    );
    if (!settings.enabled) return;

    // The receiver re-checks the grant at fire time; skipping the arming
    // here just avoids useless pending alarms (and one channel call per
    // refresh). In a background WorkManager engine the probe is a no-op
    // (missing channel handler) — the foreground refresh re-arms on the
    // next app open (documented honest edge).
    final granted = await PrayerChannel.isDndGranted();
    if (!granted) return;

    PrayerTimesBundle computeFor(String dayKey) => PrayerEngine.compute(
          dayKey,
          lat: config.lat,
          lng: config.lng,
          tz: config.tz,
          method: config.method,
          madhhab: config.madhhab,
        );

    for (var offset = 0; offset < kRollingWindowDays; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final dayKey = dateKey(day);
      if (_armedSilentDays.contains(dayKey)) continue;
      for (final arm in autoSilentArmsForDay(
        dayKey: dayKey,
        times: computeFor(dayKey),
        waqts: settings.waqts,
        minutes: settings.minutes,
        dayOffset: offset,
        now: now,
      )) {
        await PrayerChannel.scheduleAutoSilent(
          id: arm.id,
          epochMillis: arm.at.millisecondsSinceEpoch,
          on: arm.on,
        );
      }
      _armedSilentDays.add(dayKey);
    }
  }
}

/// Background-safe refresh — reads the profile from the local Drift
/// database (the persisted GuestProfile row is the source of truth) and
/// arms the rolling window. Used by the daily WorkManager task and any
/// other headless path where no Riverpod container exists. adhan_dart is
/// pure Dart, so the computation is isolate-safe.
Future<void> refreshPrayerBellsFromDb() async {
  final db = AppDatabase();
  try {
    final row = await db.guestProfile();
    await PrayerBellScheduler.refresh(
      PrayerBellConfig(
        lat: row.lat,
        lng: row.lng,
        tz: row.tz,
        method: CalcMethodJson.fromJson(row.method),
        madhhab: MadhhabJson.fromJson(row.madhhab),
      ),
    );
  } catch (e) {
    debugPrint('background bell refresh failed: $e');
  } finally {
    try {
      await db.close();
    } catch (_) {}
  }
}

/// WorkManager dispatcher — the unique daily periodic task
/// `prayer-bell-refresh` re-arms the rolling window from the persisted
/// profile so bells stay pending for days even when the app is never
/// opened. MUST stay top-level with the vm:entry-point pragma; a task
/// failure returns false so WorkManager retries with backoff.
@pragma('vm:entry-point')
void prayerBellCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('workmanager task: $task');
    try {
      await refreshPrayerBellsFromDb();
      return true;
    } catch (e) {
      debugPrint('workmanager task failed: $e');
      return false;
    }
  });
}
