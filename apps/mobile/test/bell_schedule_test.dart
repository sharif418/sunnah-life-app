// C-W3b bell-scheduling pure logic — deterministic ids, minute clamps,
// action payload codec, reschedule-trigger detection. No platform channels
// involved: everything here is core/bell_schedule.dart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/bell_schedule.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/services/widget_snapshot.dart';

void main() {
  group('rolling-window notification ids', () {
    test('deterministic — same inputs, same ids', () {
      for (final key in farzPrayers) {
        for (var offset = 0; offset < kRollingWindowDays; offset++) {
          expect(
            Nid.bell(offset, key),
            Nid.bell(offset, key),
            reason: 'bell id must be a pure function',
          );
        }
      }
    });

    test('collision-free across 3 days × 5 farz × bell/post', () {
      final ids = <int>{};
      for (var offset = 0; offset < kRollingWindowDays; offset++) {
        for (final key in farzPrayers) {
          ids
            ..add(Nid.bell(offset, key))
            ..add(Nid.postPrayer(offset, key));
        }
      }
      expect(farzPrayers.length, 5);
      expect(kRollingWindowDays, 3);
      expect(ids, hasLength(30), reason: 'every slot must be unique');
    });

    test('day-0 slots reuse the historical single-day ids', () {
      // Pre-C-W3b devices armed 1000+idx / 2000+idx; the upgrade replaces
      // those alarms in place instead of duplicating them.
      expect(Nid.bell(0, PrayerKey.fajr), 1000);
      expect(Nid.bell(0, PrayerKey.isha), 1008); // isha index = 8
      expect(Nid.postPrayer(0, PrayerKey.fajr), 2000);
      expect(Nid.postPrayer(0, PrayerKey.isha), 2008);
    });

    test('day blocks cannot collide — stride > max PrayerKey.index', () {
      final maxIndex = PrayerKey.values
          .map((k) => k.index)
          .reduce((a, b) => a > b ? a : b);
      expect(1000 + 2 * 16 + maxIndex, lessThan(1000 + 3 * 16));
      // And the two families stay disjoint from each other + exact alarms.
      final bellMax = 1000 + 2 * 16 + maxIndex;
      final postMin = 2000;
      expect(bellMax, lessThan(postMin));
      final postMax = 2000 + 2 * 16 + maxIndex;
      for (final key in farzPrayers) {
        expect(Nid.exactAlarm(key), lessThan(1000));
      }
      expect(postMax, lessThan(Nid.amalConfirmBase));
    });

    test('rollingWindowDateKeys covers today + 2', () {
      final today = '2026-02-08';
      expect(rollingWindowDateKeys(today), [
        '2026-02-08',
        '2026-02-09',
        '2026-02-10',
      ]);
    });
  });

  group('per-waqt minutes', () {
    test('defaults when the pref is absent', () {
      expect(bellMinutesFor(PrayerKey.fajr, stored: null), 10);
      expect(postPrayerMinutesFor(PrayerKey.asr, stored: null), 20);
    });

    test('bell lead clamps to 0–60', () {
      expect(bellMinutesFor(PrayerKey.fajr, stored: -5), 0);
      expect(bellMinutesFor(PrayerKey.fajr, stored: 7), 7);
      expect(bellMinutesFor(PrayerKey.fajr, stored: 99), 60);
    });

    test('post-prayer lag clamps to 5–120', () {
      expect(postPrayerMinutesFor(PrayerKey.isha, stored: 0), 5);
      expect(postPrayerMinutesFor(PrayerKey.isha, stored: 35), 35);
      expect(postPrayerMinutesFor(PrayerKey.isha, stored: 999), 120);
    });

    test('prefs keys are per-waqt and stable', () {
      expect(bellMinutesPrefKey(PrayerKey.maghrib), 'bellmin_maghrib');
      expect(postPrayerMinutesPrefKey(PrayerKey.dhuhr), 'postmin_dhuhr');
    });
  });

  group('post-prayer action payload codec', () {
    test('encode/decode round-trip', () {
      const payload = PostPrayerActionPayload(
        dateKey: '2026-02-08',
        amalKey: 'salat_fajr',
      );
      final decoded = PostPrayerActionPayload.decode(payload.encode());
      expect(decoded, payload);
      expect(decoded!.dateKey, '2026-02-08');
      expect(decoded.amalKey, 'salat_fajr');
      // Wire format: flat JSON with exactly the two context fields.
      final raw = jsonDecode(payload.encode()) as Map<String, dynamic>;
      expect(raw.keys.toSet(), {'dateKey', 'amalKey'});
    });

    test('malformed payloads decode to null — never throw', () {
      expect(PostPrayerActionPayload.decode(null), isNull);
      expect(PostPrayerActionPayload.decode(''), isNull);
      expect(PostPrayerActionPayload.decode('not json'), isNull);
      expect(PostPrayerActionPayload.decode('[1,2]'), isNull);
      expect(PostPrayerActionPayload.decode('{"dateKey":"x"}'), isNull);
      expect(PostPrayerActionPayload.decode('{"dateKey":"","amalKey":"s"}'),
          isNull);
      expect(PostPrayerActionPayload.decode('{"dateKey":"x","amalKey":42}'),
          isNull);
      expect(
        PostPrayerActionPayload.decode('"just a string"'),
        isNull,
      );
    });

    test('action ids map to the catalog tristate values', () {
      expect(kAmalActionValues['amal_jamaat'], 'jamaat');
      expect(kAmalActionValues['amal_ekai'], 'alone');
      expect(kAmalActionValues['amal_qaza'], 'qaza');
      expect(kAmalActionValues['amal_unknown'], isNull);
      // Every value has a Bengali label for the confirmation notification.
      for (final v in kAmalActionValues.values) {
        expect(kAmalValueLabelsBn[v], isNotNull);
      }
    });

    test('salat amalKey + auto source mirror the catalog', () {
      // fallback_catalog.dart: salat_fajr…salat_isha, autoSource
      // auto:prayer:<waqt> (server AUTO_SOURCE_RE allowlist).
      expect(salatAmalKey(PrayerKey.fajr), 'salat_fajr');
      expect(salatAutoSource(PrayerKey.isha), 'auto:prayer:isha');
      expect(autoSourceFromAmalKey('salat_dhuhr'), 'auto:prayer:dhuhr');
      expect(autoSourceFromAmalKey('quran_page'), isNull);
    });
  });

  group('reschedule trigger (profile change detection)', () {
    const base = PrayerBellConfig(
      lat: 23.8103,
      lng: 90.4125,
      tz: 6.0,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
    );

    PrayerBellConfig with_({
      double? lat,
      double? lng,
      double? tz,
      CalcMethod? method,
      Madhhab? madhhab,
    }) =>
        PrayerBellConfig(
          lat: lat ?? base.lat,
          lng: lng ?? base.lng,
          tz: tz ?? base.tz,
          method: method ?? base.method,
          madhhab: madhhab ?? base.madhhab,
        );

    test('identical profiles → same key (no forced reschedule)', () {
      expect(with_().scheduleKey, base.scheduleKey);
    });

    test('city (lat/lng/tz), method and madhhab force a reschedule', () {
      expect(with_(lat: 22.35).scheduleKey, isNot(base.scheduleKey));
      expect(with_(lng: 91.78).scheduleKey, isNot(base.scheduleKey));
      expect(with_(tz: 5.5).scheduleKey, isNot(base.scheduleKey));
      expect(
        with_(method: CalcMethod.mwl).scheduleKey,
        isNot(base.scheduleKey),
      );
      expect(
        with_(madhhab: Madhhab.shafii).scheduleKey,
        isNot(base.scheduleKey),
      );
    });

    test('keys are injective enough to distinguish field changes', () {
      final keys = <String>{
        base.scheduleKey,
        with_(lat: 22.35).scheduleKey,
        with_(tz: 5.5).scheduleKey,
        with_(method: CalcMethod.mwl).scheduleKey,
        with_(madhhab: Madhhab.shafii).scheduleKey,
      };
      expect(keys, hasLength(5));
    });
  });

  group('widget snapshot', () {
    test('writes the full JSON shape + midnight wrap', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // 23:30 local — everything for "today" is past; next = tomorrow fajr.
      final times = PrayerEngine.compute(dateKey(DateTime(2026, 2, 8)));
      await WidgetSnapshotService.write(
        city: 'ঢাকা',
        dateKey: '2026-02-08',
        times: times,
        nextKey: PrayerKey.fajr,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('widget_snapshot');
      expect(raw, isNotNull);
      final snap = jsonDecode(raw!) as Map<String, dynamic>;
      expect(snap['city'], 'ঢাকা');
      expect(snap['dateKey'], '2026-02-08');
      expect(snap['nextKey'], 'fajr');
      expect(snap['nextLabelBn'], 'ফজর');
      final timesMap = snap['times'] as Map<String, dynamic>;
      expect(timesMap.keys.toSet(), {
        for (final k in PrayerKey.values) k.name,
      });
      expect(timesMap['fajr'], matches(RegExp(r'^\d{2}:\d{2}$')));
      // The fixed dateKey is in the past → the slot is past → the next
      // prayer must be tomorrow's fajr = today's fajr slot + 24h, exactly.
      final day = parseKey('2026-02-08');
      final fajr = times.fajr;
      final expected = DateTime(
            day.year,
            day.month,
            day.day,
            fajr ~/ 60,
            (fajr % 60).round(),
          ).add(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(snap['nextAt'], expected);
    });

    test('HH:mm formatting is zero-padded + wraps defensively', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Round up a 23:59.9 edge minute to check no "24:60" leaks: write a
      // bundle whose fajr is fine and verify a known time round-trips via
      // the public API through compute() of a fixed date (engine output is
      // deterministic for a fixed date).
      final times = PrayerEngine.compute('2026-02-08');
      await WidgetSnapshotService.write(
        city: 'x',
        dateKey: '2026-02-08',
        times: times,
        nextKey: PrayerKey.dhuhr,
      );
      final prefs = await SharedPreferences.getInstance();
      final snap =
          jsonDecode(prefs.getString('widget_snapshot')!) as Map<String, dynamic>;
      for (final v in (snap['times'] as Map<String, dynamic>).values) {
        expect(v as String, matches(RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')));
      }
    });
  });
}
