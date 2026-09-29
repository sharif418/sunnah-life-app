// W4-fix4 — Da'wah offline-cache tests:
//   1. DriftApiCacheStore round-trip on the REAL in-memory database
//      (schema v4 — the RemoteCacheTable migration is exercised by
//      createAll here);
//   2. fresh fetch → cache row written + stale: false;
//   3. network failure + cached envelope → stale: true, fetchedAt from the
//      cache row, model re-parsed from the stored payload;
//   4. network failure + NEVER cached → rethrows (the error state stays);
//   5. server rejection (403) with a warm cache → still rethrows — stale
//      data must never mask a live refusal;
//   6. scope isolation — u1's envelope can never surface for u2;
//   7. usrah()/reviews()/dawahRequirements() envelopes parse back;
//   8. OfflineBanner renders the "সর্বশেষ হালনাগাদ" stamp (pinned clock).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/api_cache.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/dawah/dawah_screen.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/design/phosphor_icons.dart';

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const Map<String, dynamic> _overviewJson = {
  'memberCode': 'DS-000004',
  'referralLink': 'https://sunnahlife.app/join/DS-000004',
  'invitedCount': 3,
  'downline': [],
  'level': 'muhibbus_sunnah',
  'monthsInLevel': 2,
  'requirements': [],
  'nextLevel': 'farze_ain_1',
  'assessments': [],
};

const Map<String, dynamic> _usrahJson = {
  'usrah': {
    'id': 'u1',
    'name': 'আল-হুদা উসরা',
    'gender': 'M',
    'headName': 'উসরা প্রধান',
    'memberCount': 5,
    'members': [
      {'id': 'm1', 'name': 'রাফিউল ইসলাম', 'gender': 'M', 'level': 'none'},
    ],
  },
  'announcements': [
    {
      'id': 'a1',
      'authorId': 'h1',
      'kind': 'announcement',
      'body': 'শুক্রবার মজলিস',
      'pinned': true,
      'createdAt': '2025-06-10',
      'authorName': 'উসরা প্রধান',
    },
  ],
};

const Map<String, dynamic> _reviewsJson = {
  'reviews': [
    {
      'id': 'r1',
      'userId': 'u1',
      'reviewerId': 'h1',
      'weekStart': '2025-06-09',
      'comment': 'আলহামদুলিল্লাহ',
      'rating': 4,
      'status': 'done',
      'createdAt': '2025-06-13',
      'completedAt': '2025-06-13',
      'userName': 'রাফিউল ইসলাম',
      'reviewerName': 'উসরা প্রধান',
    },
  ],
};

const Map<String, dynamic> _requirementsJson = {
  'level': 'muhibbus_sunnah',
  'nextLevel': 'farze_ain_1',
  'rulesApply': true,
  'allMet': false,
  'autoEligible': false,
  'requirements': [
    {'key': 'k1', 'labelBn': 'রিভিউ', 'met': true, 'autoChecked': true},
  ],
};

