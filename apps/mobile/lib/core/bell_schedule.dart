/// Pure prayer-bell scheduling logic — the deterministic notification-ID
/// scheme for the rolling multi-day window, per-waqt minute preferences,
/// the post-prayer action payload codec, and the profile-change
/// reschedule trigger.
///
/// Everything here is side-effect free (no plugins, no Riverpod) and
/// unit-tested in test/bell_schedule_test.dart; the impure engine that
/// talks to flutter_local_notifications / SharedPreferences lives in
/// services/prayer_bell_scheduler.dart.
library;

import 'dart:convert';

import '../models/domain.dart';
import 'date_keys.dart';
import 'prayer_engine.dart';

/// Rolling scheduling window: today + tomorrow + the day after. The daily
/// WorkManager re-arm + the boot receiver keep at least this much pending,
/// so bells survive 2+ days without the app being opened.
const int kRollingWindowDays = 3;

// ── Notification IDs ────────────────────────────────────────────────────────
//
// Stable, so re-scheduling with the same id REPLACES and never duplicates.
//
//   bell        = 1000 + dayOffset * 16 + PrayerKey.index   (1000..1032)
//   post-prayer = 2000 + dayOffset * 16 + PrayerKey.index   (2000..2032)
//   exact alarm =  900 + PrayerKey.index (Kotlin AlarmManager path, unchanged)
//   silent on   = 4000 + dayOffset * 16 + PrayerKey.index   (Kotlin ringer)
//   silent off  = 5000 + dayOffset * 16 + PrayerKey.index   (Kotlin ringer)
//   detox       = 6000 (W4d — the single daily screen-time reminder)
//
// The day stride is 16 because max PrayerKey.index is tahajjud = 9 < 16:
// the five farz slots of one day can never bleed into the next day's
// block. Day-offset 0 reuses the historical single-day ids (1000+idx /
// 2000+idx), so devices upgrading from the 1-day schedule replace their
// existing alarms in place. The families stay disjoint from each other, the
// 900-exact block, the push/foreground ids (< 900) and the 3000-confirms.
// The auto-silent ids are AlarmManager PendingIntent request codes (not
// notification ids) but live in the same scheme so the whole scheduling
// surface stays collision-free in one place.

abstract final class Nid {
  static const int waqtBellBase = 1000; // + dayOffset*16 + PrayerKey.index
  static const int postPrayerBase = 2000; // + dayOffset*16 + PrayerKey.index
  static const int exactAlarmBase = 900; // + PrayerKey.index (Kotlin path)
  static const int amalConfirmBase =
      3000; // + PrayerKey.index (diary-write ack)
  static const int autoSilentOnBase = 4000; // + dayOffset*16 + PrayerKey.index
  static const int autoSilentOffBase = 5000; // + dayOffset*16 + PrayerKey.index

  /// The single daily screen-time reminder (W4d Guard-module seed) —
  /// zonedSchedule with DateTimeComponents.time, replaced in place on
  /// every toggle/time change.
  static const int detoxReminder = 6000;

  /// The weekly guest sign-up reminder (Friday 10:00, repeating) —
  /// cancelled the moment the user signs in.
  static const int guestNudge = 6100;

  static const int _dayStride = 16;

  /// Bell notification id for [key] on the day [dayOffset] days from today.
  static int bell(int dayOffset, PrayerKey key) =>
      waqtBellBase + dayOffset * _dayStride + key.index;

  /// Post-prayer prompt id for [key] on the day [dayOffset] days from today.
  static int postPrayer(int dayOffset, PrayerKey key) =>
      postPrayerBase + dayOffset * _dayStride + key.index;

  /// Exact-alarm (Kotlin AlarmManager) id for [key].
  static int exactAlarm(PrayerKey key) => exactAlarmBase + key.index;

  /// Ringer-silence alarm id for [key] on [dayOffset] (Kotlin AlarmManager →
  /// AutoSilentReceiver, fires setAutoSilent(true) at the waqt start).
  static int autoSilentOn(int dayOffset, PrayerKey key) =>
      autoSilentOnBase + dayOffset * _dayStride + key.index;

  /// Ringer-restore alarm id for [key] on [dayOffset] (fires
  /// setAutoSilent(false) N minutes after the waqt start).
  static int autoSilentOff(int dayOffset, PrayerKey key) =>
      autoSilentOffBase + dayOffset * _dayStride + key.index;

  /// Every auto-silent id that can exist across the rolling window — the
  /// deterministic cancel set (feature off / profile change). Covers every
  /// slot of the stride, not just the farz indices, so the cancel stays
  /// correct even if the waqt set ever widens.
  static List<int> autoSilentAllIds() => [
    for (final base in [autoSilentOnBase, autoSilentOffBase])
      for (var offset = 0; offset < kRollingWindowDays; offset++)
        for (var slot = 0; slot < _dayStride; slot++)
          base + offset * _dayStride + slot,
  ];

  /// Confirmation id for a diary write triggered by the [key] prompt.
  static int amalConfirm(PrayerKey key) => amalConfirmBase + key.index;
}

