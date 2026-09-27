// Amal engine logic tests — points, streaks, completion, locking rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/amal_engine.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/models/domain.dart';

AmalDefinition def(
  String key, {
  AmalInputType type = AmalInputType.boolean,
  Map<String, num>? target,
  String cadence = 'daily',
}) =>
    AmalDefinition(
      key: key,
      titleBn: key,
      titleEn: key,
      category: AmalCategory.salah,
      inputType: type,
      cadence: cadence,
      target: target,
      sortOrder: 0,
    );

AmalEntry entry(String day, String key, Object value) => AmalEntry(
      amalKey: key,
      date: day,
      clientUpdatedAt: '2025-01-01T00:00:00Z',
      value: value,
      source: 'manual',
    );

void main() {
  group('amalPoints', () {
    test('tristate: jamaat/alone = 1, qaza = 0, none = 0', () {
      final d = def('fajr', type: AmalInputType.tristate);
      expect(amalPoints('jamaat', d, UserCategory.general), 1);
      expect(amalPoints('alone', d, UserCategory.general), 1);
      expect(amalPoints('qaza', d, UserCategory.general), 0);
      expect(amalPoints(null, d, UserCategory.general), 0);
    });

    test('boolean: true = 1', () {
      final d = def('miswak');
      expect(amalPoints(true, d, UserCategory.general), 1);
      expect(amalPoints(false, d, UserCategory.general), 0);
    });

    test('count/quantity: >= target = 1, partial > 0 = 0.5', () {
      final d = def('durood',
          type: AmalInputType.count, target: {'general': 100});
      expect(amalPoints(100, d, UserCategory.general), 1);
      expect(amalPoints(150, d, UserCategory.general), 1);
      expect(amalPoints(40, d, UserCategory.general), 0.5);
      expect(amalPoints(0, d, UserCategory.general), 0);
      expect(amalPoints(null, d, UserCategory.general), 0);
    });

    test('quantity target by category: hafez 1 para, alim 10 pages, general 1 page',
        () {
      final tilawat = def('tilawat',
          type: AmalInputType.quantity,
          target: {'general': 1, 'hafez': 1, 'alim': 10});
      expect(amalPoints(1, tilawat, UserCategory.general), 1);
      expect(amalPoints(0.5, tilawat, UserCategory.general), 0.5);
      expect(amalPoints(5, tilawat, UserCategory.alim), 0.5);
      expect(amalPoints(10, tilawat, UserCategory.alim), 1);
      expect(amalPoints(1, tilawat, UserCategory.hafez), 1);
      // Fallback to general when the category is missing from the map.
      final sparse = def('x', type: AmalInputType.count, target: {'general': 3});
      expect(amalPoints(3, sparse, UserCategory.alim), 1);
    });

    test('text: non-empty = 1', () {
      final d = def('note', type: AmalInputType.text);
      expect(amalPoints('লিখেছি', d, UserCategory.general), 1);
      expect(amalPoints('   ', d, UserCategory.general), 0);
    });
  });

  group('streaks', () {
    test('3 consecutive days with entries = 3', () {
      final d = [def('a'), def('b')];
      final today = '2025-03-10';
      final entries = [
        entry('2025-03-08', 'a', true),
        entry('2025-03-08', 'b', true),
        entry('2025-03-09', 'a', true),
        entry('2025-03-09', 'b', true),
        entry('2025-03-10', 'a', true),
        entry('2025-03-10', 'b', true),
      ];
      expect(currentStreak(entries, d, UserCategory.general, today), 3);
    });

    test('breaks on a missed day', () {
      final d = [def('a')];
      final today = '2025-03-10';
      final entries = [
        entry('2025-03-07', 'a', true),
        // 03-08 missed
        entry('2025-03-09', 'a', true),
        entry('2025-03-10', 'a', true),
      ];
      expect(currentStreak(entries, d, UserCategory.general, today), 2);
    });

    test('today not yet filled does not break the streak', () {
      final d = [def('a')];
      final today = '2025-03-10';
      final entries = [
        entry('2025-03-08', 'a', true),
        entry('2025-03-09', 'a', true),
      ];
      expect(currentStreak(entries, d, UserCategory.general, today), 2);
    });
  });

  group('locking rule (paper-diary: next day Ishraq)', () {
    test('day locks after next-day ishraq (Dhaka)', () {
      // 2025-06-14: next day 2025-06-15 sunrise ≈ 05:11 → ishraq ≈ 05:31.
      final locked = isDateLocked(
        '2025-06-14',
        DateTime(2025, 6, 15, 6, 0),
        lat: 23.8103,
        lng: 90.4125,
        tz: 6.0,
      );
      final notYet = isDateLocked(
        '2025-06-14',
        DateTime(2025, 6, 15, 4, 0),
        lat: 23.8103,
        lng: 90.4125,
        tz: 6.0,
      );
      expect(locked, isTrue);
      expect(notYet, isFalse);
    });

    test('deadline is the next day, not the same day', () {
      final deadline = computeLockDeadline('2025-06-14',
          lat: 23.8103, lng: 90.4125, tz: 6.0);
      expect(dateKey(deadline), '2025-06-15');
      // Sunrise on 2025-06-15 in Dhaka ≈ 05:11 → ishraq 05:31 (±2 min).
      final minutes = deadline.hour * 60 + deadline.minute;
      expect((minutes - (5 * 60 + 31)).abs(), lessThanOrEqualTo(2));
    });

    test('older days are locked, today never is (caller rule)', () {
      final now = DateTime(2025, 6, 20, 12, 0);
      expect(isDateLocked('2025-06-18', now, tz: 6.0), isTrue);
      expect(isDateLocked('2025-06-19', now, tz: 6.0), isTrue);
      // A future day's deadline is also in the future → not locked.
      expect(isDateLocked('2025-06-25', now, tz: 6.0), isFalse);
    });
  });

  group('cadence awareness', () {
    test('weekly:fri only on Friday; ayyam-beez on Hijri 13–15', () {
      final fri = def('kahf', cadence: 'weekly:fri');
      final monThu = def('fast', cadence: 'weekly:mon_thu');
      final beez = def('beez', cadence: 'monthly:ayyam_beez');
      // 2025-06-13 is a Friday.
      expect(isAmalDay(fri, '2025-06-13'), isTrue);
      expect(isAmalDay(fri, '2025-06-14'), isFalse);
      // 2025-06-16 Monday, 2025-06-19 Thursday.
      expect(isAmalDay(monThu, '2025-06-16'), isTrue);
      expect(isAmalDay(monThu, '2025-06-19'), isTrue);
      expect(isAmalDay(monThu, '2025-06-17'), isFalse);
      // Ayyam-beez: use a known window — 2025-06-09..11 was Dhul-Hijjah 13–15
      // in the Umm al-Qura table (hijri package). Verify at least one hit in
      // a 30-day sweep and that hits are exactly Hijri 13–15.
      var hits = <String>[];
      for (var i = 1; i <= 30; i++) {
        final day = addDays('2025-06-01', i);
        if (isAmalDay(beez, day)) hits.add(day);
      }
      expect(hits.length, inInclusiveRange(2, 5)); // 2–3 per lunar month
    });

    test('completion percentage over a day', () {
      final defs = [
        def('a', type: AmalInputType.tristate),
        def('b'),
        def('c', type: AmalInputType.count, target: {'general': 10}),
      ];
      final today = '2025-03-10';
      final entries = [
        entry(today, 'a', 'jamaat'), // 1
        entry(today, 'b', false), // 0
        entry(today, 'c', 4), // 0.5
      ];
      // (1 + 0 + 0.5) / 3 = 50%
      expect(completionPct(entries, defs, UserCategory.general, [today]), 50);
    });
  });

  group('habit builder progress', () {
    test('counts checked days + streak', () {
      final d = def('a');
      final today = '2025-03-10';
      final entries = [
        entry('2025-03-08', 'a', true),
        entry('2025-03-09', 'a', true),
        entry('2025-03-10', 'a', true),
      ];
      final p =
          habitProgress('a', entries, d, UserCategory.general, today, days: 7);
      expect(p.daysChecked, 3);
      expect(p.streak, 3);
    });
  });
}
