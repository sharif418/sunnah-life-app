/// Date-key helpers (YYYY-MM-DD) — mirrors src/lib/calendars.ts.
/// All day arithmetic in Sunnah Life uses these timezone-free local keys.
library;

import 'bn_digits.dart';

/// Local YYYY-MM-DD key for a DateTime (no UTC drift).
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Parse a YYYY-MM-DD key into a local DateTime (midnight).
DateTime parseKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// Add [days] to a date key, returning a new key.
String addDays(String key, int days) {
  final d = parseKey(key);
  return dateKey(d.add(Duration(days: days)));
}

/// First day of the month containing [key].
String monthStart(String key) => '${key.substring(0, 7)}-01';

/// Number of days in the month of [key].
int monthDays(String key) {
  final d = parseKey(key);
  final next = DateTime(d.year, d.month + 1, 1);
  return next.difference(DateTime(d.year, d.month, 1)).inDays;
}

/// 1..N day keys of the month containing [key].
List<String> monthDayKeys(String key) {
  final n = monthDays(key);
  final prefix = key.substring(0, 7);
  return List.generate(
    n,
    (i) => '$prefix-${(i + 1).toString().padLeft(2, '0')}',
  );
}

/// The weekday (1=Mon..7=Sun, ISO-like where Monday=1) of a key.
int weekdayOfKey(String key) => parseKey(key).weekday;

/// Human duration like "২ ঘ ১৫ মি" / "2h 15m".
String formatDurationBn(int totalMinutes, {bool bengali = true}) {
  final h = totalMinutes ~/ 60;
  final m = (totalMinutes % 60).round();
  String two(int v) => bengali ? toBn(v) : v.toString();
  if (h <= 0) return '${two(m)}${bengali ? ' মি' : 'm'}';
  return '${two(h)}${bengali ? ' ঘ ' : 'h '}${two(m)}${bengali ? ' মি' : 'm'}';
}
