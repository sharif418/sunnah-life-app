// Google Play's account-deletion rule, in the app: a signed-in member finds
// "অ্যাকাউন্ট মুছে ফেলুন" on the profile; the sheet says what goes and what
// stays; the red button stays disabled until the member ticks that they
// understand; deleting calls DELETE /api/me, wipes the diary from the phone
// and signs out. A server refusal (a usrah head) is shown, nothing is wiped.
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
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';

const _member = User(
  id: 'u1',
  name: 'টেস্ট সদস্য',
  gender: Gender.m,
  role: Role.daee,
  category: UserCategory.general,
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

class _Api extends ApiClient {
  _Api({this.refuse});
  final String? refuse;
  int deletes = 0;

  @override
  Future<void> deleteMe() async {
    deletes++;
    if (refuse != null) throw ApiException(409, refuse!);
  }
}

Future<(_Api, AppDatabase, ProviderContainer)> _pump(
  WidgetTester tester, {
  AuthNotifier Function() auth = _SignedIn.new,
  String? refuse,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = _Api(refuse: refuse);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      apiProvider.overrideWithValue(api),
      authProvider.overrideWith(auth),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildSunnahLightTheme(), home: const ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (api, db, container);
}

Future<void> _seedDiary(AppDatabase db) => db.into(db.amalEntries).insert(
      AmalEntriesCompanion.insert(
        amalKey: 'salat_fajr',
        date: '2025-01-01',
        valueJson: '"jamaat"',
        source: 'manual',
        clientUpdatedAt: DateTime.utc(2025, 1, 1, 5),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'Sunnah Life',
      packageName: 'bd.asunnah.sunnah_life',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  String t(String k) => S.tr(Lang.bn, k);

  testWidgets('guests see no delete-account entry', (tester) async {
    await _pump(tester, auth: _Guest.new);
    expect(find.byKey(const ValueKey('profile_delete_account')), findsNothing);
  });

  testWidgets('delete needs the tick, then deletes, wipes the diary, signs out', (tester) async {
    final (api, db, container) = await _pump(tester);
    await _seedDiary(db);

    await tester.tap(find.byKey(const ValueKey('profile_delete_account')));
    await tester.pumpAndSettle();
    expect(find.text(t('delete_account_title')), findsOneWidget);
    expect(find.text(t('delete_account_final')), findsOneWidget);

    final confirm = find.byKey(const ValueKey('delete_account_confirm'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(api.deletes, 0, reason: 'disabled until the member ticks');

    await tester.tap(find.byKey(const ValueKey('delete_account_understood')));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(api.deletes, 1);
    expect(await db.select(db.amalEntries).get(), isEmpty);
    expect(container.read(authProvider).signedIn, isFalse);
  });

  testWidgets('a refusal (usrah head) is shown and nothing is wiped', (tester) async {
    const why = 'আপনি একটি উসরার দায়িত্বে আছেন — আগে অ্যাডমিনকে বলে দায়িত্ব হস্তান্তর করুন';
    final (api, db, container) = await _pump(tester, refuse: why);
    await _seedDiary(db);

    await tester.tap(find.byKey(const ValueKey('profile_delete_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_account_understood')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_account_confirm')));
    await tester.pumpAndSettle();

    expect(api.deletes, 1);
    expect(find.text(why), findsOneWidget);
    expect(await db.select(db.amalEntries).get(), hasLength(1));
    expect(container.read(authProvider).signedIn, isTrue);
  });
}
