// C-W3h — referral plumbing tests:
//   1. PendingReferralStore — write/read/clear + survives a "restart"
//      (a fresh store over the same persisted prefs);
//   2. ApiClient.verifyOtp — referredByCode rides along only when present;
//   3. AuthNotifier.signIn — the join code reaches the wire AND the storage
//      is consumed on success (kept on failure — the retry still credits
//      the inviter).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/core/referral.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/providers.dart';

const Map<String, dynamic> _userJson = {
  'id': 'u1',
  'name': 'নতুন সদস্য',
  'gender': 'M',
  'role': 'user',
  'category': 'general',
  'createdAt': '2025-01-01T00:00:00.000Z',
  'lastActiveAt': '2025-01-01T00:00:00.000Z',
};

/// Bengali in the body → the utf-8 content type is mandatory (http
/// defaults to latin1 and throws on the encoded bytes).
http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PendingReferralStore', () {
    test('write → read round-trips the code', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingReferralStore(prefs);
      expect(store.read(), isNull);
      await store.write('DS-000123');
      expect(store.read(), 'DS-000123');
    });

    test('re-writing the same link idempotently replaces, not appends',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingReferralStore(prefs);
      await store.write('DS-000123');
      await store.write('DS-000004'); // a newer link tap wins
      expect(store.read(), 'DS-000004');
    });

    test('survives an app restart (fresh store, same persisted prefs)',
        () async {
      await (await SharedPreferences.getInstance())
          .setString(kPendingReferralPref, 'DS-000123');
      // "Restart": a brand-new store instance over the same storage.
      final prefs = await SharedPreferences.getInstance();
      expect(PendingReferralStore(prefs).read(), 'DS-000123');
    });

    test('clear consumes the referral', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingReferralStore(prefs);
      await store.write('DS-000123');
      await store.clear();
      expect(store.read(), isNull);
    });
  });

  group('ApiClient.verifyOtp — referredByCode on the wire', () {
    test('present in the JSON body when passed', () async {
      Map<String, dynamic>? capturedBody;
      final client = ApiClient(
        innerClient: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'user': _userJson, 'accessToken': 'tok'});
        }),
      );
      await client.verifyOtp(
        phone: '01700000000',
        code: '1234',
        referredByCode: 'DS-000123',
      );
      expect(capturedBody!['referredByCode'], 'DS-000123');
    });

    test('absent from the body when null (no pending referral)', () async {
      Map<String, dynamic>? capturedBody;
      final client = ApiClient(
        innerClient: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'user': _userJson, 'accessToken': 'tok'});
        }),
      );
      await client.verifyOtp(phone: '01700000000', code: '1234');
      expect(capturedBody!.containsKey('referredByCode'), isFalse);
    });
  });

  group('AuthNotifier.signIn — join-code plumbing end to end', () {
    test('success: code reaches the wire and the storage is consumed',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPendingReferralPref: 'DS-000123',
      });
      final capturedBodies = <String, Map<String, dynamic>>{};
      final api = ApiClient(
        innerClient: MockClient((request) async {
          capturedBodies[request.url.path] =
              jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'user': _userJson, 'accessToken': 'tok'});
        }),
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          dbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      // The auth screen passes the STORED pending referral:
      final prefs = await SharedPreferences.getInstance();
      final referral = PendingReferralStore(prefs).read();
      expect(referral, 'DS-000123');

      await container.read(authProvider.notifier).signIn(
            phone: '01700000000',
            code: '1234',
            name: 'নতুন সদস্য',
            referredByCode: referral,
          );

      // … it reached the verify request…
      expect(
        capturedBodies['/api/auth/otp/verify']!['referredByCode'],
        'DS-000123',
      );
      // …the session is in…
      expect(container.read(authProvider).signedIn, isTrue);
      // …and the pending referral was consumed on success.
      expect(PendingReferralStore(prefs).read(), isNull);
    });

    test('failure: storage survives for the retry', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPendingReferralPref: 'DS-000123',
      });
      final api = ApiClient(
        innerClient: MockClient(
          (request) async => _jsonResponse({'error': 'ভুল কোড'}, 400),
        ),
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          dbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final prefs = await SharedPreferences.getInstance();
      final referral = PendingReferralStore(prefs).read();

      await expectLater(
        container
            .read(authProvider.notifier)
            .signIn(
              phone: '01700000000',
              code: '0000',
              referredByCode: referral,
            ),
        throwsA(isA<ApiException>()),
      );
      // The verify failed — the inviter still gets credited on the retry.
      expect(PendingReferralStore(prefs).read(), 'DS-000123');
      expect(container.read(authProvider).signedIn, isFalse);
    });
  });
}
