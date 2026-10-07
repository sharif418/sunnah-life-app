// On-demand renders of the home prayer card + schedule card at the parts of
// the day a single pinned clock never shows (design review, not a
// regression test — skipped unless SL_RENDER_DIR is set):
//
//   SL_RENDER_DIR=/tmp/cards flutter test test/render_cards_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/home/home_sections.dart';
import 'package:sunnah_life/features/home/schedule_card.dart';
import 'package:sunnah_life/features/home/sun_arc_card.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fonts.dart';

PrayerNow nowAt(String date, double minutes) {
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

void main() {
  final outDir = Platform.environment['SL_RENDER_DIR'];
  // (name, date, minutes, friday, ramadan, dark, textScale, diary)
  final cases = [
    ('pre_fajr_isha', '2026-10-07', 3 * 60.0 + 50, false, false, false, 1.0),
    (
      'sunrise_forbidden',
      '2026-10-07',
      5 * 60.0 + 58,
      false,
      false,
      false,
      1.0,
    ),
    ('gap_morning', '2026-10-07', 8 * 60.0 + 20, false, false, false, 1.0),
    ('zawal_forbidden', '2026-10-07', 11 * 60.0 + 40, false, false, false, 1.0),
    ('friday_jumuah', '2026-10-09', 13 * 60.0, true, false, false, 1.0),
    ('asr_dark', '2026-10-07', 17 * 60.0 + 20, false, false, true, 1.0),
    ('night_isha', '2026-10-07', 20 * 60.0 + 30, false, false, false, 1.0),
    ('ramadan', '2027-02-20', 18 * 60.0 + 10, false, true, false, 1.0),
    (
      'night_large_text',
      '2026-10-07',
      20 * 60.0 + 30,
      false,
      false,
      false,
      1.3,
    ),
  ];

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final (name, date, minutes, friday, ramadan, dark, scale) in cases) {
    testWidgets('card $name', (tester) async {
      final width = scale > 1 ? 360.0 : 412.0;
      tester.view.physicalSize = Size(width * 2, 1900 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await warmAppFonts(tester);
      final prayer = nowAt(date, minutes);
      const keys = [
        PrayerKey.fajr,
        PrayerKey.dhuhr,
        PrayerKey.asr,
        PrayerKey.maghrib,
        PrayerKey.isha,
      ];
      const recorded = ['jamaat', 'alone', 'qaza', null, null];
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? buildSunnahDarkTheme() : buildSunnahLightTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    color: dark
                        ? SLColors.darkBackground
                        : SLColors.lightBackground,
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (context) => Column(
                        children: [
                          SunArcPrayerCard(
                            prayer: prayer,
                            bn: true,
                            friday: friday,
                            onShowSchedule: () {},
                            todayPrayers: [
                              for (var i = 0; i < 5; i++)
                                HeroPrayerStatus(
                                  label: waqtLabel(
                                    context,
                                    keys[i],
                                    friday: friday,
                                  ),
                                  value:
                                      prayer.nowMinutes >=
                                          prayer.times.byKey(keys[i])
                                      ? recorded[i]
                                      : null,
                                  started:
                                      prayer.nowMinutes >=
                                      prayer.times.byKey(keys[i]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PrayerScheduleCard(
                            prayer: prayer,
                            bells: const {'fajr', 'dhuhr', 'asr', 'tahajjud'},
                            bn: true,
                            friday: friday,
                            ramadan: ramadan,
                            onBell: (_) {},
                            onBellLongPress: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('$outDir/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }, skip: outDir == null);
  }
}
