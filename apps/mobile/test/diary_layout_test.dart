// The Today diary follows the paper muhasaba diary. lib/core/diary_layout.dart
// mirrors packages/content/diary-instructions.json as Dart constants (so the
// most-opened screen renders without an asset round-trip); this test keeps
// the mirror honest and pins the grouping rules.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/core/diary_layout.dart';

void main() {
  final json =
      jsonDecode(File('assets/content/diary-instructions.json').readAsStringSync())
          as Map<String, dynamic>;

  test('kPaperDiaryLayout mirrors diary-instructions.json paperLayout exactly', () {
    final groups = (json['paperLayout'] as List).cast<Map<String, dynamic>>();
    expect(kPaperDiaryLayout.length, groups.length);
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final mine = kPaperDiaryLayout[i];
      expect(mine.groupBn, g['groupBn']);
      expect(mine.noteBn, g['noteBn']);
      final rows = (g['rows'] as List).cast<Map<String, dynamic>>();
      expect(mine.rows.length, rows.length, reason: g['groupBn'] as String);
      for (var j = 0; j < rows.length; j++) {
        expect(mine.rows[j].labelBn, rows[j]['labelBn']);
        expect(mine.rows[j].amalKeys, (rows[j]['amalKeys'] as List).cast<String>());
      }
    }
  });

  test('kDiaryInstructionsBn mirrors the paper instructions', () {
    final instructions = (json['instructions'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => e['textBn'] as String)
        .toList();
    expect(kDiaryInstructionsBn, instructions);
    expect(kDiaryCoverQuoteAr, json['coverQuoteAr']);
    expect(kDiaryCoverQuoteBn, json['coverQuoteBn']);
  });

  test('the guest fallback catalog mirrors amal-catalog.json in full', () {
    final catalog = (jsonDecode(File('assets/content/amal-catalog.json').readAsStringSync())
            as Map<String, dynamic>)['definitions'] as List;
    final defs = {for (final d in fallbackDefinitions()) d.key: d};
    expect(defs.length, catalog.length);
    for (final raw in catalog.cast<Map<String, dynamic>>()) {
      final d = defs[raw['key']];
      expect(d, isNotNull, reason: '${raw['key']} missing from the fallback');
      expect(d!.titleBn, raw['titleBn']);
      expect(d.cadence, raw['cadence']);
      expect(d.sortOrder, raw['sortOrder']);
      expect(d.unit, raw['unit']);
      expect(d.autoSource, raw['autoSource']);
      final target = raw['targetJson'] == null
          ? null
          : (jsonDecode(raw['targetJson'] as String) as Map).cast<String, num>();
      expect(d.target, target, reason: '${raw['key']} target');
    }
  });

  test('layoutDiary: paper groups in paper order + every other amal as an extra', () {
    final defs = fallbackDefinitions();
    final daily = defs.where((d) => d.cadence == 'daily').toList();
    final (:paper, :extras) = layoutDiary(daily);

    expect(paper.map((g) => g.titleBn), [
      'সালাত ট্র্যাকার',
      'বিতর',
      'সুন্নাহ ও নফল সালাত',
      'জিকর ও তিলাওয়াত',
      'ইলম বা জ্ঞানার্জন',
      'করণীয়-বর্জনীয় কাজ (হারাম বর্জন)',
    ]); // weekly/monthly groups drop out: nothing of theirs is in `daily`
    expect(paper.first.rows.map((r) => r.labelBn), ['ফজর', 'যোহর', 'আসর', 'মাগরিব', 'এশা']);
    // the two-key ইলম row keeps each amal's own title
    final ilm = paper.firstWhere((g) => g.titleBn == 'ইলম বা জ্ঞানার্জন');
    expect(ilm.rows.map((r) => r.def.key), ['tilawat_minutes', 'tilawat']);
    expect(ilm.rows.every((r) => r.labelBn == null), isTrue);

    // nothing is lost: paper rows + extras = every daily definition
    final placed = {
      for (final g in paper)
        for (final r in g.rows) r.def.key,
      for (final d in extras) d.key,
    };
    expect(placed, daily.map((d) => d.key).toSet());
    expect(extras.map((d) => d.key), contains('durood_100'));
    expect(extras.map((d) => d.key), isNot(contains('salat_fajr')));
  });
}