/// Never answers — every call is a network drop.
http.Client _deadNet() => MockClient((request) async {
  throw http.ClientException('no network');
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DriftApiCacheStore round-trip (real in-memory Drift, schema v4)',
      () {
    test('write then read returns the same payload + timestamp', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftApiCacheStore(db);
      final at = DateTime(2026, 9, 29, 10, 30);

      await store.write('dawah/overview:u1', _overviewJson, at);
      final hit = await store.read('dawah/overview:u1');

      expect(hit, isNotNull);
      expect(hit!.fetchedAt, at);
      expect(hit.payload['memberCode'], 'DS-000004');
      expect(hit.payload['level'], 'muhibbus_sunnah');
    });

    test('read of a never-written key is null', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftApiCacheStore(db);

      expect(await store.read('dawah/overview:u1'), isNull);
    });

    test('second write overwrites the first (last-good wins)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftApiCacheStore(db);

      await store.write(
        'dawah/overview:u1',
        _overviewJson,
        DateTime(2026, 1, 1),
      );
      final newer = {
        ..._overviewJson,
        'invitedCount': 7,
      };
      await store.write(
        'dawah/overview:u1',
        newer,
        DateTime(2026, 9, 29, 11),
      );
      final hit = await store.read('dawah/overview:u1');

      expect(hit!.payload['invitedCount'], 7);
      expect(hit.fetchedAt, DateTime(2026, 9, 29, 11));
    });
  });

  group('ApiClient cached GET pipeline', () {
    test('fresh fetch writes the cache and returns stale: false', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = ApiClient(
        innerClient: MockClient((request) async {
          expect(request.url.path, '/api/dawah');
          return _jsonResponse(_overviewJson);
        }),
        cacheStore: DriftApiCacheStore(db),
      );

      final c = await client.dawahOverview(scope: 'u1');
      expect(c.stale, isFalse);
      expect(c.data.memberCode, 'DS-000004');
      expect(c.fetchedAt.difference(DateTime.now()).abs().inMinutes, lessThan(1));

      // The envelope landed under the user-scoped key.
      final row = await db.remoteCache('dawah/overview:u1');
      expect(row, isNotNull);
      expect(row!.payload, contains('DS-000004'));
    });

    test('network failure + warm cache → stale snapshot with the row stamp',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final stamp = DateTime(2026, 9, 28, 8, 0);
      await db.saveRemoteCache(
        key: 'dawah/overview:u1',
        payload: jsonEncode(_overviewJson),
        fetchedAt: stamp,
      );

      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );
      final c = await client.dawahOverview(scope: 'u1');

      expect(c.stale, isTrue);
      expect(c.fetchedAt, stamp);
      expect(c.data.memberCode, 'DS-000004');
      expect(c.data.level, Level.muhibbusSunnah);
    });

    test('network failure + never cached → rethrows (error state stays)',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );

      await expectLater(
        client.dawahOverview(scope: 'u1'),
        throwsA(isA<ApiException>()),
      );
    });

    test('server rejection (403) rethrows even with a warm cache', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveRemoteCache(
        key: 'dawah/overview:u1',
        payload: jsonEncode(_overviewJson),
        fetchedAt: DateTime(2026, 9, 28),
      );

      final client = ApiClient(
        innerClient: MockClient(
          (request) async => _jsonResponse({'error': 'নিষিদ্ধ'}, 403),
        ),
        cacheStore: DriftApiCacheStore(db),
      );

      await expectLater(
        client.dawahOverview(scope: 'u1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403),
        ),
      );
    });

    test('scope isolation — u1\'s envelope never surfaces for u2', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveRemoteCache(
        key: 'dawah/overview:u1',
        payload: jsonEncode(_overviewJson),
        fetchedAt: DateTime(2026, 9, 28),
      );

      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );

      // u2 has never been cached → the drop surfaces as the error, not as
      // u1's private overview.
      await expectLater(
        client.dawahOverview(scope: 'u2'),
        throwsA(isA<ApiException>()),
      );
    });

    test('usrah() envelope parses back offline (roster + announcements)',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveRemoteCache(
        key: 'dawah/usrah:u1',
        payload: jsonEncode(_usrahJson),
        fetchedAt: DateTime(2026, 9, 28),
      );

      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );
      final c = await client.usrah(scope: 'u1');

      expect(c.stale, isTrue);
      expect(c.data.$1!.name, 'আল-হুদা উসরা');
      expect(c.data.$2, hasLength(1));
      expect(c.data.$2.first.body, 'শুক্রবার মজলিস');
    });

    test('reviews() envelope parses back offline', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveRemoteCache(
        key: 'dawah/reviews:u1',
        payload: jsonEncode(_reviewsJson),
        fetchedAt: DateTime(2026, 9, 28),
      );

      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );
      final c = await client.reviews(scope: 'u1');

      expect(c.stale, isTrue);
      expect(c.data, hasLength(1));
      expect(c.data.first.weekStart, '2025-06-09');
    });

    test('dawahRequirements() envelope parses back offline', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveRemoteCache(
        key: 'dawah/requirements:u1',
        payload: jsonEncode(_requirementsJson),
        fetchedAt: DateTime(2026, 9, 28),
      );

      final client = ApiClient(
        innerClient: _deadNet(),
        cacheStore: DriftApiCacheStore(db),
      );
      final c = await client.dawahRequirements(scope: 'u1');

      expect(c.stale, isTrue);
      expect(c.data.rulesApply, isTrue);
      expect(c.data.requirements, hasLength(1));
    });

    test('a null cacheStore behaves exactly like the old client (rethrows)',
        () async {
      final client = ApiClient(innerClient: _deadNet());
      await expectLater(
        client.dawahOverview(scope: 'u1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('OfflineBanner widget', () {
    testWidgets('renders the offline line + the staleness stamp (bn)',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildSunnahLightTheme(),
            home: Scaffold(
              body: OfflineBanner(
                fetchedAt: DateTime(2026, 9, 29, 10, 0),
                now: DateTime(2026, 9, 29, 10, 5), // ৫ মিনিট আগে
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.wifiSlash), findsOneWidget);
      expect(
        find.textContaining('সর্বশেষ হালনাগাদ'),
        findsOneWidget,
      );
      expect(find.textContaining('৫ মিনিট আগে'), findsOneWidget);
    });

    testWidgets('Dawah tab serves the cached overview offline — banner + stamp',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.saveRemoteCache(
        key: 'dawah/overview:u1',
        payload: jsonEncode(_overviewJson),
        fetchedAt: DateTime(2026, 9, 29, 9, 30),
      );
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(
          _StaleDawahApi(db),
        ),
        authProvider.overrideWith(_DaeeAuth.new),
      ]);
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildSunnahLightTheme(),
            home: const DawahScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The overview renders from the cache — not an error wall.
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('সর্বশেষ হালনাগাদ'), findsOneWidget);
      expect(find.textContaining('DS-000004'), findsWidgets);
      expect(find.byType(ErrorState), findsNothing);
    });
  });
}

class _DaeeAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u1',
      name: 'রাফিউল ইসলাম',
      gender: Gender.m,
      role: Role.daee,
      category: UserCategory.general,
      memberCode: 'DS-000004',
      level: Level.muhibbusSunnah,
      createdAt: '2025-01-01T00:00:00.000Z',
      lastActiveAt: '2025-01-01T00:00:00.000Z',
    ),
  );
}

/// Serves EVERY cached GET from a pre-warmed row with a dead network —
/// exactly the device state the fix exists for.
class _StaleDawahApi extends ApiClient {
  _StaleDawahApi(this._db);
  final AppDatabase _db;

  @override
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) async {
    final row = await _db.remoteCache('dawah/overview:${scope ?? ''}');
    if (row == null) throw ApiException(0, 'নেটওয়ার্ক');
    return ApiCached(
      DawahOverview.fromJson(jsonDecode(row.payload) as Map<String, dynamic>),
      fetchedAt: row.fetchedAt,
      stale: true,
    );
  }

  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
  );
}
