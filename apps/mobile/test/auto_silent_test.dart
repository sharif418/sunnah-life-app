// C-W3e auto-silent pure logic — windows, clamps, prefs round-trip, the
// scheduling state machine and the deterministic ringer-alarm ids. No
// platform channels; the impure arming (PrayerBellScheduler) is covered by
// static review + the device checklist.
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/auto_silent.dart';
import 'package:sunnah_life/core/bell_schedule.dart';
import 'package:sunnah_life/core/prayer_engine.dart';

void main() {
  // Fixed bundle — fajr 05:12, dhuhr 12:10, asr 15:30, maghrib 18:05,
  // isha 19:20 (farz); other waqts irrelevant to auto-silent.
  PrayerTimesBundle bundle() => PrayerTimesBundle(
        fajr: 5 * 60 + 12,
        sunrise: 6 * 60 + 33,
        ishraq: 6 * 60 + 53,
        duha: 9 * 60,
        dhuhr: 12 * 60 + 10,
        asr: 15 * 60 + 30,
        maghrib: 18 * 60 + 5,
        sunset: 18 * 60 + 2,
        isha: 19 * 60 + 20,
        tahajjud: 3 * 60,
      );

  group('minutes clamp', () {
    test('default 30 when the pref is absent', () {
      expect(autoSilentMinutesFor(stored: null), 30);
    });

    test('clamps to 10–90', () {
      expect(autoSilentMinutesFor(stored: 5), 10);
      expect(autoSilentMinutesFor(stored: 45), 45);
      expect(autoSilentMinutesFor(stored: 120), 90);
      expect(kMinAutoSilentMinutes, 10);
      expect(kMaxAutoSilentMinutes, 90);
      expect(kDefaultAutoSilentMinutes, 30);
    });

    test('prefs keys are stable + per-waqt', () {
      expect(autoSilentEnabledPrefKey, 'autosilent_enabled');
      expect(autoSilentWaqtPrefKey(PrayerKey.fajr), 'autosilent_fajr');
      expect(autoSilentWaqtPrefKey(PrayerKey.isha), 'autosilent_isha');
      expect(autoSilentMinutesPrefKey, 'autosilent_min');
    });
  });

  group('settings round-trip', () {
    AutoSilentPrefs read(Map<String, Object> stored) =>
        AutoSilentPrefs.fromStorage(
          boolAt: (k) => stored[k] as bool?,
          intAt: (k) => stored[k] as int?,
        );

    test('defaults: master off, all five farz on, 30 minutes', () {
      final p = read(const {});
      expect(p.enabled, isFalse);
      expect(p.waqts, farzPrayers.toSet());
      expect(p.minutes, 30);
    });

    test('stored values round-trip', () {
      final p = read({
        'autosilent_enabled': true,
        'autosilent_min': 45,
        'autosilent_fajr': true,
        'autosilent_dhuhr': false,
        'autosilent_asr': true,
        'autosilent_maghrib': false,
        'autosilent_isha': true,
      });
      expect(p.enabled, isTrue);
      expect(p.minutes, 45);
      expect(p.waqts, {
        PrayerKey.fajr,
        PrayerKey.asr,
        PrayerKey.isha,
      });
    });

    test('out-of-range stored minutes clamp on read', () {
      expect(read({'autosilent_min': 200}).minutes, 90);
      expect(read({'autosilent_min': 1}).minutes, 10);
    });
  });

  group('silent windows', () {
    test('window = waqt start → start + N minutes', () {
      final windows = autoSilentWindowsForDay(
        dayKey: '2026-02-08',
        times: bundle(),
        waqts: farzPrayers.toSet(),
        minutes: 30,
      );
      expect(windows, hasLength(5));
      final fajr = windows.first;
      expect(fajr.key, PrayerKey.fajr);
      expect(fajr.start, DateTime(2026, 2, 8, 5, 12));
      expect(fajr.end, DateTime(2026, 2, 8, 5, 42));
      final isha = windows.last;
      expect(isha.key, PrayerKey.isha);
      expect(isha.start, DateTime(2026, 2, 8, 19, 20));
      expect(isha.end, DateTime(2026, 2, 8, 19, 50));
    });

    test('per-waqt enable matrix — only the selected waqts', () {
      final windows = autoSilentWindowsForDay(
        dayKey: '2026-02-08',
        times: bundle(),
        waqts: {PrayerKey.dhuhr, PrayerKey.maghrib},
        minutes: 15,
      );
      expect(windows.map((w) => w.key), [PrayerKey.dhuhr, PrayerKey.maghrib]);
      expect(windows.last.end, DateTime(2026, 2, 8, 18, 20));
    });

    test('empty waqt set → no windows', () {
      expect(
        autoSilentWindowsForDay(
          dayKey: '2026-02-08',
          times: bundle(),
          waqts: const {},
          minutes: 30,
        ),
        isEmpty,
      );
    });
  });

  group('alarm arms', () {
    test('ids are the deterministic Nid scheme, on at start / off at end',
        () {
      final now = DateTime(2026, 2, 8, 4, 0); // before fajr
      final arms = autoSilentArmsForDay(
        dayKey: '2026-02-08',
        times: bundle(),
        waqts: {PrayerKey.fajr},
        minutes: 30,
        dayOffset: 1,
        now: now,
      );
      expect(arms, hasLength(2));
      expect(arms[0].id, Nid.autoSilentOn(1, PrayerKey.fajr));
      expect(arms[0].at, DateTime(2026, 2, 8, 5, 12));
      expect(arms[0].on, isTrue);
      expect(arms[1].id, Nid.autoSilentOff(1, PrayerKey.fajr));
      expect(arms[1].at, DateTime(2026, 2, 8, 5, 42));
      expect(arms[1].on, isFalse);
    });

    test('mid-window: start past → only the restore arm remains', () {
      final now = DateTime(2026, 2, 8, 5, 30); // inside 05:12–05:42
      final arms = autoSilentArmsForDay(
        dayKey: '2026-02-08',
        times: bundle(),
        waqts: {PrayerKey.fajr},
        minutes: 30,
        dayOffset: 0,
        now: now,
      );
      expect(arms, hasLength(1));
      expect(arms.single.on, isFalse);
      expect(arms.single.at, DateTime(2026, 2, 8, 5, 42));
    });

    test('past window arms nothing', () {
      final now = DateTime(2026, 2, 8, 6, 0); // window over
      expect(
        autoSilentArmsForDay(
          dayKey: '2026-02-08',
          times: bundle(),
          waqts: {PrayerKey.fajr},
          minutes: 30,
          dayOffset: 0,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('scheduling state machine (autoSilentWindowArms)', () {
    test('feature off → nothing scheduled', () {
      final arms = autoSilentWindowArms(
        prefs: const AutoSilentPrefs(
          enabled: false,
          waqts: {PrayerKey.fajr},
          minutes: 30,
        ),
        dndGranted: true,
        today: '2026-02-08',
        compute: (_) => bundle(),
        now: DateTime(2026, 2, 8, 4),
      );
      expect(arms, isEmpty);
    });

    test('DND access missing → nothing scheduled', () {
      final arms = autoSilentWindowArms(
        prefs: AutoSilentPrefs(
          enabled: true,
          waqts: farzPrayers.toSet(),
          minutes: 30,
        ),
        dndGranted: false,
        today: '2026-02-08',
        compute: (_) => bundle(),
        now: DateTime(2026, 2, 8, 4),
      );
      expect(arms, isEmpty);
    });

    test('enabled + granted → rolling 3 days × enabled waqts, future only',
        () {
      final arms = autoSilentWindowArms(
        prefs: AutoSilentPrefs(
          enabled: true,
          waqts: {PrayerKey.fajr, PrayerKey.isha},
          minutes: 30,
        ),
        dndGranted: true,
        today: '2026-02-08',
        compute: (_) => bundle(),
        now: DateTime(2026, 2, 8, 4),
      );
      // 3 days × 2 waqts × 2 edges, all in the future.
      expect(arms, hasLength(12));
      for (final a in arms) {
        expect(a.at.isAfter(DateTime(2026, 2, 8, 4)), isTrue);
      }
      // Day-2 isha restore lands 2026-02-10 19:50.
      expect(
        arms.map((a) => a.id),
        contains(Nid.autoSilentOff(2, PrayerKey.isha)),
      );
    });

    test('no waqt selected with master on → honest empty schedule', () {
      final arms = autoSilentWindowArms(
        prefs: const AutoSilentPrefs(
          enabled: true,
          waqts: {},
          minutes: 30,
        ),
        dndGranted: true,
        today: '2026-02-08',
        compute: (_) => bundle(),
        now: DateTime(2026, 2, 8, 4),
      );
      expect(arms, isEmpty);
    });
  });

  group('auto-silent alarm ids', () {
    test('deterministic + disjoint from every other Nid family', () {
      final other = <int>{
        for (var offset = 0; offset < kRollingWindowDays; offset++)
          for (final key in farzPrayers) ...[
            Nid.bell(offset, key),
            Nid.postPrayer(offset, key),
          ],
        for (final key in farzPrayers) ...[
          Nid.exactAlarm(key),
          Nid.amalConfirm(key),
        ],
      };
      for (var offset = 0; offset < kRollingWindowDays; offset++) {
        for (final key in farzPrayers) {
          final on = Nid.autoSilentOn(offset, key);
          final off = Nid.autoSilentOff(offset, key);
          expect(on, Nid.autoSilentOn(offset, key));
          expect(other, isNot(contains(on)));
          expect(other, isNot(contains(off)));
          expect(off, isNot(on));
        }
      }
    });

    test('day blocks cannot collide — stride > max PrayerKey.index', () {
      final ids = <int>{};
      for (var offset = 0; offset < kRollingWindowDays; offset++) {
        for (final key in PrayerKey.values) {
          ids
            ..add(Nid.autoSilentOn(offset, key))
            ..add(Nid.autoSilentOff(offset, key));
        }
      }
      expect(ids, hasLength(2 * 3 * PrayerKey.values.length));
    });

    test('autoSilentAllIds covers every armed id (the full cancel set)', () {
      final all = Nid.autoSilentAllIds().toSet();
      for (var offset = 0; offset < kRollingWindowDays; offset++) {
        for (final key in PrayerKey.values) {
          expect(all, contains(Nid.autoSilentOn(offset, key)));
          expect(all, contains(Nid.autoSilentOff(offset, key)));
        }
      }
      // 2 families × 3 days × 16 stride slots.
      expect(all, hasLength(96));
      // And nothing outside the two families sneaks in.
      expect(all.every((id) => id >= 4000 && id < 5048), isTrue);
    });
  });
}
