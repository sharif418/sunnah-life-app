// The redesigned home cards (2026-10-07): what each must say and do, so a
// later change cannot silently drop a feature (the nafl bells, Friday's
// Jumu'ah, Ramadan's Sehri/Iftar, the forbidden-window warning).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/home/schedule_card.dart';
import 'package:sunnah_life/features/home/sun_arc_card.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

PrayerNow nowAt(double minutes, {String date = '2026-10-07'}) {
  final times = PrayerEngine.compute(
    date,
    lat: 23.8103,
    lng: 90.4125,
    tz: 6,
    method: CalcMethod.karachi,
    madhhab: Madhhab.hanafi,
  );
  final (next, mins) = PrayerEngine.nextPrayer(times, minutes);
  return PrayerNow(
    dateKey: date,
    times: times,
    nowMinutes: minutes,
    currentWaqt: PrayerEngine.currentWaqt(times, minutes),
    nextKey: next,
    minutesToNext: mins,
    forbiddenLabel: PrayerEngine.inForbiddenWindow(times, minutes),
    postPrayerKey: null,
  );
}

Future<void> pumpIn(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(412 * 3, 2000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [dbProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

String tr(String key) => S.tr(Lang.bn, key);

void main() {
  group('schedule card', () {
    testWidgets(
      'every time keeps its bell: tap → timing, long-press → toggle',
      (tester) async {
        final tapped = <PrayerKey>[];
        final held = <PrayerKey>[];
        await pumpIn(
          tester,
          PrayerScheduleCard(
            prayer: nowAt(15 * 60.0),
            bells: const {'fajr', 'tahajjud'},
            bn: true,
            friday: false,
            ramadan: false,
            onBell: tapped.add,
            onBellLongPress: held.add,
          ),
        );
        // five fard rows + four nafl cells, each with its own bell
        for (final k in [
          PrayerKey.fajr,
          PrayerKey.dhuhr,
          PrayerKey.asr,
          PrayerKey.maghrib,
          PrayerKey.isha,
          PrayerKey.sunrise,
          PrayerKey.ishraq,
          PrayerKey.duha,
          PrayerKey.tahajjud,
        ]) {
          final row = find.byKey(ValueKey('schedule_row_${k.name}'));
          expect(row, findsOneWidget, reason: k.name);
          final bell = find.descendant(
            of: row,
            matching: find.byType(PrayerBellButton),
          );
          expect(bell, findsOneWidget, reason: '${k.name} lost its bell');
          await tester.tap(bell);
          await tester.longPress(bell);
        }
        expect(tapped.length, 9);
        expect(held.length, 9);
        expect(tapped, contains(PrayerKey.duha));
        // the forbidden windows live in the same card
        expect(
          find.byKey(const ValueKey('home_forbidden_card')),
          findsOneWidget,
        );
        expect(find.text(tr('prayer_forbidden_title')), findsOneWidget);
        expect(find.byKey(const ValueKey('schedule_ramadan')), findsNothing);
      },
    );

    testWidgets('Friday reads জুমা; Ramadan adds Sehri and Iftar', (
      tester,
    ) async {
      await pumpIn(
        tester,
        PrayerScheduleCard(
          prayer: nowAt(13 * 60.0, date: '2026-10-09'),
          bells: const {},
          bn: true,
          friday: true,
          ramadan: true,
          onBell: (_) {},
          onBellLongPress: (_) {},
        ),
      );
      expect(find.text(tr('jumuah')), findsOneWidget);
      expect(find.text(tr('waqt_dhuhr')), findsNothing);
      expect(find.byKey(const ValueKey('schedule_ramadan')), findsOneWidget);
      expect(find.textContaining(tr('sched_sehri_end')), findsOneWidget);
      expect(find.textContaining(tr('sched_iftar')), findsOneWidget);
    });
  });

  group('prayer card', () {
    testWidgets('after sunrise: no fard runs, the forbidden window is named', (
      tester,
    ) async {
      final prayer = nowAt(prayerMinutes(sunriseOffset: 5));
      await pumpIn(
        tester,
        SunArcPrayerCard(prayer: prayer, bn: true, friday: false),
      );
      expect(
        (tester.widget(
          find.byKey(const ValueKey('home_sun_now')),
        ) as Text).data,
        tr('sun_after_sunrise'),
      );
      expect(find.byKey(const ValueKey('home_forbidden_now')), findsOneWidget);
      expect(find.text(tr('sun_wait_dhuhr')), findsOneWidget);
    });

    testWidgets('mid-afternoon: the running waqt, no warning; Friday is জুমা', (
      tester,
    ) async {
      await pumpIn(
        tester,
        SunArcPrayerCard(
          prayer: nowAt(13 * 60.0, date: '2026-10-09'),
          bn: true,
          friday: true,
          onShowSchedule: () {},
        ),
      );
      expect(
        (tester.widget(
          find.byKey(const ValueKey('home_sun_now')),
        ) as Text).data,
        tr('jumuah'),
      );
      expect(find.byKey(const ValueKey('home_forbidden_now')), findsNothing);
      expect(find.byKey(const ValueKey('home_to_schedule')), findsOneWidget);
    });
  });
}

/// A minute a few minutes after today's sunrise (inside its forbidden window).
double prayerMinutes({required int sunriseOffset}) =>
    nowAt(0).times.sunrise + sunriseOffset;
