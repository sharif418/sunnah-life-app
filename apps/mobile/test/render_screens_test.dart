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
import 'dart:convert';
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
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/core/location_service.dart';
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

// SL_RENDER_VIEWPORTS="360x1.0,412x1.0" overrides (e.g. to match a
// prototype frame); default: a common phone + the small/large-text case.
final List<(double width, double textScale)> _viewports = () {
  final env = Platform.environment['SL_RENDER_VIEWPORTS'];
  if (env == null || env.isEmpty) return const [(412.0, 1.0), (360.0, 1.3)];
  return [
    for (final v in env.split(','))
      (double.parse(v.split('x')[0]), double.parse(v.split('x')[1])),
  ];
}();

/// Logical height of every capture — tall enough for most scroll content.
// SL_RENDER_HEIGHT=800 renders a real phone's height (sheets, FABs)
final double _height =
    double.tryParse(Platform.environment['SL_RENDER_HEIGHT'] ?? '') ?? 2000;

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

  // SL_RENDER_PREFS='{"key":"json string"}' seeds the phone's storage (e.g.
  // a starred mosque); SL_RENDER_TAP='text' taps that text once the screen
  // has settled (open a sheet, switch a tab) — both on demand only.
  final seededPrefs = <String, Object>{
    for (final e
        in ((Platform.environment['SL_RENDER_PREFS'] ?? '').isEmpty
                ? <String, dynamic>{}
                : jsonDecode(Platform.environment['SL_RENDER_PREFS']!)
                      as Map<String, dynamic>)
            .entries)
      e.key: e.value as Object,
  };
  // SL_RENDER_TAP may list several steps: 'text|tip:tooltip|text'
  final tapText = Platform.environment['SL_RENDER_TAP'];
  // SL_RENDER_ADJUST='{"maghrib":5}' seeds the profile's ± minutes
  final seededAdjust = Platform.environment['SL_RENDER_ADJUST'];
  final suffix = Platform.environment['SL_RENDER_SUFFIX'] ?? '';
  // SL_RENDER_GPS=1: the phone has location (else it has none)
  final gps = Platform.environment['SL_RENDER_GPS'] == '1';
  // SL_RENDER_CONTACTS=1: the server's real contacts (mounts the headset FAB)
  final contacts = Platform.environment['SL_RENDER_CONTACTS'] == '1';

  setUp(() {
    SharedPreferences.setMockInitialValues(seededPrefs);
  });

  for (final path in paths) {
    for (final theme in themes) {
      for (final (width, scale) in _viewports) {
        final name =
            '${_slug(path)}${suffix}_${theme}_${width.toInt()}w_${scale}x';
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
                prayerAdjust: seededAdjust == null
                    ? const Value.absent()
                    : Value(seededAdjust),
              ),
            );
            final container = ProviderContainer(
              overrides: [
                dbProvider.overrideWithValue(db),
                authProvider.overrideWith(GoldenSignedInDaee.new),
                prayerProvider.overrideWith(GoldenPinnedPrayer.new),
                headerNowProvider.overrideWithValue(kGoldenNow),
                apiProvider.overrideWithValue(
                  contacts ? _ContactsApi() : GoldenApi(),
                ),
                locationServiceProvider.overrideWithValue(
                  FakeLocation(granted: gps),
                ),
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
            for (final step in (tapText ?? '').split('|')) {
              if (step.isEmpty) continue;
              final target = step.startsWith('tip:')
                  ? find.byTooltip(step.substring(4))
                  : step.startsWith('sem:')
                  ? find.bySemanticsLabel(step.substring(4))
                  : find.text(step);
              await tester.ensureVisible(target.first);
              await tester.pumpAndSettle();
              await tester.tap(target.first);
              try {
                await tester.pumpAndSettle(
                  const Duration(milliseconds: 100),
                  EnginePhase.sendSemanticsUpdate,
                  const Duration(seconds: 5),
                );
              } on FlutterError {
                await tester.pump(const Duration(seconds: 1));
              }
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

/// The app config as the server sends it (packages/content/app-config.json).
class _ContactsApi extends GoldenApi {
  @override
  Future<AppConfig> config() async => AppConfig.fromJson(
    jsonDecode(
          File('../../packages/content/app-config.json').readAsStringSync(),
        )
        as Map<String, dynamic>,
  );
}
