/// Amal state: definitions (API when signed in / bundled fallback for
/// guests), optimistic entries, and the offline-first sync engine.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/fallback_catalog.dart';
import '../core/amal_engine.dart';
import '../core/date_keys.dart';
import '../core/sync_policy.dart';
import '../models/domain.dart';
import 'providers.dart';

// ── Definitions ──────────────────────────────────────────────────────────────

class AmalDefinitionsNotifier extends AsyncNotifier<List<AmalDefinition>> {
  @override
  Future<List<AmalDefinition>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.signedIn) {
      try {
        final defs = await ref.read(apiProvider).amalDefinitions();
        if (defs.isNotEmpty) return defs;
      } on ApiException catch (e) {
        debugPrint('amal definitions fallback: ${e.message}');
      }
    }
    return _fallbackDefs();
  }

  static List<AmalDefinition> _fallbackDefs() => fallbackDefinitions();
}

final amalDefinitionsProvider =
    AsyncNotifierProvider<AmalDefinitionsNotifier, List<AmalDefinition>>(
      AmalDefinitionsNotifier.new,
    );

// ── Entries + optimistic writes ───────────────────────────────────────────────

class AmalState {
  const AmalState({this.entries = const {}, this.loadedThrough});
  // date → (amalKey → entry)
  final Map<String, Map<String, AmalEntry>> entries;
  final String? loadedThrough;

  AmalEntry? entry(String date, String amalKey) => entries[date]?[amalKey];
}

class AmalNotifier extends Notifier<AmalState> {
  Timer? _debounce;

  @override
  AmalState build() {
    ref.onDispose(() => _debounce?.cancel());
    _loadWindow();
    return const AmalState();
  }

  Future<void> _loadWindow({String? through}) async {
    final db = ref.read(dbProvider);
    final today = dateKey(DateTime.now());
    final from = addDays(today, -95); // 3 months of history
    final to = through ?? today;
    final rows = await db.entriesBetween(from, to);
    final next = <String, Map<String, AmalEntry>>{};
    for (final e in rows) {
      next.putIfAbsent(e.date, () => {})[e.amalKey] = e;
    }
    state = AmalState(entries: next, loadedThrough: to);
  }

  /// Hydrate a month (e.g. after login when server history arrives).
  Future<void> hydrate() => _loadWindow();

  AmalEntry? entry(String date, String amalKey) =>
      state.entries[date]?[amalKey];

  /// Optimistic write: state updates first, then Drift + outbox, then the
  /// debounced sync flush. Locked days are rejected with a reason.
  Future<String?> write(
    String amalKey,
    String date,
    Object value,
    String source,
  ) async {
    final profile = ref.read(profileProvider);
    final now = DateTime.now();
    final locked = isLockedNow(date, profile);
    if (locked != null) return locked;

    // Optimistic state update.
    final day = Map<String, AmalEntry>.from(state.entries[date] ?? {});
    day[amalKey] = AmalEntry(
      amalKey: amalKey,
      date: date,
      clientUpdatedAt: now.toIso8601String(),
      value: value,
      source: source,
    );
    state = AmalState(
      entries: {...state.entries, date: day},
      loadedThrough: state.loadedThrough,
    );

    await ref
        .read(dbProvider)
        .writeEntry(
          amalKey: amalKey,
          date: date,
          value: value,
          source: source,
          clientUpdatedAt: now,
        );
    _scheduleFlush();
    return null; // accepted
  }

  /// Null when writable, or a reason string when the day is locked
  /// (paper-diary rule: a day locks after the NEXT day's Ishraq).
  String? isLockedNow(String date, ProfileState profile) {
    final now = DateTime.now();
    if (date == dateKey(now)) return null; // today is always writable
    if (isDateLocked(
      date,
      now,
      lat: profile.lat,
      lng: profile.lng,
      tz: profile.tz,
      method: profile.method,
      madhhab: profile.madhhab,
    )) {
      return 'লক হয়ে গেছে — উসরা প্রধানের অনুমতি দরকার';
    }
    return null;
  }

  void _scheduleFlush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(syncProvider.notifier).flush();
    });
  }
}

final amalProvider = NotifierProvider<AmalNotifier, AmalState>(
  AmalNotifier.new,
);

