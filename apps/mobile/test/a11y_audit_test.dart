// Accessibility audit (TalkBack / large text / low vision) — on demand.
//
// Boots the real app over the golden fixtures (as render_screens_test does),
// opens each route and runs Flutter's accessibility guidelines:
//   • tap targets ≥ 44×44 dp (the DESIGN.md minimum; Android's own is 48)
//   • labeledTapTargetGuideline  — every tappable has a spoken label
//   • textContrastGuideline      — text ≥ 4.5:1 (3:1 large)
// Findings go to SL_A11Y_DIR/<route>.txt; the test fails for a route that
// has any, so the summary lists them. Skipped unless SL_A11Y_DIR is set.
//
//   SL_A11Y_DIR=/tmp/a11y flutter test test/a11y_audit_test.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';
import 'golden_fonts.dart';

const List<String> _paths = [
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
  '/more/live',
  '/more/zakat',
  '/more/support',
  '/more/about',
];

void main() {
  final outDir = Platform.environment['SL_A11Y_DIR'];
  final paths = Platform.environment['SL_A11Y_PATHS']?.split(',') ?? _paths;

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final path in paths) {
    final slug = path == '/' ? 'home' : path.substring(1).replaceAll('/', '_');
    testWidgets(
      'a11y $slug',
      (tester) async {
        tester.view.physicalSize = const Size(412 * 2, 900 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.guestProfile();
        await db.saveGuestProfile(
          const GuestProfilesCompanion(onboardingDone: Value(true)),
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
        await warmAppFonts(tester);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const BootstrapGate(),
          ),
        );
        await tester.pumpAndSettle();
        container.read(routerProvider).go(path);
        try {
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );
        } on FlutterError {
          await tester.pump(const Duration(seconds: 1));
        }

        final findings = <String>[];
        for (final (name, g) in [
          (
            'tap target',
            const MinimumTapTargetGuideline(
              size: Size(44, 44),
              link: 'DESIGN.md — reachable and readable',
            ),
          ),
          ('label', labeledTapTargetGuideline),
          ('contrast', textContrastGuideline),
        ]) {
          final result = await g.evaluate(tester);
          if (!result.passed) findings.add('## $name\n${result.reason}');
        }
        final file = File('$outDir/$slug.txt');
        await tester.runAsync(() async {
          await file.parent.create(recursive: true);
          if (findings.isEmpty) {
            if (file.existsSync()) await file.delete();
          } else {
            await file.writeAsString(findings.join('\n\n'));
          }
        });
        semantics.dispose();
        container.dispose();
        expect(findings, isEmpty, reason: findings.join('\n'));
      },
      skip: outDir == null,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
