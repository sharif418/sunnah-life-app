/// Custom-checklist state (W4c) — per-day LOCAL items in the diary.
/// Offline-first by design: no API surface exists, the rows live only in
/// the device's Drift DB, and guests get the exact same experience as
/// signed-in members. Mirrors the AmalNotifier pattern (build-time load +
/// explicit reload after each write).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_keys.dart';
import '../db/database.dart';
import 'providers.dart';

class ChecklistNotifier extends Notifier<Map<String, List<CustomChecklistItem>>> {
  @override
  Map<String, List<CustomChecklistItem>> build() {
    _loadToday();
    return const {};
  }

  String _todayKey() => dateKey(DateTime.now());

  Future<void> _loadToday() async {
    final today = _todayKey();
    final rows = await ref.read(dbProvider).checklistFor(today);
    state = {...state, today: rows};
  }

  List<CustomChecklistItem> itemsFor(String dateKey) =>
      state[dateKey] ?? const [];

  /// Append an item to today's list (sortOrder = current tail + 1).
  Future<void> add(String title) async {
    final today = _todayKey();
    final db = ref.read(dbProvider);
    final rows = await db.checklistFor(today);
    final next = rows.isEmpty
        ? 0
        : rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await db.addChecklistItem(dateKey: today, title: title, sortOrder: next);
    await _loadToday();
  }

  Future<void> toggle(CustomChecklistItem item) async {
    await ref.read(dbProvider).setChecklistDone(item.id, done: !item.done);
    await _loadToday();
  }

  Future<void> remove(CustomChecklistItem item) async {
    await ref.read(dbProvider).deleteChecklistItem(item.id);
    await _loadToday();
  }
}

final checklistProvider =
    NotifierProvider<ChecklistNotifier, Map<String, List<CustomChecklistItem>>>(
      ChecklistNotifier.new,
    );
