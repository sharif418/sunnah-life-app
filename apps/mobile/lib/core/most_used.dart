/// সর্বাধিক ব্যবহৃত (most-used) selection (C-W4b) — pure, unit-tested.
///
/// OFFLINE-FIRST DATA SOURCE: the caller passes the amal entries already
/// loaded from the LOCAL Drift DB (the amalProvider window covers −95
/// days..today), so the section works with zero network and updates live
/// when the user quick-logs. A day counts as "used" only when the entry
/// earns full points (amalPoints ≥ 1 — a কাযা tristate or a below-target
/// count is a log, not a use). Distinct DATES are counted, so multiple
/// writes to the same amal on one day never inflate the rank.
///
/// Selection: within the last-30-days window, keep amals used on ≥ minDays
/// distinct days, rank by count desc, tie-break by catalog sortOrder (then
/// key — fully deterministic), take the top [limit]. No history ⇒ empty.
library;

import 'amal_engine.dart';
import 'date_keys.dart';
import '../models/domain.dart';

class MostUsedAmal {
  const MostUsedAmal({required this.def, required this.daysUsed});
  final AmalDefinition def;
  final int daysUsed;
}

List<MostUsedAmal> mostUsedAmals(
  List<AmalEntry> entries,
  List<AmalDefinition> defs, {
  required String today,
  UserCategory category = UserCategory.general,
  int windowDays = 30,
  int limit = 4,
  int minDays = 2,
}) {
  final from = addDays(today, -(windowDays - 1));
  final defMap = {for (final d in defs) d.key: d};
  final counts = <String, Set<String>>{};
  for (final e in entries) {
    // Lexicographic YYYY-MM-DD comparison is a correct date compare.
    if (e.date.compareTo(from) < 0 || e.date.compareTo(today) > 0) continue;
    final def = defMap[e.amalKey];
    if (def == null) continue;
    if (amalPoints(e.value, def, category) >= 1) {
      counts.putIfAbsent(e.amalKey, () => {}).add(e.date);
    }
  }
  final sortOrder = {for (final d in defs) d.key: d.sortOrder};
  final ranked = counts.entries
      .where((c) => c.value.length >= minDays)
      .toList()
    ..sort((a, b) {
      final byCount = b.value.length.compareTo(a.value.length);
      if (byCount != 0) return byCount;
      final byOrder = (sortOrder[a.key] ?? 0).compareTo(sortOrder[b.key] ?? 0);
      if (byOrder != 0) return byOrder;
      return a.key.compareTo(b.key);
    });
  return [
    for (final c in ranked.take(limit))
      MostUsedAmal(def: defMap[c.key]!, daysUsed: c.value.length),
  ];
}

/// The "আজ লিখুন" quick-log value for a most-used row: boolean → true,
/// count/quantity → current + 1, tristate → jamaat. Pure — the widget
/// passes the current value, the engine writes what comes back.
Object? quickLogValue(AmalDefinition def, Object? currentValue) {
  switch (def.inputType) {
    case AmalInputType.boolean:
      return true;
    case AmalInputType.count:
      final n = currentValue is num ? currentValue.toInt() : 0;
      return n + 1;
    case AmalInputType.quantity:
      final n = currentValue is num ? currentValue.toDouble() : 0.0;
      return n + 1;
    case AmalInputType.tristate:
      return 'jamaat';
    case AmalInputType.text:
      return null; // no cheap quick affordance for free-text amals
  }
}

/// Today's preview numbers for the amal section header/ring: completed =
/// today's-catalog defs with full points, total = the catalog size.
class TodayAmalPreview {
  const TodayAmalPreview({required this.completed, required this.total});
  final int completed;
  final int total;
  int get pct => total <= 0 ? 0 : ((100 * completed) / total).round().clamp(0, 100);
}

TodayAmalPreview todayAmalPreview(
  List<AmalEntry> entries,
  List<AmalDefinition> todayDefs,
  UserCategory category,
  String today,
) {
  final byKey = {for (final d in todayDefs) d.key: d};
  var done = 0;
  for (final e in entries) {
    if (e.date != today) continue;
    final def = byKey[e.amalKey];
    if (def == null) continue;
    if (amalPoints(e.value, def, category) >= 1) done++;
  }
  return TodayAmalPreview(completed: done, total: todayDefs.length);
}
