// Sync pull + outbox retry policy tests (C-W3d): the pure policy matrix,
// watermark math, the LWW-convergence invariant, flush's finally-semantics
// (a non-ApiError can no longer stick syncing=true), the reject-handling
// end-to-end path (fake api + in-memory drift), pull merge idempotence and
// the outbox v1→v2 schema migration on a real v1 sqlite file.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/core/sync_merge.dart';
import 'package:sunnah_life/core/sync_policy.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/providers.dart';

AmalEntry _e(String amalKey, String date, Object value, String stamp) =>
    AmalEntry(
      amalKey: amalKey,
      date: date,
      clientUpdatedAt: stamp,
      value: value,
      source: 'manual',
    );

AmalRejectInfo _rej(
  String amalKey,
  String date, {
  String reason = 'নতুন সংস্করণ আছে',
  Object? serverValue,
}) =>
    AmalRejectInfo(
      amalKey: amalKey,
      date: date,
      reason: reason,
      serverValue: serverValue,
    );

const _user = User(
  id: 'u1',
  name: 'টেস্ট',
  gender: Gender.m,
  role: Role.user,
  category: UserCategory.general,
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

/// Fake API: scriptable upsert result + pull rows. Never touches the
/// network (the real amalUpsert would POST to the default base URL).
class _FakeApi extends ApiClient {
  _FakeApi({this.upsertResult, this.pullEntries = const []});
  AmalUpsertResult? upsertResult;
  final List<AmalEntry> pullEntries;
  int upsertCalls = 0;

  @override
  Future<AmalUpsertResult> amalUpsert(List<AmalEntry> entries) async {
    upsertCalls++;
    return upsertResult ??
        AmalUpsertResult(accepted: const [], rejected: const []);
  }

  @override
  Future<List<AmalEntry>> amalEntries(String from, String to) async =>
      pullEntries;
}

class _ThrowingApi extends _FakeApi {
  @override
  Future<AmalUpsertResult> amalUpsert(List<AmalEntry> entries) async {
    upsertCalls++;
    throw StateError('db exploded'); // a non-ApiError, exactly the W3d hazard
  }
}

class _ApiErrorApi extends _FakeApi {
  @override
  Future<AmalUpsertResult> amalUpsert(List<AmalEntry> entries) async {
    upsertCalls++;
    throw ApiException(503, 'অফলাইন');
  }
}

class _GuestAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.guest);
}

ProviderContainer _container(AppDatabase db, ApiClient api) =>
    ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(api),
        authProvider.overrideWith(_GuestAuth.new),
      ],
    );

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

