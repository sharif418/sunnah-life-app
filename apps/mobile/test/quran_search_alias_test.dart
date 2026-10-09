// Common spellings find their surah (2026-10-09): the strict substring
// match missed "fatiha", "rahman", "ইয়াসিন", "কাহাফ".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/models/quran_models.dart';

void main() {
  late List<SurahMeta> surahs;
  setUpAll(() async {
    QuranRepository.assetLoaderForTesting = (p) => File(p).readAsString();
    surahs = await QuranRepository.surahList();
  });
  tearDownAll(QuranRepository.resetForTesting);

  for (final (q, n) in [
    ('fatiha', 1),
    ('Fatiha', 1),
    ('rahman', 55),
    ('yasin', 36),
    ('ইয়াসিন', 36),
    ('ইয়াসীন', 36),
    ('কাহাফ', 18),
    ('কাহফ', 18),
    ('বাকারা', 2),
    ('mulk', 67),
    ('২', 2),
  ]) {
    test('"$q" finds surah $n', () {
      final hits = QuranRepository.filterSurahs(surahs, q).map((s) => s.number);
      expect(hits, contains(n));
    });
  }

  test('30 paras, starting at 1:1 and ending inside an-Naba', () async {
    final starts = await QuranRepository.juzStarts();
    expect(starts.length, 30);
    expect((starts.first.surah, starts.first.ayah), (1, 1));
    expect(starts.last.surah, 78);
  });
}
