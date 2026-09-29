// C-W4b pure-logic tests — most-used selection + countdown-ring interval
// math + the quick-log/preview helpers (the home rewiring that consumes
// them is the next unit; these pin the contracts the wiring will rely on).
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/most_used.dart';
import 'package:sunnah_life/core/prayer_engine.dart' show PrayerKey;
import 'package:sunnah_life/core/waqt_progress.dart';
import 'package:sunnah_life/models/domain.dart';

AmalDefinition _def(String key, int sortOrder, {String inputType = 'tristate'}) =>
    AmalDefinition(
      key: key,
      titleBn: 'আমল $key',
      titleEn: 'Amal $key',
      category: AmalCategory.salah,
      inputType: switch (inputType) {
        'count' => AmalInputType.count,
        'quantity' => AmalInputType.quantity,
        'boolean' => AmalInputType.boolean,
        _ => AmalInputType.tristate,
      },
      cadence: 'daily',
      sortOrder: sortOrder,
    );

AmalEntry _e(String key, String date, Object? value) => AmalEntry(
      amalKey: key,
      date: date,
      clientUpdatedAt: '${date}T06:00:00.000Z',
      value: value,
      source: 'manual',
    );

void main() {
  group('mostUsedAmals — সর্বাধিক ব্যবহৃত', () {
    final defs = [
      _def('salat_fajr', 1),
      _def('tilawat', 2, inputType: 'count'),
      _def('adhkar_sabah', 3, inputType: 'boolean'),
      _def('salat_dhuhr', 4),
    ];
    final today = '2025-06-30';

    test('ranks by distinct full-point days; same-day writes never inflate',
        () {
      final entries = [
        // fajr: 5 distinct days (06-10 double-written — must count once)
        for (final d in ['06-01', '06-02', '06-03', '06-10', '06-28'])
          ...() {
            final e = _e('salat_fajr', '2025-$d', 'jamaat');
            return d == '06-10' ? [e, _e('salat_fajr', '2025-$d', 'alone')] : [e];
          }(),
        // tilawat: 2 days ≥ minDays
        _e('tilawat', '2025-06-05', 5),
        _e('tilawat', '2025-06-06', 10),
        // adhkar_sabah: below-target count-style value → points < 1 → NOT a use
        _e('adhkar_sabah', '2025-06-01', 'x'),
      ];
      final ranked = mostUsedAmals(entries, defs, today: today);
      expect(ranked.first.def.key, 'salat_fajr');
      expect(ranked.first.daysUsed, 5);
      expect(ranked.map((m) => m.def.key), contains('tilawat'));
      expect(ranked.map((m) => m.def.key), isNot(contains('adhkar_sabah')));
    });

    test('outside the 30-day window counts for nothing', () {
      final entries = [
        _e('salat_fajr', '2025-05-01', 'jamaat'), // 60 days back
        _e('salat_fajr', '2025-05-31', 'jamaat'), // just outside the window
        _e('salat_fajr', '2025-06-01', 'jamaat'), // inside
      ];
      final ranked = mostUsedAmals(entries, defs, today: today, minDays: 1);
      expect(ranked.single.daysUsed, 1);
    });

    test('tie-break by catalog sortOrder, deterministic; limit respected', () {
      final entries = [
        _e('salat_dhuhr', '2025-06-01', 'alone'),
        _e('salat_dhuhr', '2025-06-02', 'alone'),
        _e('tilawat', '2025-06-01', 20),
        _e('tilawat', '2025-06-02', 20),
      ];
      final ranked = mostUsedAmals(entries, defs, today: today);
      expect(ranked.map((m) => m.def.key), ['tilawat', 'salat_dhuhr']);

      final limited = mostUsedAmals(entries, defs, today: today, limit: 1);
      expect(limited.single.def.key, 'tilawat');
    });

    test('no history ⇒ empty (never invents rows)', () {
      expect(mostUsedAmals(const [], defs, today: today), isEmpty);
    });
  });

  group('quickLogValue — the আজ লিখুন affordance', () {
    test('boolean → true; tristate → jamaat; counts increment from current',
        () {
      expect(quickLogValue(_def('b', 1, inputType: 'boolean'), null), isTrue);
      expect(quickLogValue(_def('t', 1), null), 'jamaat');
      expect(quickLogValue(_def('c', 1, inputType: 'count'), 3), 4);
      expect(quickLogValue(_def('c', 1, inputType: 'count'), null), 1);
      expect(quickLogValue(_def('q', 1, inputType: 'quantity'), 2.5), 3.5);
    });

    test('free-text amals get no cheap affordance', () {
      expect(
        quickLogValue(
          AmalDefinition(
            key: 'x',
            titleBn: '',
            titleEn: '',
            category: AmalCategory.salah,
            inputType: AmalInputType.text,
            cadence: 'daily',
          ),
          null,
        ),
        isNull,
      );
    });
  });

  group('todayAmalPreview — the amal section ring', () {
    final defs = [
      _def('salat_fajr', 1),
      _def('tilawat', 2, inputType: 'count'),
    ];

    test('completed counts only today + full-point writes', () {
      final p = todayAmalPreview(
        [
          _e('salat_fajr', '2025-06-30', 'jamaat'),
          _e('tilawat', '2025-06-30', 20),
          _e('tilawat', '2025-06-29', 20), // yesterday — excluded
        ],
        defs,
        UserCategory.general,
        '2025-06-30',
      );
      expect(p.completed, 2);
      expect(p.total, 2);
      expect(p.pct, 100);
    });

    test('zero-progress + degenerate catalog clamp sanely', () {
      final none = todayAmalPreview(const [], defs, UserCategory.general,
          '2025-06-30');
      expect(none.completed, 0);
      expect(none.pct, 0);

      final empty = todayAmalPreview(
          const [], const <AmalDefinition>[], UserCategory.general, '2025-06-30');
      expect(empty.total, 0);
      expect(empty.pct, 0);
    });
  });

  group('WaqtInterval — countdown-ring math', () {
    test('remaining fraction decays linearly; halves mid-interval', () {
      const start = WaqtInterval(
        currentWaqt: PrayerKey.dhuhr,
        totalMinutes: 300,
        elapsedMinutes: 0,
      );
      expect(start.remainingFraction, 1.0);
      expect(start.elapsedFraction, 0.0);

      const mid = WaqtInterval(
        currentWaqt: PrayerKey.asr,
        totalMinutes: 300,
        elapsedMinutes: 150,
      );
      expect(mid.remainingFraction, closeTo(0.5, 1e-9));
      expect(mid.elapsedFraction, closeTo(0.5, 1e-9));
    });

    test('degenerate intervals clamp, never divide by zero', () {
      const zero = WaqtInterval(
        currentWaqt: PrayerKey.fajr,
        totalMinutes: 0,
        elapsedMinutes: 0,
      );
      expect(zero.remainingFraction, 0);
      expect(zero.elapsedFraction, 0);

      const overshoot = WaqtInterval(
        currentWaqt: PrayerKey.isha,
        totalMinutes: 60,
        elapsedMinutes: 90,
      );
      expect(overshoot.remainingFraction, 0);
      expect(overshoot.elapsedFraction, 1);

      const negative = WaqtInterval(
        currentWaqt: PrayerKey.fajr,
        totalMinutes: 60,
        elapsedMinutes: -30,
      );
      expect(negative.remainingFraction, 1);
      expect(negative.elapsedFraction, 0);
    });
  });
}
