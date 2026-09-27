/// Drift local database — offline-first Muhasaba engine.
/// Tables mirror the domain: AmalEntries (natural key amalKey+date), Outbox
/// (pending sync batch), GuestProfile (single row), Settings (KV), LastRead,
/// AyahBookmarks.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/sync_merge.dart';
import '../models/domain.dart' as domain;

part 'database.g.dart';

@DataClassName('AmalRow')
class AmalEntries extends Table {
  TextColumn get amalKey => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get valueJson => text()();
  TextColumn get source => text()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {amalKey, date};
}

@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get amalKey => text()();
  TextColumn get date => text()();
  TextColumn get valueJson => text()();
  TextColumn get source => text()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

@DataClassName('GuestProfile')
class GuestProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get gender => text().withDefault(const Constant('M'))();
  TextColumn get language => text().withDefault(const Constant('bn'))();
  TextColumn get city => text().withDefault(const Constant('ঢাকা'))();
  RealColumn get lat => real().withDefault(const Constant(23.8103))();
  RealColumn get lng => real().withDefault(const Constant(90.4125))();
  RealColumn get tz => real().withDefault(const Constant(6.0))();
  TextColumn get method => text().withDefault(const Constant('karachi'))();
  TextColumn get madhhab => text().withDefault(const Constant('hanafi'))();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  IntColumn get hijriAdjust => integer().withDefault(const Constant(0))();
  BoolColumn get onboardingDone =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class SettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('LastReadData')
class LastRead extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get surah => integer().withDefault(const Constant(1))();
  IntColumn get ayah => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AyahBookmark')
class AyahBookmarks extends Table {
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {surah, ayah};
}

