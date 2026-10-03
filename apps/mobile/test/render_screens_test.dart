// On-demand screen renderer for design review — NOT a regression test.
//
// Skipped unless SL_RENDER_DIR is set, so CI never runs it. It boots the real
// app over the deterministic golden fixtures (pinned clock, frozen prayer
// times, a signed-in da'ee, fake ApiClient) with the real fonts warmed, then
// writes one PNG per route × theme × viewport into SL_RENDER_DIR:
//
//   <slug>_<light|dark>_<width>w_<scale>x.png
//
// Viewports: 412dp at 1.0x text (a common Android phone) and 360dp at 1.3x
// text (small phone, large-text user) — the two the design checklist asks
// for. Run from apps/mobile:
//
//   SL_RENDER_DIR=/tmp/sl-screens flutter test test/render_screens_test.dart
//   SL_RENDER_DIR=/tmp/sl-screens SL_RENDER_PATHS=/amal,/amal/month \
//     flutter test test/render_screens_test.dart
//
// Text renders on Windows/macOS exactly as on the Linux CI except for
// anti-aliasing, which is irrelevant for review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';
import 'golden_fonts.dart';

const List<String> _defaultPaths = [
  '/',
  '/amal',
  '/amal/month',
  '/amal/habit',
  '/amal/self-test',
  '/amal/goals',
  '/dawah',
  '/dawah/requirements',
  '/dawah/questions',
  '/ilm',
  '/ilm/quran',
  '/ilm/adhkar',
  '/ilm/duas',
  '/ilm/courses',
  '/ilm/quizzes',
  '/more',
  '/more/profile',
  '/more/live',
  '/more/zakat',
  '/more/qibla',
  '/more/mosques',
  '/more/support',
  '/more/about',
];

const List<(double width, double textScale)> _viewports = [
  (412, 1.0),
  (360, 1.3),
];

/// Logical height of every capture — tall enough for most scroll content.
const double _height = 2000;

String _slug(String path) =>
    path == '/' ? 'home' : path.substring(1).replaceAll('/', '_');

void main() {
  final outDir = Platform.environment['SL_RENDER_DIR'];
  final paths =
      Platform.environment['SL_RENDER_PATHS']
          ?.split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList() ??
      _defaultPaths;
  final themes =
      Platform.environment['SL_RENDER_THEMES']?.split(',') ??
      const ['light', 'dark'];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final path in paths) {
    for (final theme in themes) {
      for (final (width, scale) in _viewports) {
        final name = '${_slug(path)}_${theme}_${width.toInt()}w_${scale}x';
        testWidgets(
          name,
          (tester) async {
            tester.view.physicalSize = Size(width * 2, _height * 2);
            tester.view.devicePixelRatio = 2.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final db = AppDatabase.forTesting(NativeDatabase.memory());
            addTearDown(db.close);
            await db.guestProfile();
            await db.saveGuestProfile(
              GuestProfilesCompanion(
                onboardingDone: const Value(true),
                themeMode: Value(theme),
              ),
            );
            final container = ProviderContainer(
              overrides: [
                dbProvider.overrideWithValue(db),
                authProvider.overrideWith(GoldenSignedInDaee.new),
                prayerProvider.overrideWith(GoldenPinnedPrayer.new),
                headerNowProvider.overrideWithValue(kGoldenNow),
                apiProvider.overrideWithValue(GoldenApi()),
              ],
            );

            // Layout errors (overflow, bad ParentData) are FINDINGS, not
            // reasons to lose the picture: collect them into <name>.errors.txt
            // and keep rendering. The test still fails so the run summary
            // lists every screen that has one.
            final errors = <String>[];
            final previousOnError = FlutterError.onError;
            FlutterError.onError = (details) => errors.add(
              [
                details.exceptionAsString(),
                ...?details.informationCollector?.call().take(3),
              ].join('\n'),
            );

            await warmAppFonts(tester);
            // Material icons (BackButton, checkmarks) ship with the SDK, not
            // the app; without them every back arrow renders as a tofu box.
            await tester.runAsync(() async {
              final font = File(
                '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
                'material_fonts/materialicons-regular.otf',
              );
              if (font.existsSync()) {
                final bytes = ByteData.sublistView(await font.readAsBytes());
                await (FontLoader(
                  'MaterialIcons',
                )..addFont(Future.value(bytes))).load();
              }
            });
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const BootstrapGate(),
              ),
            );
            await tester.pumpAndSettle();
            container.read(routerProvider).go(path);
            // Screens with a live ticker (Qur'an audio, compass) never
            // settle — fall back to a fixed pump.
            try {
              await tester.pumpAndSettle(
                const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 5),
              );
            } on FlutterError {
              await tester.pump(const Duration(seconds: 1));
            }

            final element = find.byType(MaterialApp).evaluate().single;
            await tester.runAsync(() async {
              final image = await captureImage(element);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$outDir/$name.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              final log = File('$outDir/$name.errors.txt');
              if (errors.isEmpty) {
                if (log.existsSync()) await log.delete();
              } else {
                await log.writeAsString(errors.join('\n\n---\n\n'));
              }
            });
            FlutterError.onError = previousOnError;
            expect(errors, isEmpty, reason: errors.join('\n---\n'));

            // Inside the body — cancels the periodic sync-flush timer in time.
            container.dispose();
          },
          skip: outDir == null,
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    }
  }
}