/// Flip the fake auth to signed-in — the SyncNotifier's auth listener then
/// fires syncNow() (flush + pull), the same path as login/app-start. The
/// sync notifier is created FIRST (while still guest) so the flip is what
/// triggers the listener, and pumpEventQueue drains the whole chain.
Future<void> _signIn(ProviderContainer container) async {
  container.read(syncProvider.notifier);
  container.read(authProvider.notifier).state =
      const AuthState(status: AuthStatus.signedIn, user: _user);
  await pumpEventQueue();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('outboxRejectDecision — policy matrix', () {
    test('no serverValue: retry until attempts reaches the cap', () {
      for (var attempts = 0; attempts < 4; attempts++) {
        final d = outboxRejectDecision(
          info: _rej('k', '2025-06-15', reason: 'লক হয়ে গেছে'),
          previousAttempts: attempts,
        );
        expect(d.attempts, attempts + 1, reason: 'attempts $attempts');
        expect(d.dead, isFalse, reason: 'attempts $attempts is under cap');
        expect(d.converge, isFalse);
        expect(d.reason, 'লক হয়ে গেছে', reason: 'reason captured');
      }
    });

    test('no serverValue: the 5th rejection kills the row', () {
      final d = outboxRejectDecision(
        info: _rej('k', '2025-06-15'),
        previousAttempts: kMaxOutboxAttempts - 1,
      );
      expect(d.attempts, kMaxOutboxAttempts);
      expect(d.dead, isTrue);
      expect(d.converge, isFalse);
    });

    test('already over the cap stays dead', () {
      final d = outboxRejectDecision(
        info: _rej('k', '2025-06-15'),
        previousAttempts: 9,
      );
      expect(d.attempts, 10);
      expect(d.dead, isTrue);
    });

    test('serverValue (LWW loss): converge + dead in ONE round', () {
      final d = outboxRejectDecision(
        info: _rej('k', '2025-06-15', serverValue: 'jamaat'),
        previousAttempts: 0,
      );
      expect(d.converge, isTrue);
      expect(d.dead, isTrue, reason: 'must never re-POST after converging');
      expect(d.reason, 'নতুন সংস্করণ আছে');
      expect(d.attempts, 1);
    });

    test('AmalRejectInfo parses the W2g rejected payload', () {
      final j = AmalRejectInfo.fromJson(const {
        'date': '2025-06-15',
        'amalKey': 'salat_fajr',
        'reason': 'নতুন সংস্করণ আছে',
        'serverValue': 'jamaat',
      });
      expect(j.serverValue, 'jamaat');
      expect(
        AmalRejectInfo.fromJson(const {
          'date': '2025-06-15',
          'amalKey': 'salat_fajr',
          'reason': 'মান ঠিক নয়',
        }).serverValue,
        isNull,
      );
    });
  });

  group('pullWindowFrom — watermark math', () {
    const today = '2025-06-15';

    test('first run (no watermark): bounded 95-day window, not "everything"',
        () {
      expect(pullWindowFrom(null, today), addDays(today, -kFirstPullWindowDays));
    });

    test('incremental: watermark minus 3 days of overlap', () {
      expect(pullWindowFrom('2025-06-10', today), '2025-06-07');
    });

    test('corrupt watermark falls back to the first-pull window', () {
      expect(pullWindowFrom('2025-13-01', today),
          addDays(today, -kFirstPullWindowDays));
      expect(pullWindowFrom('garbage', today),
          addDays(today, -kFirstPullWindowDays));
      expect(pullWindowFrom('', today), addDays(today, -kFirstPullWindowDays));
    });

    test('future watermark (device clock set back): recent overlap only', () {
      expect(pullWindowFrom('2025-06-20', today), '2025-06-12');
    });

    test('isValidDateKey — real calendar days only', () {
      expect(isValidDateKey('2025-06-15'), isTrue);
      expect(isValidDateKey('2024-02-29'), isTrue); // leap
      expect(isValidDateKey('2023-02-29'), isFalse);
      expect(isValidDateKey('2025-02-30'), isFalse);
      expect(isValidDateKey('2025-13-01'), isFalse);
      expect(isValidDateKey('2025-6-15'), isFalse); // unpadded
      expect(isValidDateKey('20250615'), isFalse);
    });
  });

  group('convergedEntryFor — LWW convergence invariant', () {
    final pushed =
        _e('salat_fajr', '2025-06-15', 'alone', '2025-06-15T10:00:00.000Z');

    test('takes the server value with a stamp 1 ms past the pushed one', () {
      final c = convergedEntryFor(pushed, _rej('salat_fajr', '2025-06-15',
          serverValue: 'jamaat'));
      expect(c.value, 'jamaat');
      expect(c.clientUpdatedAt, '2025-06-15T10:00:00.001Z');
      expect(convergenceWinsMerge(pushed, c), isTrue,
          reason: 'converged entry must win the local merge');
    });

    test('any later server pull still converges to the same VALUE', () {
      final c = convergedEntryFor(pushed, _rej('salat_fajr', '2025-06-15',
          serverValue: 'jamaat'));
      // The true server row is ≥ the pushed stamp — all three positions.
      final serverEqualPushed =
          _e('salat_fajr', '2025-06-15', 'jamaat', '2025-06-15T10:00:00.000Z');
      final serverEqualConverged =
          _e('salat_fajr', '2025-06-15', 'jamaat', '2025-06-15T10:00:00.001Z');
      final serverNewer = _e('salat_fajr', '2025-06-15', 'jamaat',
          '2025-06-15T11:00:00.000Z');
      for (final server in [serverEqualPushed, serverEqualConverged, serverNewer]) {
        expect(mergeEntry(c, server).value, 'jamaat',
            reason: 'server stamp ${server.clientUpdatedAt}');
      }
    });

    test('guest-merge echo: same value convergence is a no-op value-wise',
        () {
      // After sign-in the outbox re-POSTs guest entries the server already
      // merged — those come back newerVersion + the same value.
      final c = convergedEntryFor(pushed,
          _rej('salat_fajr', '2025-06-15', serverValue: 'alone'));
      expect(convergenceWinsMerge(pushed, c), isTrue);
      expect(c.value, 'alone');
    });
  });

  group('flush — reject handling end-to-end (fake api + drift)', () {
    test('accepted → synced; serverValue → converge + resolved; other → retry',
        () async {
      final db = _db();
      addTearDown(db.close);
      final today = dateKey(DateTime.now());
      await db.writeEntry(
          amalKey: 'salat_fajr',
          date: today,
          value: 'alone',
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));
      await db.writeEntry(
          amalKey: 'miswak',
          date: today,
          value: true,
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));
      await db.writeEntry(
          amalKey: 'tilawat',
          date: today,
          value: 5,
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));

      final yesterday = addDays(today, -1);
      final api = _FakeApi(
        upsertResult: AmalUpsertResult(
          accepted: [_e('miswak', today, true, '2025-06-15T10:00:00.000Z')],
          rejected: [
            _rej('salat_fajr', today, serverValue: 'jamaat'),
            _rej('tilawat', today, reason: 'মান ঠিক নয়'),
          ],
        ),
        // A row another device wrote yesterday — the pull must land it.
        pullEntries: [
          _e('quran_daily', yesterday, 'jamaat', '2025-06-15T09:00:00.000Z'),
        ],
      );
      final container = _container(db, api);
      addTearDown(container.dispose);

      await _signIn(container);

      final s = container.read(syncProvider);
      expect(s.syncing, isFalse);
      expect(s.pending, 1, reason: 'tilawat is still retrying');
      expect(s.dead, 0,
          reason: 'salat_fajr converged — resolved, not a failed upload');
      expect(s.lastSyncedAt, isNotNull, reason: 'pull ran after the flush');

      // Convergence: the local entry now holds the SERVER's value.
      final fajr = await db.entry('salat_fajr', today);
      expect(fajr!.value, 'jamaat');
      // …and it left the queue (no red badge for an ordinary conflict).
      expect(await db.deadRows(), isEmpty);

      // The accepted entry left the outbox…
      expect(await db.pendingSyncCount(), 1);
      // …the retryable one recorded its attempt…
      final alive = await db.pendingOps();
      expect(alive, hasLength(1));
      expect(alive.single.$1.amalKey, 'tilawat');
      expect(alive.single.$1.attempts, 1);
      expect(alive.single.$1.lastError, 'মান ঠিক নয়');
      expect(alive.single.$1.deadAt, isNull);

      // The pull landed the other device's row…
      final pulled = await db.entry('quran_daily', yesterday);
      expect(pulled!.value, 'jamaat');
      // …and persisted the watermark (cursor = today).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_pull_cursor'), today);
    });

    test('validation rejections stop at kMaxOutboxAttempts, then stay dead',
        () async {
      final db = _db();
      addTearDown(db.close);
      final today = dateKey(DateTime.now());
      await db.writeEntry(
          amalKey: 'tilawat',
          date: today,
          value: 5,
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));

      final api = _FakeApi(
        upsertResult: AmalUpsertResult(
          accepted: const [],
          rejected: [_rej('tilawat', today, reason: 'মান ঠিক নয়')],
        ),
      );
      final container = _container(db, api);
      addTearDown(container.dispose);

      await _signIn(container);
      expect(container.read(syncProvider).dead, 0);

      // Rejections 2..5 (flush #1 already counted the first attempt).
      final notifier = container.read(syncProvider.notifier);
      for (var i = 2; i <= kMaxOutboxAttempts; i++) {
        await notifier.flush();
        final dead = i >= kMaxOutboxAttempts ? 1 : 0;
        expect(container.read(syncProvider).dead, dead,
            reason: 'attempt $i: alive under the cap, dead at the cap');
        final rows = await db.pendingOps();
        if (dead == 0) {
          expect(rows.single.$1.attempts, i);
          expect(rows.single.$1.deadAt, isNull);
        } else {
          expect(rows, isEmpty, reason: 'the capped row left the batch');
        }
      }

      // Flush #6: the outbox is dead — pendingOps must skip it, so no POST.
      final callsBefore = api.upsertCalls;
      await notifier.flush();
      expect(container.read(syncProvider).pending, 0);
      expect(container.read(syncProvider).dead, 1);
      expect(api.upsertCalls, callsBefore,
          reason: 'dead rows are never re-POSTed');

      final dead = await db.deadRows();
      expect(dead.single.attempts, kMaxOutboxAttempts);
      expect(dead.single.lastError, 'মান ঠিক নয়');

      // Retry-again (sync sheet): the row revives with a clean counter…
      await notifier.retryDead(dead.single.id);
      expect(await db.deadRows(), isEmpty);
      final revived = await db.pendingOps();
      expect(revived.single.$1.attempts, 0);
      expect(revived.single.$1.lastError, isNull);
      // …discard (sync sheet): the row is dropped for good.
      await notifier.discardDead((await db.pendingOps()).single.$1.id);
      expect(await db.deadRows(), isEmpty);
      expect(await db.pendingOps(), isEmpty);
    });
  });

  group('flush — every error path resets syncing (the W3d unstick)', () {
    test('a non-ApiError no longer sticks syncing=true', () async {
      final db = _db();
      addTearDown(db.close);
      final today = dateKey(DateTime.now());
      await db.writeEntry(
          amalKey: 'k',
          date: today,
          value: true,
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));

      final api = _ThrowingApi();
      final container = _container(db, api);
      addTearDown(container.dispose);

      await _signIn(container);
      final s = container.read(syncProvider);
      expect(s.syncing, isFalse, reason: 'StateError must reset the spinner');
      expect(s.messageKey, 'sync_error_unexpected');
      expect(s.lastMessage, isNull);
      expect(s.pending, 1, reason: 'the row survives for the next flush');

      // The guard is NOT blocked: flushing again completes (and still
      // resets) — pre-C-W3d this second call returned early forever.
      final notifier = container.read(syncProvider.notifier);
      await notifier.flush();
      expect(container.read(syncProvider).syncing, isFalse);
      expect(api.upsertCalls, 2);
    });

    test('ApiException keeps its message (regression)', () async {
      final db = _db();
      addTearDown(db.close);
      final today = dateKey(DateTime.now());
      await db.writeEntry(
          amalKey: 'k',
          date: today,
          value: true,
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));

      final api = _ApiErrorApi();
      final container = _container(db, api);
      addTearDown(container.dispose);

      await _signIn(container);
      final s = container.read(syncProvider);
      expect(s.syncing, isFalse);
      expect(s.lastMessage, 'অফলাইন');
      expect(s.messageKey, isNull);
      expect(s.stalled, isTrue, reason: 'offline → the badge may show the waiting rows');
    });

    test('rows older versions kept as failed get ONE more try after the update',
        () async {
      final db = _db();
      addTearDown(db.close);
      final today = dateKey(DateTime.now());
      await db.writeEntry(
          amalKey: 'salat_fajr',
          date: today,
          value: '',
          source: 'manual',
          clientUpdatedAt: DateTime(2025, 6, 15, 10));
      await db.recordRejection(
          amalKey: 'salat_fajr', date: today, reason: 'মান ঠিক নয়', dead: true);
      expect(await db.deadCount(), 1);

      final api = _FakeApi(
        upsertResult: AmalUpsertResult(
          accepted: [_e('salat_fajr', today, '', '2025-06-15T10:00:00.000Z')],
          rejected: const [],
        ),
      );
      final container = _container(db, api);
      addTearDown(container.dispose);
      await _signIn(container);

      expect(await db.deadCount(), 0);
      expect(container.read(syncProvider).dead, 0);
      expect(container.read(syncProvider).stalled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sync_dead_revived_v2'), isTrue,
          reason: 'only once — a real failure afterwards stays visible');
    });
  });

  group('pull — merge idempotence + LWW against pending rows', () {
    test('pulling the same rows twice yields the same local state', () async {
      final db = _db();
      addTearDown(db.close);
      final rows = [
        _e('a', '2025-06-14', 'jamaat', '2025-06-14T09:00:00.000Z'),
        _e('b', '2025-06-15', 3, '2025-06-15T09:00:00.000Z'),
      ];
      await db.mergeServerEntries(rows);
      final first = await db.entriesBetween('2000-01-01', '2999-12-31');
      await db.mergeServerEntries(rows);
      final second = await db.entriesBetween('2000-01-01', '2999-12-31');

      String describe(List<AmalEntry> l) => l
          .map((e) =>
              '${e.amalKey}|${e.date}|${e.value}|${e.clientUpdatedAt}|${e.source}')
          .join(';');
      expect(describe(second), describe(first));
      expect(first, hasLength(2));
    });

    test('a pull overwriting a PENDING local row still converges via LWW',
        () async {
      final db = _db();
      addTearDown(db.close);
      await db.writeEntry(
          amalKey: 'a',
          date: '2025-06-15',
          value: 'alone',
          source: 'manual',
          clientUpdatedAt: DateTime.parse('2025-06-15T09:00:00.000Z'));

      // The server's copy is NEWER → the merge overwrites the local row…
      await db.mergeServerEntries(
          [_e('a', '2025-06-15', 'jamaat', '2025-06-15T10:00:00.000Z')]);
      expect((await db.entry('a', '2025-06-15'))!.value, 'jamaat');
      // …but the outbox row survives — the eventual re-POST is decided by
      // the SERVER (accept if ours is newer, reject+serverValue otherwise).
      expect(await db.pendingSyncCount(), 1);
    });
  });

  group('outbox schema v1 → v2 migration', () {
    test('a real v1 file upgrades in place — new columns, data survives',
        () async {
      final dir = await Directory.systemTemp.createTemp('sl_sync_v1');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/v1.sqlite');

      // A faithful v1 outbox table (exactly what drift generated at
      // schemaVersion 1) with one pre-existing pending row.
      final raw = sql.sqlite3.open(file.path);
      raw.execute('''
        CREATE TABLE IF NOT EXISTS "outbox" (
          "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          "amal_key" TEXT NOT NULL,
          "date" TEXT NOT NULL,
          "value_json" TEXT NOT NULL,
          "source" TEXT NOT NULL,
          "client_updated_at" INTEGER NOT NULL,
          "attempts" INTEGER NOT NULL DEFAULT 0
        );
      ''');
      // drift stores DateTime as unix SECONDS in this project (probed).
      raw.execute(
          "INSERT INTO outbox (amal_key, date, value_json, source, client_updated_at, attempts) "
          "VALUES ('salat_fajr', '2025-06-01', '\"jamaat\"', 'manual', 1748736000, 3)");
      raw.execute('PRAGMA user_version = 1');
      raw.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      // The migration runs on first use: the pre-existing row survives.
      final ops = await db.pendingOps();
      expect(ops, hasLength(1));
      expect(ops.single.$1.amalKey, 'salat_fajr');
      expect(ops.single.$1.attempts, 3);
      expect(ops.single.$2.value, 'jamaat');
      expect(await db.deadRows(), isEmpty);

      // Rejection recording works on the upgraded table.
      await db.recordRejection(
        amalKey: 'salat_fajr',
        date: '2025-06-01',
        reason: 'নতুন সংস্করণ আছে',
        dead: true,
        now: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final dead = await db.deadRows();
      expect(dead.single.attempts, 4);
      expect(dead.single.lastError, 'নতুন সংস্করণ আছে');
      expect(dead.single.deadAt, isNotNull);
      expect(await db.pendingSyncCount(), 0,
          reason: 'dead rows are not pending');
    });
  });

  group('profile schema v4 → v5 migration', () {
    test('a v4 phone: Karachi (the old default) → IFB, no adjustment yet',
        () async {
      final dir = await Directory.systemTemp.createTemp('sl_v4');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/v4.sqlite');

      // Build today's schema, then take it back to v4: drop the new column
      // and store the old default method.
      final fresh = AppDatabase.forTesting(NativeDatabase(file));
      await fresh.guestProfile();
      await fresh.close();
      final raw = sql.sqlite3.open(file.path);
      raw.execute('ALTER TABLE guest_profiles DROP COLUMN prayer_adjust');
      raw.execute("UPDATE guest_profiles SET method = 'karachi'");
      raw.execute('PRAGMA user_version = 4');
      raw.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final row = await db.guestProfile();
      expect(row.method, 'ifb');
      expect(row.prayerAdjust, '{}');
    });
  });
}
