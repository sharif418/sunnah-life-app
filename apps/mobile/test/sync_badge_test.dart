// The header sync badge: members see it only when they should know — entries
// that could not be saved, or entries waiting because the last upload did
// not go through (offline). An ordinary upload is silent. Guests never (their
// diary is local by design).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

class _Sync extends SyncNotifier {
  _Sync(this.s);
  final SyncState s;
  @override
  SyncState build() => s;
}

Future<void> _pump(WidgetTester tester, AuthNotifier Function() auth, SyncState s) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      authProvider.overrideWith(auth),
      syncProvider.overrideWith(() => _Sync(s)),
    ],
    child: MaterialApp(theme: buildSunnahLightTheme(), home: const Scaffold(body: Center(child: SyncBadge()))),
  ));
  await tester.pump();
}

void main() {
  testWidgets('guest with pending rows: nothing shown', (tester) async {
    await _pump(tester, _Guest.new, const SyncState(pending: 3));
    expect(find.byType(Icon), findsNothing);
    expect(find.text('৩'), findsNothing);
  });

  testWidgets('member, an ordinary upload under way: quiet', (tester) async {
    await _pump(tester, GoldenSignedInDaee.new, const SyncState(pending: 3, syncing: true));
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('member offline with waiting rows: says so', (tester) async {
    await _pump(tester, GoldenSignedInDaee.new, const SyncState(pending: 3, stalled: true));
    expect(find.text('৩ অপেক্ষায়'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('৩ টি আমল ইন্টারনেট পেলে জমা হবে')), findsOneWidget);
  });

  testWidgets('entries that could not be saved: red, with the word', (tester) async {
    await _pump(tester, GoldenSignedInDaee.new, const SyncState(dead: 2));
    expect(find.text('২ সমস্যা'), findsOneWidget);
  });

  testWidgets('member, nothing pending: quiet', (tester) async {
    await _pump(tester, GoldenSignedInDaee.new, const SyncState());
    expect(find.byType(Icon), findsNothing);
  });
}
