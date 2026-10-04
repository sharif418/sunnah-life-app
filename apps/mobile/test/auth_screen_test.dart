// The sign-in screen: typing a number enables "কোড পাঠান" (it used to stay
// disabled — the field never rebuilt the screen), the staging test code
// fills in one tap, "নম্বর বদলান" goes back, the code step hides the intro,
// and Google leads when available.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/auth/auth_screen.dart';
import 'package:sunnah_life/state/providers.dart';

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

class _Api extends ApiClient {
  String? sentTo;
  @override
  Future<OtpResponse> requestOtp(String phone) async {
    sentTo = phone;
    return const OtpResponse(ok: true, devCode: '482913');
  }
}

Future<_Api> _pump(WidgetTester tester, {bool google = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final api = _Api();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      authProvider.overrideWith(_Guest.new),
      apiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      theme: buildSunnahLightTheme(),
      home: AuthScreen(debugForceGoogle: google),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

FilledButton _btn(WidgetTester t, String key) => t.widget<FilledButton>(
  find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(FilledButton)),
);

void main() {
  testWidgets('number → code (one-tap fill) → change number', (tester) async {
    final api = await _pump(tester);
    expect(_btn(tester, 'auth_send').onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('auth_phone')), '০১৭১২৩৪৫৬৭৮'); // Bengali digits
    await tester.pump();
    expect(_btn(tester, 'auth_send').onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('auth_send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.sentTo, '01712345678');
    expect(find.text('পরীক্ষামূলক কোড: ৪৮২৯১৩'), findsOneWidget);
    expect(find.textContaining('সেকেন্ড পর আবার'), findsOneWidget);
    expect(_btn(tester, 'auth_verify').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('auth_dev_code_fill')));
    await tester.pump();
    expect(_btn(tester, 'auth_verify').onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('auth_change_number')));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth_phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth_code')), findsNothing);
  });

  testWidgets('Google leads when available; the phone button steps back to outlined', (tester) async {
    await _pump(tester, google: true);
    expect(find.text('Google দিয়ে চালিয়ে যান'), findsOneWidget);
    expect(find.text('অথবা মোবাইল নম্বর দিয়ে'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('auth_send')), matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
  });
}