// ── Sync engine ──────────────────────────────────────────────────────────────

class SyncState {
  const SyncState({
    this.pending = 0,
    this.dead = 0,
    this.syncing = false,
    this.lastSyncedAt,
    this.lastMessage,
    this.messageKey,
  });

  /// Alive outbox rows waiting to be pushed.
  final int pending;

  /// Dead outbox rows (rejected: converged or attempts exhausted).
  final int dead;
  final bool syncing;
  final DateTime? lastSyncedAt;

  /// Server-supplied message (already localized server-side — the API's
  /// rejection reasons are Bengali constants).
  final String? lastMessage;

  /// App-side l10n KEY for messages owned by the client (e.g. the generic
  /// unexpected-error message) — translated at display time so every
  /// language gets its own string.
  final String? messageKey;

  static const _unset = Object();

  SyncState copyWith({
    int? pending,
    int? dead,
    bool? syncing,
    DateTime? lastSyncedAt,
    bool clearSyncedAt = false,
    Object? lastMessage = _unset,
    Object? messageKey = _unset,
  }) =>
      SyncState(
        pending: pending ?? this.pending,
        dead: dead ?? this.dead,
        syncing: syncing ?? this.syncing,
        lastSyncedAt: clearSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
        lastMessage: lastMessage == _unset ? this.lastMessage : lastMessage as String?,
        messageKey: messageKey == _unset ? this.messageKey : messageKey as String?,
      );
}

class SyncNotifier extends Notifier<SyncState> {
  Timer? _periodic;

  static const _pullCursorKey = 'sync_pull_cursor';

