// নিজের মসজিদের সাথে মেলান (2026-10-09): whole minutes per waqt on top of
// the calculation — start times only; sunrise, noon and zawal stay with the
// sun; the bells reschedule when it changes.
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/bell_schedule.dart';
import 'package:sunnah_life/core/prayer_adjust.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/models/user.dart';

void main() {
  group('PrayerAdjust', () {
    test('clamps to ±30, drops zeros, keeps only the five waqts', () {
      var a = const PrayerAdjust().withValue(PrayerKey.fajr, 45);
      expect(a.of(PrayerKey.fajr), 30);
      a = a.withValue(PrayerKey.isha, -2).withValue(PrayerKey.fajr, 0);
      expect(a.toJson(), {'isha': -2});
      expect(a.anyEarlier, isTrue);
      expect(const PrayerAdjust().isEmpty, isTrue);
    });

    test('parses the server map or the stored JSON; junk is no adjustment', () {
      expect(PrayerAdjust.parse({'fajr': 2, 'maghrib': 5}).toJson(), {
        'fajr': 2,
        'maghrib': 5,
      });
      expect(PrayerAdjust.parse('{"asr":-1}').of(PrayerKey.asr), -1);
      expect(PrayerAdjust.parse('{"sunrise":4}').isEmpty, isTrue);
      expect(PrayerAdjust.parse('not json').isEmpty, isTrue);
      expect(PrayerAdjust.parse(null), const PrayerAdjust());
      expect(PrayerAdjust.parse('{"fajr":2}'), PrayerAdjust.parse({'fajr': 2}));
    });
  });

  group('engine', () {
    const day = '2026-08-28';
    final base = PrayerEngine.compute(day, method: CalcMethod.ifb);
    final mine = PrayerEngine.compute(
      day,
      method: CalcMethod.ifb,
      adjust: PrayerAdjust.parse({'fajr': 2, 'dhuhr': 10, 'isha': -1}),
    );

    test('moves the start times by the minutes', () {
      expect(mine.fajr - base.fajr, 2);
      expect(mine.dhuhr - base.dhuhr, 10);
      expect(mine.asr, base.asr);
      expect(mine.isha - base.isha, -1);
    });

    test('sunrise, noon and the forbidden windows stay with the sun', () {
      expect(mine.sunrise, base.sunrise);
      expect(mine.noon, base.noon);
      expect(mine.noon, base.dhuhr);
      expect(
        PrayerEngine.forbiddenWindows(mine),
        PrayerEngine.forbiddenWindows(base),
      );
    });

    test('IFB is the default method', () {
      expect(PrayerEngine.compute(day).fajr, base.fajr);
      // an account the server sent without a method
      final u = User.fromJson({
        'id': 'u',
        'name': 'n',
        'gender': 'M',
        'role': 'member',
        'category': 'general',
      });
      expect(u.calcMethod, CalcMethod.ifb);
    });
  });

  test('a changed adjustment reschedules the bells', () {
    const plain = PrayerBellConfig(
      lat: 23.8,
      lng: 90.4,
      tz: 6,
      method: CalcMethod.ifb,
      madhhab: Madhhab.hanafi,
    );
    final adjusted = PrayerBellConfig(
      lat: 23.8,
      lng: 90.4,
      tz: 6,
      method: CalcMethod.ifb,
      madhhab: Madhhab.hanafi,
      adjust: PrayerAdjust.parse({'maghrib': 5}),
    );
    expect(plain.scheduleKey == adjusted.scheduleKey, isFalse);
  });
}
