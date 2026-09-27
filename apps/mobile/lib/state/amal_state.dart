/// Amal state: definitions (API when signed in / bundled fallback for
/// guests), optimistic entries, and the offline-first sync engine.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/fallback_catalog.dart';
import '../core/amal_engine.dart';
import '../core/date_keys.dart';
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
    this.syncing = false,
    this.lastSyncedAt,
    this.lastMessage,
  });
  final int pending;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? lastMessage;
}

class SyncNotifier extends Notifier<SyncState> {
  Timer? _periodic;

  @override
  SyncState build() {
    ref.onDispose(() => _periodic?.cancel());
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
    final pending = await ref.read(dbProvider).pendingSyncCount();
    state = SyncState(
      pending: pending,
      syncing: state.syncing,
      lastSyncedAt: state.lastSyncedAt,
      lastMessage: state.lastMessage,
    );
  }

  /// Flush the outbox to POST /api/amal/entries. Guests stay local-only.
  Future<void> flush() async {
    final auth = ref.read(authProvider);
    if (!auth.signedIn) {
      await _refreshCount();
      return;
    }
    if (state.syncing) return;
    state = SyncState(
      pending: state.pending,
      syncing: true,
      lastSyncedAt: state.lastSyncedAt,
      lastMessage: state.lastMessage,
    );
    try {
      final db = ref.read(dbProvider);
      final batch = await db.pendingEntries();
      if (batch.isEmpty) {
        state = SyncState(
          pending: 0,
          syncing: false,
          lastSyncedAt: DateTime.now(),
          lastMessage: state.lastMessage,
        );
        return;
      }
      final result = await ref.read(apiProvider).amalUpsert(batch);
      await db.markSynced(result.accepted);
      state = SyncState(
        pending: await db.pendingSyncCount(),
        syncing: false,
        lastSyncedAt: DateTime.now(),
        lastMessage: result.rejected.isEmpty
            ? null
            : 'সার্ভার জানিয়েছে: ${result.rejected.first.reason}',
      );
    } on ApiException catch (e) {
      state = SyncState(
        pending: state.pending,
        syncing: false,
        lastSyncedAt: state.lastSyncedAt,
        lastMessage: e.message,
      );
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

// re-export for AmalNotifier's computation
// (kept at the bottom to avoid a circular import in the file-local scope)
// ignore: always_use_package_imports
// ignore: implementation_imports
