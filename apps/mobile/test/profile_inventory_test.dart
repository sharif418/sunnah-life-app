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

  @override
  Future<User> updateMe(Map<String, dynamic> patch) async {
    lastPatch = patch;
    return User.fromJson({..._member.toJson(), ...patch});
  }
}

Future<_FakeApi> _pump(WidgetTester tester, AuthNotifier Function() auth) async {
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
    expect(find.text('ঢাকা'), findsOneWidget);
    expect(find.text('যোগ করুন'), findsNWidgets(2)); // workplace + department

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

  testWidgets('guest: no register rows', (tester) async {
    await _pump(tester, _Guest.new);
    expect(find.byKey(const ValueKey('profile_field_workplace')), findsNothing);
  });
}