/// The profile slice that feeds PrayerEngine.compute — any change to these
/// fields changes computed times and therefore forces a full reschedule
/// (city → lat/lng/tz, calculation method, madhhab). Name / language /
/// theme changes must NOT thrash the armed alarms.
class PrayerBellConfig {
  const PrayerBellConfig({
    required this.lat,
    required this.lng,
    required this.tz,
    required this.method,
    required this.madhhab,
  });

  final double lat;
  final double lng;
  final double tz;
  final CalcMethod method;
  final Madhhab madhhab;

  /// Reschedule trigger: two configs describe the same schedule iff their
  /// keys are equal (double + enum fields stringify losslessly here).
  String get scheduleKey => '$lat|$lng|$tz|${method.json}|${madhhab.json}';
}

/// DateKeys of the rolling window ([today], [today]+1, [today]+2).
List<String> rollingWindowDateKeys(String today) => [
  for (var i = 0; i < kRollingWindowDays; i++) addDays(today, i),
];

// ── Per-waqt minute preferences ──────────────────────────────────────────────
//
// Stored per waqt in SharedPreferences:
//   bellmin_<waqt> — bell lead time,  0–60  min (default 10)
//   postmin_<waqt> — prompt lag,      5–120 min (default 20)

const int kDefaultBellMinutes = 10;
const int kDefaultPostPrayerMinutes = 20;

String bellMinutesPrefKey(PrayerKey key) => 'bellmin_${key.name}';
String postPrayerMinutesPrefKey(PrayerKey key) => 'postmin_${key.name}';

/// Bell lead time in minutes; [stored] is the raw pref value (null when the
/// user never customized this waqt). Clamped to 0–60.
int bellMinutesFor(PrayerKey key, {int? stored}) =>
    _clampPref(stored, 0, 60, kDefaultBellMinutes);

/// Post-prayer prompt lag in minutes; [stored] is the raw pref value.
/// Clamped to 5–120.
int postPrayerMinutesFor(PrayerKey key, {int? stored}) =>
    _clampPref(stored, 5, 120, kDefaultPostPrayerMinutes);

int _clampPref(int? stored, int min, int max, int fallback) {
  if (stored == null) return fallback;
  if (stored < min) return min;
  if (stored > max) return max;
  return stored;
}

// ── Post-prayer action payload codec ─────────────────────────────────────────

/// Payload riding on the post-prayer notification so its action buttons can
/// write the diary from a headless background isolate (no Riverpod there):
/// `{"dateKey":"2026-02-08","amalKey":"salat_fajr"}`.
class PostPrayerActionPayload {
  const PostPrayerActionPayload({required this.dateKey, required this.amalKey});

  final String dateKey;
  final String amalKey;

  String encode() => jsonEncode({'dateKey': dateKey, 'amalKey': amalKey});

  /// Null on any malformed input — handlers treat null as "do nothing".
  static PostPrayerActionPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final date = decoded['dateKey'];
      final amalKey = decoded['amalKey'];
      if (date is! String ||
          amalKey is! String ||
          date.isEmpty ||
          amalKey.isEmpty) {
        return null;
      }
      return PostPrayerActionPayload(dateKey: date, amalKey: amalKey);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PostPrayerActionPayload &&
      other.dateKey == dateKey &&
      other.amalKey == amalKey;

  @override
  int get hashCode => Object.hash(dateKey, amalKey);
}

/// Notification action-button ids (AndroidNotificationAction.id) → tristate
/// amal value. জামাতে / একা / কাযা write the same strings the in-app
/// post-prayer prompt writes (amal_engine + the server catalog both key on
/// these exact literals).
const Map<String, String> kAmalActionValues = {
  'amal_jamaat': 'jamaat',
  'amal_ekai': 'alone',
  'amal_qaza': 'qaza',
};

/// Amal catalog key of a farz salah diary row (fallback_catalog:
/// salat_fajr … salat_isha).
String salatAmalKey(PrayerKey key) => 'salat_${key.name}';

/// Machine source of a salah diary write — matches the catalog's
/// autoSource for the five farz prayers and the server's AUTO_SOURCE_RE
/// allowlist (`^auto:[a-z]+(:[a-z0-9_]+)?$`).
String salatAutoSource(PrayerKey key) => 'auto:prayer:${key.name}';

/// [salatAutoSource] from a diary amalKey ('salat_fajr' →
/// 'auto:prayer:fajr'); null for non-salat keys (never written by bells).
String? autoSourceFromAmalKey(String amalKey) =>
    amalKey.startsWith('salat_') ? 'auto:prayer:${amalKey.substring(6)}' : null;

/// Bengali labels of the tristate values for the headless confirmation
/// notification (the notification layer is Bengali-first like every other
/// notification string; widgets go through l10n).
const Map<String, String> kAmalValueLabelsBn = {
  'jamaat': 'জামাতে',
  'alone': 'একা',
  'qaza': 'কাযা',
};
