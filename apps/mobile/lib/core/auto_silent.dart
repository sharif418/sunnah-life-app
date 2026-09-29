/// Pure auto-silent logic (C-W3e) — the jama'at silent-window computation,
/// the SharedPreferences codec and the scheduling state machine. No plugins,
/// no Riverpod; the impure engine that arms the Kotlin alarms lives in
/// services/prayer_bell_scheduler.dart, unit tests in
/// test/auto_silent_test.dart.
///
/// Model: when the master switch is on AND the OS granted DND access, each
/// enabled farz waqt gets a silent window — ringer flips to priority-only at
/// the waqt START and restores N minutes later (10–90, default 30). The
/// windows are armed on the same rolling 3-day window as the W3b bells and
/// re-arm through the same triggers (app start / resume / day rollover /
/// profile change / daily WorkManager task) — see
/// PrayerBellScheduler._scheduleAutoSilentWindows.
library;

import 'bell_schedule.dart';
import 'date_keys.dart';
import 'prayer_engine.dart';

// ── Minute preferences ───────────────────────────────────────────────────────
//
// Stored in SharedPreferences:
//   autosilent_enabled  — master switch (bool, default off)
//   autosilent_<waqt>   — per-waqt enable (bool, default ON for the 5 farz)
//   autosilent_min      — window length, 10–90 min (default 30)

const int kDefaultAutoSilentMinutes = 30;
const int kMinAutoSilentMinutes = 10;
const int kMaxAutoSilentMinutes = 90;

/// Master switch — nothing arms without this AND the DND grant.
const String autoSilentEnabledPrefKey = 'autosilent_enabled';

/// Per-waqt enable ('autosilent_fajr' … 'autosilent_isha'; default on).
String autoSilentWaqtPrefKey(PrayerKey key) => 'autosilent_${key.name}';

/// Silent-window length in minutes.
const String autoSilentMinutesPrefKey = 'autosilent_min';

/// Window length in minutes; [stored] is the raw pref value (null when the
/// user never customized it). Clamped to 10–90.
int autoSilentMinutesFor({int? stored}) {
  if (stored == null) return kDefaultAutoSilentMinutes;
  if (stored < kMinAutoSilentMinutes) return kMinAutoSilentMinutes;
  if (stored > kMaxAutoSilentMinutes) return kMaxAutoSilentMinutes;
  return stored;
}

// ── Settings codec ───────────────────────────────────────────────────────────

/// The persisted auto-silent settings, decoded. [waqts] only ever contains
/// farz prayers; an empty set with [enabled] true means "on, but no waqt
/// selected" → nothing arms (honest, no hidden defaults).
class AutoSilentPrefs {
  const AutoSilentPrefs({
    required this.enabled,
    required this.waqts,
    required this.minutes,
  });

  final bool enabled;
  final Set<PrayerKey> waqts;
  final int minutes;

  /// Decode from a key-value store. [boolAt]/[intAt] return null for absent
  /// keys (SharedPreferences semantics); defaults: master off, every farz
  /// waqt on, 30 minutes.
  factory AutoSilentPrefs.fromStorage({
    bool? Function(String key)? boolAt,
    int? Function(String key)? intAt,
  }) {
    return AutoSilentPrefs(
      enabled: boolAt?.call(autoSilentEnabledPrefKey) ?? false,
      waqts: {
        for (final k in farzPrayers)
          if (boolAt?.call(autoSilentWaqtPrefKey(k)) ?? true) k,
      },
      minutes: autoSilentMinutesFor(
        stored: intAt?.call(autoSilentMinutesPrefKey),
      ),
    );
  }
}

// ── Silent windows ───────────────────────────────────────────────────────────

/// One jama'at silent window: [start] is the waqt time, [end] is
/// start + [AutoSilentPrefs.minutes].
class AutoSilentWindow {
  const AutoSilentWindow({
    required this.key,
    required this.start,
    required this.end,
  });

  final PrayerKey key;
  final DateTime start;
  final DateTime end;
}

/// The silent windows of one day for the enabled waqts — start = waqt time,
/// end = start + [minutes]. Pure; no `now` filtering here.
List<AutoSilentWindow> autoSilentWindowsForDay({
  required String dayKey,
  required PrayerTimesBundle times,
  required Set<PrayerKey> waqts,
  required int minutes,
}) {
  final day = parseKey(dayKey);
  final windows = <AutoSilentWindow>[];
  for (final key in farzPrayers) {
    if (!waqts.contains(key)) continue;
    final m = times.byKey(key);
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      m ~/ 60,
      (m % 60).round(),
    );
    windows.add(
      AutoSilentWindow(
        key: key,
        start: start,
        end: start.add(Duration(minutes: minutes)),
      ),
    );
  }
  return windows;
}

/// One ringer alarm edge — [on] true flips the ringer to priority-only,
/// false restores it. [id] is the deterministic Kotlin AlarmManager request
/// code ([Nid.autoSilentOn]/[Nid.autoSilentOff]).
class AutoSilentArmEvent {
  const AutoSilentArmEvent({
    required this.id,
    required this.at,
    required this.on,
  });

  final int id;
  final DateTime at;
  final bool on;

  @override
  bool operator ==(Object other) =>
      other is AutoSilentArmEvent &&
      other.id == id &&
      other.at == at &&
      other.on == on;

  @override
  int get hashCode => Object.hash(id, at, on);
}

/// The alarm edges to arm for one day: on at the window start, off at the
/// window end — future edges only (a start already past is skipped; an end
/// still in the future arms alone so an active window always restores).
List<AutoSilentArmEvent> autoSilentArmsForDay({
  required String dayKey,
  required PrayerTimesBundle times,
  required Set<PrayerKey> waqts,
  required int minutes,
  required int dayOffset,
  required DateTime now,
}) {
  final clampedMinutes = autoSilentMinutesFor(stored: minutes);
  return [
    for (final w in autoSilentWindowsForDay(
      dayKey: dayKey,
      times: times,
      waqts: waqts,
      minutes: clampedMinutes,
    )) ...[
      if (w.start.isAfter(now))
        AutoSilentArmEvent(
          id: Nid.autoSilentOn(dayOffset, w.key),
          at: w.start,
          on: true,
        ),
      if (w.end.isAfter(now))
        AutoSilentArmEvent(
          id: Nid.autoSilentOff(dayOffset, w.key),
          at: w.end,
          on: false,
        ),
    ],
  ];
}

/// The scheduling state machine: given the persisted settings and whether the
/// OS granted DND access, the arms for the rolling window around [today].
/// Empty when the feature is off, the permission is missing or no waqt is
/// selected — the caller cancels the deterministic id space in that case
/// ([Nid.autoSilentAllIds]) so a mid-window disable also clears pending
/// edges. [compute] resolves one day's prayer times (injected so tests pass
/// fixed bundles; production passes PrayerEngine.compute with the profile).
List<AutoSilentArmEvent> autoSilentWindowArms({
  required AutoSilentPrefs prefs,
  required bool dndGranted,
  required String today,
  required PrayerTimesBundle Function(String dayKey) compute,
  required DateTime now,
}) {
  if (!prefs.enabled || !dndGranted) return const [];
  return [
    for (var offset = 0; offset < kRollingWindowDays; offset++)
      ...autoSilentArmsForDay(
        dayKey: addDays(today, offset),
        times: compute(addDays(today, offset)),
        waqts: prefs.waqts,
        minutes: prefs.minutes,
        dayOffset: offset,
        now: now,
      ),
  ];
}
