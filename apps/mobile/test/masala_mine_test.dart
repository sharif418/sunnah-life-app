// মাসআলা: a signed-in member sees their questions — answered ones with the
// answer, pending ones marked; guests see only the form.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/more/masala_screen.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

class _Api extends ApiClient {
  @override
  Future<List<MasalaItem>> myMasala() async => [
    MasalaItem.fromJson({'id': 'a', 'question': 'বিতর কত রাকাত?', 'status': 'answered', 'answer': 'তিন রাকাত।', 'createdAt': '2026-10-01T05:00:00Z'}),
    MasalaItem.fromJson({'id': 'b', 'question': 'তাহাজ্জুদের সময় কখন?', 'status': 'new', 'createdAt': '2026-10-03T05:00:00Z'}),
  ];
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

Future<void> _pump(WidgetTester tester, AuthNotifier Function() auth) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(ProviderScope(
    overrides: [dbProvider.overrideWithValue(db), authProvider.overrideWith(auth), apiProvider.overrideWithValue(_Api())],
    child: MaterialApp(theme: buildSunnahLightTheme(), home: const MasalaScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('member: questions with answers and the pending one', (tester) async {
    await _pump(tester, GoldenSignedInDaee.new);
    expect(find.text('আমার প্রশ্ন ও উত্তর'), findsOneWidget);
    expect(find.text('তিন রাকাত।'), findsOneWidget);
    expect(find.text('উত্তর এসেছে'), findsOneWidget);
    expect(find.text('উত্তরের অপেক্ষায়'), findsOneWidget);
  });

  testWidgets('guest: the form only', (tester) async {
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('masala_mine')), findsNothing);
  });
}
