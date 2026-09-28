/// Muhasaba engine — points, streaks, completion, locking rule.
/// Mirrors src/lib/server/amal.ts business rules so client previews match
/// the server's summaries exactly.
library;

import '../core/calendars.dart';
import '../core/date_keys.dart';
import 'prayer_engine.dart';
import '../models/domain.dart';

/// Points for one entry value against its definition:
/// 1 = complete, 0.5 = partial (below target), 0 = not done.
/// Tristate: জামাত/একা = 1, কাযা = 0. Boolean: true = 1.
double amalPoints(Object? value, AmalDefinition def, UserCategory category) {
  switch (def.inputType) {
    case AmalInputType.tristate:
      return value == 'jamaat' || value == 'alone' ? 1 : 0;
    case AmalInputType.boolean:
      return value == true ? 1 : 0;
    case AmalInputType.count:
    case AmalInputType.quantity:
      final n = value is num ? value.toDouble() : double.tryParse('$value');
      if (n == null || n <= 0) return 0;
      final target = def.targetFor(category).toDouble();
      return n >= target ? 1 : 0.5;
    case AmalInputType.text:
      return value is String && value.trim().isNotEmpty ? 1 : 0;
  }
}

/// Completion % of entries over `days` for daily-cadence definitions.
int completionPct(
  List<AmalEntry> entries,
  List<AmalDefinition> defs,
  UserCategory category,
  List<String> days,
) {
  final dailyDefs = defs
      .where((d) => d.cadence == 'daily' || d.cadence == 'weekly:any')
      .toList();
  final defMap = {for (final d in dailyDefs) d.key: d};
  final daySet = days.toSet();
  var points = 0.0;
  for (final e in entries) {
    if (!daySet.contains(e.date)) continue;
    final def = defMap[e.amalKey];
    if (def == null) continue;
    points += amalPoints(e.value, def, category);
  }
  final expected = dailyDefs.length * (days.isEmpty ? 1 : days.length);
  if (expected <= 0) return 0;
  return (100 * points / expected).round().clamp(0, 100);
}

/// Per-category completion % for the ring widgets.
Map<AmalCategory, int> completionByCategory(
  List<AmalEntry> entries,
  List<AmalDefinition> defs,
  UserCategory category,
  String day,
) {
  final defsByCat = <AmalCategory, List<AmalDefinition>>{};
  for (final d in defs) {
    defsByCat.putIfAbsent(d.category, () => []).add(d);
  }
  final result = <AmalCategory, int>{};
  for (final cat in defsByCat.keys) {
    final keys = defsByCat[cat]!.map((d) => d.key).toSet();
    final dayEntries = entries
        .where((e) => e.date == day && keys.contains(e.amalKey))
        .toList();
    final defMap = {for (final d in defsByCat[cat]!) d.key: d};
    var points = 0.0;
    for (final e in dayEntries) {
      points += amalPoints(e.value, defMap[e.amalKey]!, category);
    }
    final expected = defsByCat[cat]!.length;
    result[cat] = expected == 0
        ? 0
        : (100 * points / expected).round().clamp(0, 100);
  }
  return result;
}

/// Consecutive days (ending today or yesterday) with ≥ `thresholdPct` daily
/// completion.
int currentStreak(
  List<AmalEntry> entries,
  List<AmalDefinition> defs,
  UserCategory category,
  String today, {
  int thresholdPct = 50,
  int maxLookback = 366,
}) {
  final dailyDefs = defs
      .where((d) => d.cadence == 'daily' || d.cadence == 'weekly:any')
      .toList();
  if (dailyDefs.isEmpty) return 0;
  var streak = 0;
  for (var i = 0; i < maxLookback; i++) {
    final day = addDays(today, -i);
    final dayEntries = entries.where((e) => e.date == day).toList();
    if (dayEntries.isEmpty && i == 0) continue; // today not filled yet — skip
    final pct = completionPct(dayEntries, dailyDefs, category, [day]);
    if (pct >= thresholdPct) {
      streak++;
    } else if (i == 0) {
      continue; // today still in progress — don't break the streak
    } else {
      break;
    }
  }
  return streak;
}

/// Cadence check: is this definition expected on [date]?
bool isAmalDay(AmalDefinition def, String date, {int hijriAdjust = 0}) {
  final d = parseKey(date);
  switch (def.cadence) {
    case 'daily':
    case 'weekly:any':
      return true;
    case 'weekly:fri':
      return d.weekday == DateTime.friday;
    case 'weekly:mon_thu':
      return d.weekday == DateTime.monday || d.weekday == DateTime.thursday;
    case 'monthly:ayyam_beez':
      return isAyyamBeez(d, adjustDays: hijriAdjust);
    default:
      return true;
  }
}

// ── Locking rule ─────────────────────────────────────────────────────────────

/// Deadline of amal-day `date`: Ishraq (sunrise + 20 min) of the NEXT day,
/// at the user's location (Dhaka fallback), with the user's own method.
DateTime computeLockDeadline(
  String date, {
  double lat = 23.8103,
  double lng = 90.4125,
  double tz = 6.0,
  CalcMethod method = CalcMethod.karachi,
  Madhhab madhhab = Madhhab.hanafi,
}) {
  final next = addDays(date, 1);
  final times = PrayerEngine.compute(
    next,
    lat: lat,
    lng: lng,
    tz: tz,
    method: method,
    madhhab: madhhab,
  );
  final nextDay = parseKey(next);
  return DateTime(
    nextDay.year,
    nextDay.month,
    nextDay.day,
  ).add(Duration(minutes: times.ishraq.round()));
}

/// A diary day is locked once Ishraq of the next day has passed.
bool isDateLocked(
  String date,
  DateTime now, {
  double lat = 23.8103,
  double lng = 90.4125,
  double tz = 6.0,
  CalcMethod method = CalcMethod.karachi,
  Madhhab madhhab = Madhhab.hanafi,
}) {
  return computeLockDeadline(
    date,
    lat: lat,
    lng: lng,
    tz: tz,
    method: method,
    madhhab: madhhab,
  ).isBefore(now);
}

/// Habit Builder: the chosen single-amal 7-day challenge progress.
class HabitProgress {
  const HabitProgress({
    required this.daysChecked,
    required this.daysTarget,
    required this.streak,
  });
  final int daysChecked;
  final int daysTarget;
  final int streak;
}

HabitProgress habitProgress(
  String amalKey,
  List<AmalEntry> entries,
  AmalDefinition def,
  UserCategory category,
  String today, {
  int days = 7,
}) {
  var checked = 0;
  var streak = 0;
  for (var i = 0; i < days; i++) {
    final day = addDays(today, -i);
    final e = entries
        .where((e) => e.date == day && e.amalKey == amalKey)
        .toList();
    final done = e.isNotEmpty && amalPoints(e.first.value, def, category) >= 1;
    if (done) {
      checked++;
      if (i == streak) streak++;
    }
  }
  return HabitProgress(daysChecked: checked, daysTarget: days, streak: streak);
}
