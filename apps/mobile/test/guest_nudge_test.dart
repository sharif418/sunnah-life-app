// The weekly guest sign-up nudge: a guest sees it, "পরে" hides it for seven
// days, a member never sees it; the reminder lands on the next Friday 10:00.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/core/deep_links.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/home/guest_nudge.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

Future<void> _pump(WidgetTester tester, AuthNotifier Function() auth) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db), authProvider.overrideWith(auth)],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(body: ListView(children: const [GuestNudgeCard()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guest sees it; পরে hides it and records the time', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('guest_nudge')), findsOneWidget);
    expect(find.text('অ্যাকাউন্ট খুলুন'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guest_nudge_later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guest_nudge')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('sl_guest_nudge_dismissed_at'), isNotNull);
  });

  testWidgets('dismissed 3 days ago → hidden; 8 days ago → back', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sl_guest_nudge_dismissed_at': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
    });
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('guest_nudge')), findsNothing);
  });

  testWidgets('dismissed 8 days ago → shown again', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sl_guest_nudge_dismissed_at':
          DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
    });
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('guest_nudge')), findsOneWidget);
  });

  testWidgets('a signed-in member never sees it', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pump(tester, GoldenSignedInDaee.new);
    expect(find.byKey(const ValueKey('guest_nudge')), findsNothing);
  });

  test('the reminder lands on the next Friday 10:00', () {
    // Sat 2026-10-03 → Fri 2026-10-09
    expect(nextGuestNudgeAt(DateTime(2026, 10, 3, 9)), DateTime(2026, 10, 9, 10));
    // Friday before 10 → the same day; after 10 → a week later
    expect(nextGuestNudgeAt(DateTime(2026, 10, 9, 8)), DateTime(2026, 10, 9, 10));
    expect(nextGuestNudgeAt(DateTime(2026, 10, 9, 11)), DateTime(2026, 10, 16, 10));
  });

  test('the reminder deep link opens the sign-in screen', () {
    expect(deepLinkToRoute('/auth'), '/auth');
  });
}
