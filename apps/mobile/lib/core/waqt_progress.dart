/// Countdown-ring progress math (C-W4b) — pure, unit-tested.
///
/// The home hero ring shows the REMAINING fraction of the CURRENT waqt
/// interval: currentWaqt's farz start → the next farz start (which is
/// where minutesToNext lands), wrapping over midnight into tomorrow's
/// fajr. The pre-dawn case (isha still current before today's fajr) uses
/// yesterday's isha approximated as today's isha − 24 h — the same ±1–2
/// min/day approximation the home-widget snapshot (C-W3f) documents.
library;

import 'prayer_engine.dart';

class WaqtInterval {
  const WaqtInterval({
    required this.currentWaqt,
    required this.totalMinutes,
    required this.elapsedMinutes,
  });

  /// The farz waqt whose interval is running.
  final PrayerKey currentWaqt;

  /// Interval length in minutes (> 0; > 24 h never happens in practice but
  /// degenerate polar inputs clamp the fractions anyway).
  final double totalMinutes;

  /// How far into the interval `nowMinutes` is (may start negative when
  /// `now` precedes the computed start — clamped at the fraction level).
  final double elapsedMinutes;

  /// Fraction (0..1) of the interval still to come — the gold arc length.
  double get remainingFraction => totalMinutes <= 0
      ? 0
      : ((totalMinutes - elapsedMinutes) / totalMinutes).clamp(0.0, 1.0);

  /// Fraction (0..1) of the interval already gone.
  double get elapsedFraction =>
      totalMinutes <= 0 ? 0 : (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);
}

WaqtInterval waqtInterval(PrayerTimesBundle t, double nowMinutes) {
  final current = PrayerEngine.currentWaqt(t, nowMinutes);
  final (_, minsToNext) = PrayerEngine.nextPrayer(t, nowMinutes);
  final nextStart = nowMinutes + minsToNext;
  // Pre-fajr: current is isha and yesterday's isha ≈ today's isha − 24 h.
  final start = current == PrayerKey.isha && nowMinutes < t.fajr
      ? t.isha - 24 * 60.0
      : t.byKey(current);
  return WaqtInterval(
    currentWaqt: current,
    totalMinutes: nextStart - start,
    elapsedMinutes: nowMinutes - start,
  );
}
