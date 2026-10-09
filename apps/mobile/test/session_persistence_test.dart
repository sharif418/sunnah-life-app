// The phone keeps its session (2026-10-09): the access token lives 15
// minutes, so before this nearly every reopen meant a new sign-in code.
// Now an expired access token is renewed with the refresh token, a bad
// connection never signs anyone out, and the last known user shows at once.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/services/session_store.dart';
import 'package:sunnah_life/state/providers.dart';

const _user = {
  'id': 'u1',
  'name': 'আব্দুল্লাহ',
  'gender': 'M',
  'role': 'daee',
  'level': 'none',
  'createdAt': '2026-01-01T00:00:00.000Z',
  'lastActiveAt': '2026-01-01T00:00:00.000Z',
};

/// A fake server: /api/me accepts only [validAccess]; /api/auth/refresh
/// accepts only [validRefresh] (once — it rotates).
class FakeAuthServer {
  String validAccess = 'fresh-access';
  String? validRefresh = 'r1';
  bool offline = false;
  int refreshCalls = 0;

  http.Client get client => MockClient((req) async {
    if (offline) throw http.ClientException('no network');
    if (req.url.path == '/api/auth/refresh') {
      refreshCalls++;
      final body = jsonDecode(req.body) as Map;
      if (validRefresh != null && body['refreshToken'] == validRefresh) {
        validRefresh = 'r2';
        validAccess = 'renewed-access';
        return http.Response(
          jsonEncode({'accessToken': 'renewed-access', 'refreshToken': 'r2'}),
          200,
        );
      }
      return http.Response(jsonEncode({'error': 'expired'}), 401);
    }
    final auth = req.headers['Authorization'];
    if (auth != 'Bearer $validAccess') {
      return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
    }
    if (req.url.path == '/api/me') {
      return http.Response(
        jsonEncode({'user': _user}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{}', 200);
  });
}

Future<ProviderContainer> boot(FakeAuthServer server) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final api = ApiClient(innerClient: server.client);
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      apiProvider.overrideWith((ref) {
        api.onUnauthorized = () =>
            ref.read(authProvider.notifier).forceSignOut();
        api.onTokensRefreshed = (a, r) =>
            ref.read(sessionStoreProvider).saveTokens(a, r);
        return api;
      }),
    ],
  );
  addTearDown(container.dispose);
  container.read(authProvider);
  // let _restore run to completion
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container;
}

Future<void> seed({
  String access = 'old-access',
  String? refresh = 'r1',
  bool withUser = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = SessionStore();
  await store.saveTokens(access, refresh);
  if (withUser) await store.saveUser(User.fromJson(_user));
}

void main() {
  setUp(() => SessionStore.forcePrefsForTesting = true);

  test('an expired access token is renewed — still signed in', () async {
    await seed();
    final server = FakeAuthServer();
    final c = await boot(server);
    expect(c.read(authProvider).signedIn, isTrue);
    expect(server.refreshCalls, 1);
    final saved = await SessionStore().read();
    expect(saved?.access, 'renewed-access');
    expect(saved?.refresh, 'r2', reason: 'the rotated token is kept');
  });

  test('offline: the last known user, session kept', () async {
    await seed();
    final server = FakeAuthServer()..offline = true;
    final c = await boot(server);
    expect(c.read(authProvider).signedIn, isTrue);
    expect(c.read(authProvider).user?.name, 'আব্দুল্লাহ');
    expect((await SessionStore().read())?.refresh, 'r1');
  });

  test('a refused refresh signs out and clears the phone', () async {
    await seed(refresh: 'r-revoked');
    final server = FakeAuthServer();
    final c = await boot(server);
    expect(c.read(authProvider).signedIn, isFalse);
    expect(await SessionStore().read(), isNull);
  });

  test('an old install (token in plain prefs) is carried over', () async {
    SharedPreferences.setMockInitialValues({
      SessionStore.legacyTokenKey: 'fresh-access',
    });
    final server = FakeAuthServer();
    final c = await boot(server);
    expect(c.read(authProvider).signedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SessionStore.legacyTokenKey), isNull);
  });

  test('two requests failing together spend the refresh token ONCE', () async {
    final server = FakeAuthServer();
    final api = ApiClient(innerClient: server.client)
      ..token = 'old-access'
      ..refreshToken = 'r1';
    final results = await Future.wait([api.me(), api.me(), api.me()]);
    expect(results.every((u) => u?.id == 'u1'), isTrue);
    expect(server.refreshCalls, 1);
  });
}
