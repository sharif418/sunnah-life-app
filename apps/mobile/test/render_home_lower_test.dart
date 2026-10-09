// On-demand renders of the lower home (design review, not a regression test
// — skipped unless SL_RENDER_DIR is set): the schedule card's foot, the guest
// nudge under it, the most-used list, and the live cards in every state.
//
//   SL_RENDER_DIR=/tmp/lower flutter test test/render_home_lower_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/most_used.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/design/phosphor_icons.dart';
import 'package:sunnah_life/features/home/guest_nudge.dart';
import 'package:sunnah_life/features/home/home_screen.dart';
import 'package:sunnah_life/features/home/home_sections.dart';
import 'package:sunnah_life/features/home/schedule_card.dart';
import 'package:sunnah_life/features/shared/live_program_card.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
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

AmalDefinition def(String key, String bn, AmalCategory c, AmalInputType t) =>
    AmalDefinition(
      key: key,
      titleBn: bn,
      titleEn: key,
      category: c,
      inputType: t,
      cadence: 'daily',
    );

void main() {
  final outDir = Platform.environment['SL_RENDER_DIR'];
  final now = DateTime(2026, 10, 7, 16);
  final cases = [
    ('lower_light_412', false, 1.0),
    ('lower_dark_412', true, 1.0),
    ('lower_light_360_13', false, 1.3),
  ];

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final (name, dark, scale) in cases) {
    testWidgets(name, (tester) async {
      final width = scale > 1 ? 360.0 : 412.0;
      tester.view.physicalSize = Size(width * 2, 2600 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          guestNudgeDueProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);
      await warmAppFonts(tester);

      final values = <String, Object?>{'tilawat': 3, 'adhkar_morning': true};
      final programs = [
        const LiveProgramItem(
          id: 'u1',
          titleBn: 'সাপ্তাহিক তাফসির মাহফিল — সূরা আল-কাহফ',
          hostName: 'শায়খ আহমাদুল্লাহ',
          startsAt: '2026-10-08T14:00:00.000Z',
          gender: Gender.m,
          status: 'upcoming',
        ),
        const LiveProgramItem(
          id: 'l1',
          titleBn: 'জুমার আলোচনা',
          hostName: 'মাওলানা অমুক',
          startsAt: '2026-10-07T08:00:00.000Z',
          gender: Gender.m,
          status: 'live',
          youtubeId: 'abc',
          quizId: 'q1',
        ),
        const LiveProgramItem(
          id: 'u2',
          titleBn: 'বোনদের তারবিয়াহ সেশন',
          startsAt: '2026-10-20T05:00:00.000Z',
          gender: Gender.f,
          status: 'upcoming',
        ),
        const LiveProgramItem(
          id: 'p1',
          titleBn: 'গত সপ্তাহের দারস',
          startsAt: '2026-09-30T14:00:00.000Z',
          gender: Gender.m,
          status: 'past',
          youtubeId: 'xyz',
        ),
      ];

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PrayerScheduleCard(
                          prayer: nowAt('2026-10-07', 16 * 60.0),
                          bells: const {'fajr', 'tahajjud'},
                          bn: true,
                          friday: false,
                          ramadan: false,
                          onBell: (_) {},
                          onBellLongPress: (_) {},
                        ),
                        const GuestNudgeCard(),
                        PostPrayerPrompt(
                          prayer: () {
                            final n = nowAt('2026-10-07', 16 * 60.0);
                            return PrayerNow(
                              dateKey: n.dateKey,
                              times: n.times,
                              nowMinutes: n.nowMinutes,
                              currentWaqt: n.currentWaqt,
                              nextKey: n.nextKey,
                              minutesToNext: n.minutesToNext,
                              forbiddenLabel: n.forbiddenLabel,
                              postPrayerKey: PrayerKey.asr,
                            );
                          }(),
                          bn: true,
                        ),
                        SectionHeader(
                          S.tr(Lang.bn, 'most_used'),
                          icon: PhosphorIconsFill.fire,
                        ),
                        MostUsedList(
                          items: [
                            MostUsedAmal(
                              def: def(
                                'salat_fajr',
                                'ফজর নামাজ',
                                AmalCategory.salah,
                                AmalInputType.tristate,
                              ),
                              daysUsed: 3,
                            ),
                            MostUsedAmal(
                              def: def(
                                'tilawat',
                                'কুরআন তিলাওয়াত',
                                AmalCategory.quran,
                                AmalInputType.count,
                              ),
                              daysUsed: 3,
                            ),
                            MostUsedAmal(
                              def: def(
                                'adhkar_morning',
                                'সকালের যিকির',
                                AmalCategory.dhikr,
                                AmalInputType.boolean,
                              ),
                              daysUsed: 2,
                            ),
                          ],
                          valueOf: (k) => values[k],
                          lang: Lang.bn,
                          category: UserCategory.general,
                          onQuickLog: (_, _) {},
                        ),
                        SectionHeader(S.tr(Lang.bn, 'more_live')),
                        for (final p in programs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LiveProgramCard(
                              program: p,
                              now: now,
                              onTap: () {},
                              onRemind: () {},
                              onJoinQuiz: () {},
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
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
