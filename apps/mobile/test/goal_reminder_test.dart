// NAV-04: an approved goal's daily reminder — unset shows the button, a
// stored time reads "প্রতিদিন রাত ৯:০০"; ids are stable per goal and stay in
// their block.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/core/bell_schedule.dart' show Nid;
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/goal_reminder.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';

final _goal = PersonalGoal.fromJson({
  'id': 'g-1',
  'userId': 'u1',
  'amalKey': 'tilawat',
  'title': 'প্রতিদিন ২ পৃষ্ঠা তিলাওয়াত',
  'startDate': '2026-10-01',
  'active': true,
  'status': 'approved',
  'createdAt': '2026-10-01T00:00:00Z',
});

Future<void> _pump(WidgetTester tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(ProviderScope(
    overrides: [dbProvider.overrideWithValue(db)],
    child: MaterialApp(theme: buildSunnahLightTheme(), home: Scaffold(body: GoalReminderRow(goal: _goal))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('stable ids inside the goal block', () {
    expect(goalReminderNid('g-1'), goalReminderNid('g-1'));
    for (final id in ['a', 'g-1', 'cm9x0abc', 'zzzzzzzzzzzzzzzz']) {
      expect(goalReminderNid(id), inInclusiveRange(Nid.goalReminderBase, Nid.goalReminderBase + 499));
    }
  });

  testWidgets('no reminder yet → the button', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pump(tester);
    expect(find.text('রিমাইন্ডার দিন'), findsOneWidget);
  });

  testWidgets('a stored time reads daily at that time', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'goal_reminder_g-1': 21 * 60});
    await _pump(tester);
    expect(find.textContaining('প্রতিদিন'), findsOneWidget);
    expect(find.textContaining('৯:০০'), findsOneWidget);
  });
}
