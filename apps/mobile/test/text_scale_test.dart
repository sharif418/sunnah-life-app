// Text-scale safety (WCAG 1.4.4) — the Amal hub (Today diary) must lay out
// without overflow at 1.3× text scale: no fixed heights on text containers,
// rows grow with the ambient TextScaler.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/today_screen.dart';
import 'package:sunnah_life/state/providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('Amal hub lays out cleanly at ${scale}x text scale',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildSunnahLightTheme(),
            home: const AmalHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fallback catalog (guest) renders the salat rows in Bengali.
      expect(find.text('আজকের আমল'), findsOneWidget);

      // A RenderFlex overflow throws in tests — none may be pending.
      expect(tester.takeException(), isNull);
    });
  }
}
