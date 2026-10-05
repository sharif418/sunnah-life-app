// AMOL-14 exercise log: a session adds its minutes to the day's diary
// amal (exercise_minutes) — the log is never a second source of truth —
// and undoing it takes them back off.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/features/amal/exercise_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

void main() {
  group('session storage', () {
    test('round-trips and keeps only the last 14 days', () {
      final at = DateTime(2025, 6, 15, 7, 30);
      final byDate = {
        '2025-06-15': [ExerciseSession(type: 'run', minutes: 25, at: at)],
        '2025-05-01': [ExerciseSession(type: 'walk', minutes: 10, at: at)],
      };
      final decoded = decodeExerciseSessions(
        encodeExerciseSessions(byDate, '2025-06-15'),
      );
      expect(decoded.keys, ['2025-06-15']);
      expect(decoded['2025-06-15']!.single.minutes, 25);
      expect(decoded['2025-06-15']!.single.type, 'run');
    });

    test('corrupt or foreign data reads as empty, never a crash', () {
      expect(decodeExerciseSessions(null), isEmpty);
      expect(decodeExerciseSessions('not json'), isEmpty);
      expect(decodeExerciseSessions('[1,2]'), isEmpty);
      expect(
        decodeExerciseSessions(
          '{"2025-06-15":[{"t":"run"},{"m":"x"}]}',
        )['2025-06-15'],
        isEmpty,
      );
    });

    test('diary values of any shape read as whole minutes', () {
      expect(exerciseMinutesOf(null), 0);
      expect(exerciseMinutesOf(20), 20);
      expect(exerciseMinutesOf(12.6), 13);
      expect(exerciseMinutesOf('30'), 30);
    });
  });

  testWidgets('add → today\'s diary entry grows; undo → back to zero', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExerciseScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final today = dateKey(DateTime.now());

    await tester.tap(find.byKey(const ValueKey('exercise_type_run')));
    await tester.tap(find.text(toBn(30)));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('exercise_add_button')),
    );
    await tester.tap(find.byKey(const ValueKey('exercise_add_button')));
    await tester.pumpAndSettle();

    expect(
      container.read(amalProvider).entries[today]?[kExerciseAmalKey]?.value,
      30,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exercise_today_minutes')),
      -300,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('exercise_today_minutes')))
          .data,
      toBn(30),
    );
    expect(find.text(S.tr(Lang.bn, 'exercise_type_run')), findsWidgets);

    // the session is listed; removing it takes the minutes back off
    final undo = find.byTooltip(S.tr(Lang.bn, 'exercise_undo'));
    await tester.scrollUntilVisible(undo, 300);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(
      container.read(amalProvider).entries[today]?[kExerciseAmalKey]?.value,
      0,
    );
    expect(undo, findsNothing);
  });
}