  @override
  SyncState build() {
    ref.onDispose(() => _periodic?.cancel());
    // Pull on login + after auth hydration (app start): the guest→signedIn
    // transition covers both — restore completes into signedIn, and an
    // explicit sign-in flips guest→signedIn. This is NOT the 60s loop:
    // pulling is app-start/login/manual only (no server hammering).
    // The microtask defers past the current build: with fireImmediately the
    // listener can run while build() hasn't produced a state yet (sync
    // provider created after auth was already signed in), and reading
    // `state` inside syncNow would throw before initialization.
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasIn = prev?.status == AuthStatus.signedIn;
      if (!wasIn && next.status == AuthStatus.signedIn) {
        unawaited(Future<void>.microtask(syncNow));
      }
    }, fireImmediately: true);
    _refreshCount();
    return const SyncState();
  }

  /// Offline-first background flush: every 60s while the app is alive.
  /// Started once from the app bootstrap (NOT in build — keeps widget tests
  /// timer-clean); the attempt doubles as the connectivity probe, offline
  /// throws ApiException into lastMessage and retries next tick.
  void startPeriodicFlush() {
    if (_periodic != null) return;
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => flush());
  }

  Future<void> _refreshCount() async {
    final db = ref.read(dbProvider);
    // Await BEFORE touching `state` — this runs while build() may still be
    // initializing (riverpod throws on reads of an uninitialized state).
    final pending = await db.pendingSyncCount();
    final dead = await db.deadCount();
    state = state.copyWith(pending: pending, dead: dead);
  }

  /// Manual "sync now" (sync sheet): push first, then pull. Sequential —
  /// the pull then sees everything the push just landed server-side.
  Future<void> syncNow() async {
    await flush();
    await pull();
  }

  /// Flush the outbox to POST /api/amal/entries. Guests stay local-only.
  ///
  /// EVERY error path resets `syncing` (try/finally + a belt-and-braces
  /// post-check) — before C-W3d only ApiException was caught, so any other
  /// throw left syncing=true and the `if (state.syncing) return;` guard
  /// blocked ALL future flushes until app restart.
  Future<void> flush() async {
    final auth = ref.read(authProvider);
    if (!auth.signedIn) {
      await _refreshCount();
      return;
    }
    if (state.syncing) return;
    state = state.copyWith(syncing: true);
    try {
      final db = ref.read(dbProvider);
      final ops = await db.pendingOps();
      if (ops.isEmpty) {
        state = state.copyWith(
          syncing: false,
          lastSyncedAt: DateTime.now(),
        );
        return;
      }
      final batch = [for (final (_, e) in ops) e];
      final result = await ref.read(apiProvider).amalUpsert(batch);
      await db.markSynced(result.accepted);
      // Rejected rows: bounded retries + convergence (C-W3d).
      for (final rej in result.rejected) {
        final row = ops
            .where((o) => o.$1.amalKey == rej.amalKey && o.$1.date == rej.date)
            .firstOrNull;
        final decision = outboxRejectDecision(
          info: rej,
          previousAttempts: row?.$1.attempts ?? 0,
        );
        if (decision.converge && row != null) {
          // LWW loss with the server's value: converge locally through the
          // SAME merge path a pull uses, then the row below goes dead — it
          // must never re-POST.
          await db.mergeServerEntries([convergedEntryFor(row.$2, rej)]);
        }
        await db.recordRejection(
          amalKey: rej.amalKey,
          date: rej.date,
          reason: decision.reason,
          dead: decision.dead,
        );
      }
      await ref.read(amalProvider.notifier).hydrate();
      state = state.copyWith(
        pending: await db.pendingSyncCount(),
        dead: await db.deadCount(),
        syncing: false,
        lastSyncedAt: DateTime.now(),
        lastMessage: result.rejected.isEmpty
            ? null
            : 'সার্ভার জানিয়েছে: ${result.rejected.first.reason}',
        messageKey: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        syncing: false,
        lastMessage: e.message,
        messageKey: null,
      );
    } catch (e, st) {
      debugPrint('sync flush error: $e\n$st');
      state = state.copyWith(
        syncing: false,
        lastMessage: null,
        messageKey: 'sync_error_unexpected',
      );
    } finally {
      if (state.syncing) {
        // Unreachable in theory — guarantees the spinner can never stick.
        state = state.copyWith(syncing: false);
      }
    }
  }

  /// Cursor-based pull (C-W3d): GET /api/amal/entries from (watermark − 3d
  /// overlap) to today, LWW-merge into the local DB, persist the new
  /// watermark. Failures surface in the sync state but never throw.
  ///
  /// Concurrency with flush/optimistic writes is safe: every writer (local
  /// writeEntry, this merge, the converged-entry merge in flush) funnels
  /// through client-side LWW (mergeEntry) and the server re-checks conflicts
  /// atomically at write time (W2g), so both orders converge to the same
  /// value. A pending outbox row whose local copy is overwritten by a pull
  /// still re-POSTs; the server then either accepts it (ours was newer) or
  /// rejects with serverValue (theirs was newer) → converge + dead.
  Future<void> pull() async {
    final auth = ref.read(authProvider);
    if (!auth.signedIn) return;
    if (state.syncing) return;
    state = state.copyWith(syncing: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = dateKey(DateTime.now());
      final from = pullWindowFrom(prefs.getString(_pullCursorKey), today);
      final rows = await ref.read(apiProvider).amalEntries(from, today);
      await ref.read(dbProvider).mergeServerEntries(rows);
      await prefs.setString(_pullCursorKey, today);
      await ref.read(amalProvider.notifier).hydrate();
      state = state.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now(),
        lastMessage: null,
        messageKey: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        syncing: false,
        lastMessage: e.message,
        messageKey: null,
      );
    } catch (e, st) {
      debugPrint('sync pull error: $e\n$st');
      state = state.copyWith(
        syncing: false,
        lastMessage: null,
        messageKey: 'sync_error_unexpected',
      );
    } finally {
      if (state.syncing) {
        state = state.copyWith(syncing: false);
      }
    }
  }

  /// Retry-again (sync sheet): revive one dead outbox row for the next flush.
  Future<void> retryDead(int id) async {
    await ref.read(dbProvider).retryDeadRow(id);
    await _refreshCount();
  }

  /// Discard (sync sheet): drop one dead outbox row; the local AmalEntry
  /// survives, the sync attempt is abandoned.
  Future<void> discardDead(int id) async {
    await ref.read(dbProvider).discardDeadRow(id);
    await _refreshCount();
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

// re-export for AmalNotifier's computation
// (kept at the bottom to avoid a circular import in the file-local scope)
// ignore: always_use_package_imports
// ignore: implementation_imports
