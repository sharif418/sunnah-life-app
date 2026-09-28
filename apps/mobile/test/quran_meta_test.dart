// Qur'an metadata canary (Phase C/W1c) — the reader shipped to the owner's
// phone with an EMPTY surah list ({ "surahs": [] }). This test loads the
// exact asset the app bundles and asserts the list is complete, so the
// regression can never silently return.
//
// It reads the file from disk (not rootBundle) so it also fails when the
// packages/content → apps/mobile sync step is forgotten.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/models/quran_models.dart';

void main() {
  final file = File('assets/content/quran-meta-bn.json');

  test('bundled quran-meta-bn.json lists exactly 114 surahs', () {
    expect(file.existsSync(), isTrue,
        reason: 'assets/content/quran-meta-bn.json missing — run '
            '`bun run content:sync` from the repo root');
    final Map<String, dynamic> decoded =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final surahs = (decoded['surahs'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SurahMeta.fromJson(e.cast<String, dynamic>()))
        .toList();
    expect(surahs, hasLength(114), reason: 'the reader would show NOTHING');
    expect(
      surahs.map((s) => s.number).toSet(),
      hasLength(114),
      reason: 'surah numbers must be unique 1..114',
    );
    expect(surahs.first.number, 1);
    expect(surahs.last.number, 114);
  });

  test('every surah has a Bengali name, an Arabic name and an ayah count', () {
    final Map<String, dynamic> decoded =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final m in (decoded['surahs'] as List? ?? []).whereType<Map>()) {
      final s = SurahMeta.fromJson(m.cast<String, dynamic>());
      expect(s.nameBn, isNotEmpty,
          reason: 'surah ${s.number} has no Bengali name');
      expect(s.name, anyOf(contains('سورة'), contains('سُورَة')),
          reason: 'surah ${s.number} Arabic name looks wrong: ${s.name}');
      expect(s.ayahCount, greaterThanOrEqualTo(3),
          reason: 'surah ${s.number} ayah count');
      expect(['মাক্কী', 'মাদানী'], contains(s.revelationType),
          reason: 'surah ${s.number} revelation type');
    }
  });

  test('ayah counts total 6236 (whole Qurʼān)', () {
    final Map<String, dynamic> decoded =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final total = ((decoded['surahs'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ((m['ayahCount'] as num?) ?? 0).toInt()))
        .fold<int>(0, (a, b) => a + b);
    expect(total, 6236);
  });

  test('anchors: ফাতিহা 7, বাকারা 286 (মাদানী), ইউসুফ মাক্কী, নাস 6', () {
    final Map<String, dynamic> decoded =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final byNumber = <int, SurahMeta>{};
    for (final m in (decoded['surahs'] as List? ?? []).whereType<Map>()) {
      final s = SurahMeta.fromJson(m.cast<String, dynamic>());
      byNumber[s.number] = s;
    }
    expect(byNumber[1]!.nameBn, 'আল-ফাতিহা');
    expect(byNumber[1]!.ayahCount, 7);
    expect(byNumber[2]!.ayahCount, 286);
    expect(byNumber[2]!.revelationType, 'মাদানী');
    expect(byNumber[12]!.nameBn, 'ইউসুফ');
    expect(byNumber[12]!.revelationType, 'মাক্কী');
    expect(byNumber[114]!.nameBn, 'আন-নাস');
    expect(byNumber[114]!.ayahCount, 6);
  });
}
