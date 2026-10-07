/// The home prayer card's arithmetic (2026-10-07 redesign, approved with
/// the Foundation): which fard waqt is running and until when, how much of
/// it is left, where the sun (or the moon) sits on the day's arc, and the
/// forbidden window in force. Pure — unit-tested in test/day_card_test.dart.
///
/// A fard waqt here ends where the NEXT one begins, except Fajr, which ends
/// at sunrise. Between sunrise and Dhuhr no fard is running (the Ishraq and
/// Duha time) — the card says so instead of stretching Fajr to noon.
library;

import 'prayer_engine.dart';

/// One fard waqt's span in minutes from midnight (Isha's end is past 1440).
class WaqtSpan {
  const WaqtSpan(this.key, this.start, this.end);
  final PrayerKey key;
  final double start;
  final double end;
}

/// The five fard spans of the day.
List<WaqtSpan> fardSpans(PrayerTimesBundle t) => [
  WaqtSpan(PrayerKey.fajr, t.fajr, t.sunrise),
  WaqtSpan(PrayerKey.dhuhr, t.dhuhr, t.asr),
  WaqtSpan(PrayerKey.asr, t.asr, t.maghrib),
  WaqtSpan(PrayerKey.maghrib, t.maghrib, t.isha),
  WaqtSpan(PrayerKey.isha, t.isha, t.fajr + 1440),
];

class DayCardState {
  const DayCardState({
    required this.current,
    required this.next,
    required this.spanStart,
    required this.spanEnd,
    required this.fraction,
    required this.minutesLeft,
    required this.isDay,
    required this.orbFraction,
    required this.forbiddenKey,
    required this.forbiddenEnd,
  });

  /// The running fard waqt; null between sunrise and Dhuhr.
  final PrayerKey? current;

  /// The next fard waqt to begin.
  final PrayerKey next;

  /// The span shown under the sky: the running waqt, or sunrise → Dhuhr.
  final double spanStart;
  final double spanEnd;

  /// 0..1 through that span.
  final double fraction;

  /// Whole minutes until the span ends (rounded up: "১ মিনিট" until it is
  /// really over).
  final int minutesLeft;

  /// Sun between sunrise and sunset, else the moon.
  final bool isDay;

  /// 0..1 along the arc: sunrise→sunset by day, sunset→sunrise by night.
  final double orbFraction;

  /// 'sunrise' | 'zawal' | 'sunset' while a forbidden window is in force.
  final String? forbiddenKey;
  final double? forbiddenEnd;
}

DayCardState computeDayCard(PrayerTimesBundle t, double now) {
  // before Fajr we are still inside last night's Isha
  final n = now < t.fajr ? now + 1440 : now;
  WaqtSpan? cur;
  for (final s in fardSpans(t)) {
    if (n >= s.start && n < s.end) cur = s;
  }

  late final double start, end;
  late final PrayerKey next;
  if (cur != null) {
    start = cur.start;
    end = cur.end;
    const order = [
      PrayerKey.fajr,
      PrayerKey.dhuhr,
      PrayerKey.asr,
      PrayerKey.maghrib,
      PrayerKey.isha,
    ];
    next = order[(order.indexOf(cur.key) + 1) % order.length];
  } else {
    // sunrise → Dhuhr: no fard running
    start = t.sunrise;
    end = t.dhuhr;
    next = PrayerKey.dhuhr;
  }
  final at = cur != null ? n : now;
  final fraction = ((at - start) / (end - start)).clamp(0.0, 1.0);
  final left = (end - at).ceil().clamp(0, 1440);

  final isDay = now >= t.sunrise && now <= t.sunset;
  final dayLen = t.sunset - t.sunrise;
  final orb = isDay
      ? (now - t.sunrise) / dayLen
      : (((now - t.sunset) + 1440) % 1440) / (1440 - dayLen);

  String? fKey;
  double? fEnd;
  for (final (key, s, e) in PrayerEngine.forbiddenWindows(t)) {
    if (now >= s && now < e) {
      fKey = key;
      fEnd = e;
    }
  }

  return DayCardState(
    current: cur?.key,
    next: next,
    spanStart: start,
    spanEnd: end,
    fraction: fraction,
    minutesLeft: left,
    isDay: isDay,
    orbFraction: orb.clamp(0.0, 1.0),
    forbiddenKey: fKey,
    forbiddenEnd: fEnd,
  );
}

/// The nafl windows the schedule card shows as ranges ("when CAN I pray").
/// Duha runs until the zawal forbidden window begins; Tahajjud until Fajr.
({
  double ishraq,
  double duhaStart,
  double duhaEnd,
  double tahajjudStart,
  double tahajjudEnd,
})
naflWindows(PrayerTimesBundle t) {
  final zawalStart = PrayerEngine.forbiddenWindows(t)[1].$2;
  return (
    ishraq: t.ishraq,
    duhaStart: t.duha,
    duhaEnd: zawalStart,
    tahajjudStart: t.tahajjud,
    tahajjudEnd: t.fajr,
  );
}
