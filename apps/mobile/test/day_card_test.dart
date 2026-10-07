// The home prayer card's arithmetic, at every part of the day.
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/day_card.dart';
import 'package:sunnah_life/core/prayer_engine.dart';

// Dhaka, early October (minutes from midnight)
const t = PrayerTimesBundle(
  fajr: 276, // 4:36
  sunrise: 351, // 5:51
  ishraq: 371,
  duha: 440,
  dhuhr: 706, // 11:46
  asr: 961, // 16:01
  maghrib: 1062, // 17:42
  sunset: 1060,
  isha: 1135, // 18:55
  tahajjud: 150, // 2:30
);

void main() {
  test('in the middle of Dhuhr: span, next, time left, the sun', () {
    final s = computeDayCard(t, 921); // 15:21
    expect(s.current, PrayerKey.dhuhr);
    expect(s.next, PrayerKey.asr);
    expect(s.spanStart, 706);
    expect(s.spanEnd, 961);
    expect(s.minutesLeft, 40);
    expect(s.fraction, closeTo((921 - 706) / (961 - 706), 1e-9));
    expect(s.isDay, isTrue);
    expect(s.orbFraction, closeTo((921 - 351) / (1060 - 351), 1e-9));
    expect(s.forbiddenKey, isNull);
  });

  test('Fajr ends at sunrise; then no fard runs until Dhuhr', () {
    final fajr = computeDayCard(t, 300);
    expect(fajr.current, PrayerKey.fajr);
    expect(fajr.spanEnd, 351);
    expect(fajr.next, PrayerKey.dhuhr);

    final gap = computeDayCard(t, 500);
    expect(gap.current, isNull);
    expect(gap.next, PrayerKey.dhuhr);
    expect(gap.spanStart, 351);
    expect(gap.spanEnd, 706);
    expect(gap.minutesLeft, 206);
  });

  test('just after midnight is still last night\'s Isha, until Fajr', () {
    final s = computeDayCard(t, 60); // 1:00
    expect(s.current, PrayerKey.isha);
    expect(s.next, PrayerKey.fajr);
    expect(s.minutesLeft, 276 - 60);
    expect(s.isDay, isFalse);

    final evening = computeDayCard(t, 1230); // 20:30
    expect(evening.current, PrayerKey.isha);
    expect(evening.minutesLeft, 276 + 1440 - 1230);
    expect(evening.isDay, isFalse);
    expect(evening.orbFraction, inInclusiveRange(0.0, 1.0));
  });

  test('forbidden windows are reported with their end', () {
    final s = computeDayCard(t, 358); // just after sunrise
    expect(s.forbiddenKey, 'sunrise');
    expect(s.forbiddenEnd, 351 + 20);
    expect(computeDayCard(t, 700).forbiddenKey, 'zawal');
    expect(computeDayCard(t, 1050).forbiddenKey, 'sunset');
  });

  test('the minute count rounds up and never goes negative', () {
    expect(computeDayCard(t, 960.4).minutesLeft, 1);
    expect(computeDayCard(t, 961).current, PrayerKey.asr);
  });

  test('nafl windows: Duha until the zawal window, Tahajjud until Fajr', () {
    final w = naflWindows(t);
    expect(w.ishraq, 371);
    expect(w.duhaStart, 440);
    expect(w.duhaEnd, 706 - 10);
    expect(w.tahajjudStart, 150);
    expect(w.tahajjudEnd, 276);
  });
}
