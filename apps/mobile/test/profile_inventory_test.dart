// The Dawatus Sunnah member register on the profile: a signed-in member sees
// workplace / department / district ("যোগ করুন" when empty), edits one
// through PATCH /api/me and the screen shows the saved value. Guests never
// see these rows (the register belongs to the account).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/more/profile_screen.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';

const _member = User(
  id: 'u1',
  name: 'টেস্ট সদস্য',
  gender: Gender.m,
  role: Role.daee,
  category: UserCategory.general,
  district: 'ঢাকা',
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: _member);
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

class _FakeApi extends ApiClient {
  Map<String, dynamic>? lastPatch;
  String? codeSentTo;

  @override
  Future<String?> requestPhoneChange(String phone) async {
    codeSentTo = phone;
    return '123456'; // the dev mock code
  }

  @override
  Future<User> verifyPhoneChange(String phone, String code) async {
    if (code != '123456') throw ApiException(400, 'ভুল কোড');
    return User.fromJson({..._member.toJson(), 'phone': phone});
  }

  @override
  Future<User> updateMe(Map<String, dynamic> patch) async {
    lastPatch = patch;
    return User.fromJson({..._member.toJson(), ...patch});
  }
}

Future<_FakeApi> _pump(WidgetTester tester, AuthNotifier Function() auth) async {
  // a tall surface: the profile is one long list
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = _FakeApi();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(api),
        authProvider.overrideWith(auth),
      ],
      child: MaterialApp(theme: buildSunnahLightTheme(), home: const ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'Sunnah Life',
      packageName: 'app.sunnahlife',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('signed-in: register rows show, an edit saves via PATCH /api/me',
      (tester) async {
    final api = await _pump(tester, _SignedIn.new);
    final workplace = find.byKey(const ValueKey('profile_field_workplace'));
    expect(workplace, findsOneWidget);
    expect(find.byKey(const ValueKey('profile_field_department')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_field_district')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile_field_district')),
        matching: find.text('ঢাকা'),
      ),
      findsOneWidget,
    );
    expect(find.text('যোগ করুন'), findsNWidgets(4)); // phone, email, workplace, department

    await tester.ensureVisible(workplace);
    await tester.tap(workplace);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile_edit_workplace')),
      ' আস-সুন্নাহ ফাউন্ডেশন ',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(api.lastPatch, {'workplace': 'আস-সুন্নাহ ফাউন্ডেশন'});
    expect(find.text('আস-সুন্নাহ ফাউন্ডেশন'), findsOneWidget);
    expect(find.text('সংরক্ষিত হয়েছে'), findsOneWidget);
  });

  testWidgets('phone: number → code → the account moves to it', (tester) async {
    final api = await _pump(tester, _SignedIn.new);
    await tester.ensureVisible(find.byKey(const ValueKey('profile_field_phone')));
    await tester.tap(find.byKey(const ValueKey('profile_field_phone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('phone_change_number')), '01799990003');
    await tester.tap(find.byKey(const ValueKey('phone_change_submit')));
    await tester.pumpAndSettle();
    expect(api.codeSentTo, '01799990003');
    // the dev code is pre-filled; confirm
    await tester.tap(find.byKey(const ValueKey('phone_change_submit')));
    await tester.pumpAndSettle();
    expect(find.text('মোবাইল নম্বর পরিবর্তন হয়েছে'), findsOneWidget);
    expect(find.text('০১৭৯৯৯৯০০০৩'), findsOneWidget);
  });

  testWidgets('e-mail edits through PATCH /api/me', (tester) async {
    final api = await _pump(tester, _SignedIn.new);
    await tester.ensureVisible(find.byKey(const ValueKey('profile_field_email')));
    await tester.tap(find.byKey(const ValueKey('profile_field_email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile_edit_email')), 'a@b.org');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(api.lastPatch, {'email': 'a@b.org'});
  });

  testWidgets('guest: no register rows', (tester) async {
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('profile_field_workplace')), findsNothing);
  });
}