@DriftDatabase(
  tables: [
    AmalEntries,
    Outbox,
    GuestProfiles,
    SettingsTable,
    LastRead,
    AyahBookmarks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ── Guest profile (single row, id=1) ────────────────────────────────────────

  Future<GuestProfile> guestProfile() async {
    final row = await (select(
      guestProfiles,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row != null) return row;
    await into(
      guestProfiles,
    ).insert(GuestProfilesCompanion.insert(), mode: InsertMode.insertOrIgnore);
    return (select(guestProfiles)..where((t) => t.id.equals(1))).getSingle();
  }

  Future<void> saveGuestProfile(GuestProfilesCompanion patch) =>
      (update(guestProfiles)..where((t) => t.id.equals(1))).write(patch);

  // ── Settings KV ────────────────────────────────────────────────────────────

  Future<String?> setting(String key) async {
    final rows = await (select(
      settingsTable,
    )..where((t) => t.key.equals(key))).get();
    return rows.isEmpty ? null : rows.first.value;
  }

  Future<void> setSetting(String key, String value) => into(settingsTable)
      .insertOnConflictUpdate(
        SettingsTableCompanion.insert(key: key, value: value),
      );

  // ── Amal entries ───────────────────────────────────────────────────────────

  Future<List<domain.AmalEntry>> entriesForDates(List<String> dates) async {
    final rows = await (select(
      amalEntries,
    )..where((t) => t.date.isIn(dates))).get();
    return rows.map(_rowToEntry).toList();
  }

  Future<List<domain.AmalEntry>> entriesBetween(String from, String to) async {
    final rows = await (select(
      amalEntries,
    )..where((t) => t.date.isBetweenValues(from, to))).get();
    return rows.map(_rowToEntry).toList();
  }

  Future<AmalRow?> _rawEntry(String amalKey, String date) {
    final q = select(amalEntries)
      ..where((t) => t.amalKey.equals(amalKey) & t.date.equals(date));
    return q.getSingleOrNull();
  }

  Future<domain.AmalEntry?> entry(String amalKey, String date) async {
    final row = await _rawEntry(amalKey, date);
    return row == null ? null : _rowToEntry(row);
  }

  domain.AmalEntry _rowToEntry(AmalRow row) => domain.AmalEntry(
    amalKey: row.amalKey,
    date: row.date,
    clientUpdatedAt: row.clientUpdatedAt.toIso8601String(),
    value: _decodeValue(row.valueJson),
    source: row.source,
    serverUpdatedAt: row.serverUpdatedAt?.toIso8601String(),
  );

  static Object? _decodeValue(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  /// Insert/update + queue for sync. Returns the stored entry.
  Future<domain.AmalEntry> writeEntry({
    required String amalKey,
    required String date,
    required Object value,
    required String source,
    required DateTime clientUpdatedAt,
  }) {
    return transaction(() async {
      final valueJson = jsonEncode(value);
      await into(amalEntries).insertOnConflictUpdate(
        AmalEntriesCompanion.insert(
          amalKey: amalKey,
          date: date,
          valueJson: valueJson,
          source: source,
          clientUpdatedAt: clientUpdatedAt,
        ),
      );
      // One pending op per (amalKey, date) — replace any older queued op.
      await (delete(
        outbox,
      )..where((t) => t.amalKey.equals(amalKey) & t.date.equals(date))).go();
      await into(outbox).insert(
        OutboxCompanion.insert(
          amalKey: amalKey,
          date: date,
          valueJson: valueJson,
          source: source,
          clientUpdatedAt: clientUpdatedAt,
        ),
      );
      final row = await _rawEntry(amalKey, date);
      return _rowToEntry(row!);
    });
  }

  /// Mark entries synced after the server accepted them.
  Future<void> markSynced(List<domain.AmalEntry> accepted) async {
    await batch((b) {
      for (final e in accepted) {
        b.update(
          amalEntries,
          AmalEntriesCompanion(
            synced: const Value(true),
            serverUpdatedAt: Value(DateTime.now()),
          ),
          where: (t) => t.amalKey.equals(e.amalKey) & t.date.equals(e.date),
        );
      }
    });
    for (final e in accepted) {
      await (delete(outbox)
            ..where((t) => t.amalKey.equals(e.amalKey) & t.date.equals(e.date)))
          .go();
    }
  }

  Future<int> pendingSyncCount() async {
    final count = countAll();
    final row = await (selectOnly(outbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Snapshot of the pending outbox as domain entries (sync batch payload).
  Future<List<domain.AmalEntry>> pendingEntries({int limit = 500}) async {
    final rows =
        await (select(outbox)
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(limit))
            .get();
    return rows
        .map(
          (r) => domain.AmalEntry(
            amalKey: r.amalKey,
            date: r.date,
            clientUpdatedAt: r.clientUpdatedAt.toIso8601String(),
            value: _decodeValue(r.valueJson),
            source: r.source,
          ),
        )
        .toList();
  }

  /// Latest clientUpdatedAt wins — merge of server entries into local storage
  /// (pure merge logic lives in core/sync_merge.dart, unit-tested there).
  Future<void> mergeServerEntries(List<domain.AmalEntry> remote) =>
      transaction(() async {
        for (final r in remote) {
          final local = await entry(r.amalKey, r.date);
          if (local == null) {
            await into(amalEntries).insert(
              AmalEntriesCompanion.insert(
                amalKey: r.amalKey,
                date: r.date,
                valueJson: jsonEncode(r.value),
                source: r.source,
                clientUpdatedAt: DateTime.parse(r.clientUpdatedAt),
                serverUpdatedAt: r.serverUpdatedAt != null
                    ? Value(DateTime.parse(r.serverUpdatedAt!))
                    : const Value.absent(),
                synced: const Value(true),
              ),
            );
            continue;
          }
          final winner = mergeEntry(local, r);
          if (identical(winner, r) || winner != local) {
            await (update(amalEntries)..where(
                  (t) => t.amalKey.equals(r.amalKey) & t.date.equals(r.date),
                ))
                .write(
                  AmalEntriesCompanion(
                    valueJson: Value(jsonEncode(winner.value)),
                    source: Value(winner.source),
                    clientUpdatedAt: Value(
                      DateTime.parse(winner.clientUpdatedAt),
                    ),
                    serverUpdatedAt: r.serverUpdatedAt != null
                        ? Value(DateTime.parse(r.serverUpdatedAt!))
                        : const Value.absent(),
                    synced: const Value(true),
                  ),
                );
          }
        }
      });

  // ── Last read + bookmarks ─────────────────────────────────────────────────

  Future<LastReadData?> lastReadEntry() async {
    final rows = await (select(lastRead)..where((t) => t.id.equals(1))).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> ensureLastReadRow() =>
      into(lastRead)
          .insert(LastReadCompanion.insert(), mode: InsertMode.insertOrIgnore);

  Future<void> saveLastRead(int surah, int ayah) async {
    await ensureLastReadRow();
    await (update(lastRead)..where((t) => t.id.equals(1))).write(
      LastReadCompanion(
        surah: Value(surah),
        ayah: Value(ayah),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> toggleBookmark(int surah, int ayah, bool add) => add
      ? into(ayahBookmarks).insertOnConflictUpdate(
          AyahBookmarksCompanion.insert(surah: surah, ayah: ayah),
        )
      : (delete(
          ayahBookmarks,
        )..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah))).go();

  Future<Set<(int, int)>> bookmarks() async {
    final rows = await select(ayahBookmarks).get();
    return rows.map((r) => (r.surah, r.ayah)).toSet();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sunnah_life.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
