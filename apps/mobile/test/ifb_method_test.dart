// Islamic Foundation Bangladesh method: the Karachi angles with every start
// time rounded UP to the whole minute — checked against IFB's published
// Dhaka timetable. The adhan library and the web/API engine differ by a few
// seconds, so a time on a minute boundary may land one minute apart; IFB's
// own table is that close to any model (12 Dec 2025: Zuhr 11:52, Asr 3:37,
// Maghrib 5:16, Isha 6:34; 28 Aug 2026: Asr 4:31, Maghrib 6:24, Isha 7:40).
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/models/user.dart';

double clock(int h, int m) => h * 60.0 + m;

void main() {
  test('IFB is within a minute of the published Dhaka times', () {
    final dec = PrayerEngine.compute('2025-12-12', method: CalcMethod.ifb);
    final aug = PrayerEngine.compute('2026-08-28', method: CalcMethod.ifb);
    final pairs = [
      (dec.dhuhr, clock(11, 52)),
      (dec.asr, clock(15, 37)),
      (dec.maghrib, clock(17, 16)),
      (dec.isha, clock(18, 34)),
      (aug.asr, clock(16, 31)),
      (aug.maghrib, clock(18, 24)),
      (aug.isha, clock(19, 40)),
    ];
    for (final (ours, ifb) in pairs) {
      expect((ours - ifb).abs(), lessThanOrEqualTo(1), reason: 'ours $ours vs IFB $ifb');
    }
  });

  test('start times are whole minutes, never earlier than the exact time', () {
    final t = PrayerEngine.compute('2025-12-12', method: CalcMethod.ifb);
    final k = PrayerEngine.compute('2025-12-12', method: CalcMethod.karachi);
    for (final m in [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha]) {
      expect(m, m.roundToDouble());
    }
    // the Karachi times are rounded to the NEAREST minute; IFB's rounded up
    for (final (a, b) in [(t.fajr, k.fajr), (t.asr, k.asr), (t.isha, k.isha)]) {
      expect(a - b, inInclusiveRange(0, 1));
    }
  });

  test('stored as "ifb" and read back', () {
    expect(CalcMethod.ifb.json, 'ifb');
    expect(CalcMethodJson.fromJson('ifb'), CalcMethod.ifb);
  });
}
