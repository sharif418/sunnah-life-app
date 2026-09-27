// Sync conflict tests — the pure merge rules (latest clientUpdatedAt wins).
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/sync_merge.dart';
import 'package:sunnah_life/models/domain.dart';

AmalEntry e(String stamp, Object value) => AmalEntry(
      amalKey: 'salat_fajr',
      date: '2025-06-15',
      clientUpdatedAt: stamp,
      value: value,
      source: 'manual',
    );

void main() {
  group('mergeEntry — latest clientUpdatedAt wins', () {
    test('remote strictly newer → remote wins', () {
      final local = e('2025-06-15T10:00:00Z', 'alone');
      final remote = e('2025-06-15T11:00:00Z', 'jamaat');
      expect(mergeEntry(local, remote).value, 'jamaat');
    });

    test('local strictly newer → local wins', () {
      final local = e('2025-06-15T12:00:00Z', 'alone');
      final remote = e('2025-06-15T11:00:00Z', 'jamaat');
      expect(mergeEntry(local, remote).value, 'alone');
    });

    test('exact tie → remote (already persisted) wins so the client converges',
        () {
      final local = e('2025-06-15T10:00:00Z', 'alone');
      final remote = e('2025-06-15T10:00:00Z', 'qaza');
      expect(mergeEntry(local, remote).value, 'qaza');
    });

    test('unparseable local stamp → remote wins', () {
      final local = e('not-a-date', 'alone');
      final remote = e('2025-06-15T11:00:00Z', 'jamaat');
      expect(mergeEntry(local, remote).value, 'jamaat');
    });

    test('unparseable remote stamp → local wins', () {
      final local = e('2025-06-15T11:00:00Z', 'alone');
      final remote = e('garbage', 'jamaat');
      expect(mergeEntry(local, remote).value, 'alone');
    });
  });

  group('mergeLists — batch dedup on (amalKey, date)', () {
    test('union of distinct days + conflict resolution per pair', () {
      final local = [
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-15',
            clientUpdatedAt: '2025-06-15T09:00:00Z',
            value: true,
            source: 'manual'),
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-16',
            clientUpdatedAt: '2025-06-16T23:00:00Z',
            value: 5,
            source: 'manual'),
        AmalEntry(
            amalKey: 'b',
            date: '2025-06-15',
            clientUpdatedAt: '2025-06-15T09:00:00Z',
            value: 'alone',
            source: 'manual'),
      ];
      final remote = [
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-15',
            clientUpdatedAt: '2025-06-15T10:00:00Z',
            value: false,
            source: 'manual'), // newer → wins
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-16',
            clientUpdatedAt: '2025-06-16T08:00:00Z',
            value: 2,
            source: 'manual'), // older → local wins
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-17',
            clientUpdatedAt: '2025-06-17T09:00:00Z',
            value: 'jamaat',
            source: 'manual'), // new day → added
      ];

      final merged = mergeLists(local, remote);
      expect(merged.length, 4); // 3 pairs + 1 new

      bool a15(Object? v) =>
          merged.any((m) =>
              m.date == '2025-06-15' && m.amalKey == 'a' && m.value == v);
      expect(a15(false), isTrue, reason: 'remote newer wins');
      expect(a15(true), isFalse);

      final a16 = merged
          .firstWhere((m) => m.date == '2025-06-16' && m.amalKey == 'a');
      expect(a16.value, 5, reason: 'local newer wins');

      expect(
          merged.any((m) =>
              m.date == '2025-06-17' && m.amalKey == 'a'),
          isTrue);
    });

    test('empty inputs', () {
      expect(mergeLists(const <AmalEntry>[], const <AmalEntry>[]), isEmpty);
      final local = [
        AmalEntry(
            amalKey: 'a',
            date: '2025-06-15',
            clientUpdatedAt: '2025-06-15T09:00:00Z',
            value: true,
            source: 'manual'),
      ];
      expect(mergeLists(local, const <AmalEntry>[]), hasLength(1));
    });
  });
}
