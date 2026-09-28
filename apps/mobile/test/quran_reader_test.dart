// Qur'an reader W3a — pure logic: audio URL building (padding + reciter
// catalog), Bengali-digit parsing, jump-estimation math, list search
// filtering, and the repository's single-flight/memoization guarantees
// (verified through the injectable asset loader with tiny fake packs,
// including the first-open race regression and Bismillah-strip behavior).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/features/ilm/quran_audio.dart';
import 'package:sunnah_life/models/quran_models.dart';

const _basmala =
    'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

String _metaPack() => jsonEncode({
  'surahs': [
    for (final (n, bn, en, count) in [
      (1, 'আল-ফাতিহা', 'Al-Fatihah', 7),
      (2, 'আল-বাকারা', 'Al-Baqarah', 3),
      (9, 'আত-তাওবা', 'At-Tawbah', 3),
      (114, 'আন-নাস', 'An-Nas', 6),
    ])
      {
        'number': n,
        'name': 'سُورَةُ $n',
        'nameBn': bn,
        'englishName': en,
        'englishNameTranslation': 'x',
        'revelationType': 'মাক্কী',
        'ayahCount': count,
      },
  ],
});

String _uthmaniPack() => jsonEncode({
  'data': {
    'surahs': [
      {
        'number': 1,
        'ayahs': [
          for (var i = 1; i <= 7; i++)
            {
              'number': i,
              'numberInSurah': i,
              'text': 'فاتحة آية $i',
              'page': 1,
              'juz': 1,
            },
        ],
      },
      {
        'number': 2,
        'ayahs': [
          // Ayah 1 embeds the Basmala (4 space-separated words) — must strip.
          {
            'number': 8,
            'numberInSurah': 1,
            'text': '$_basmala বাকারা প্রথম আয়াত',
            'page': 2,
            'juz': 1,
          },
          for (var i = 2; i <= 3; i++)
            {'number': 7 + i, 'numberInSurah': i, 'text': 'বাকারা আয়াত $i'},
        ],
      },
      {
        'number': 9,
        'ayahs': [
          // Surah 9 never carries the Basmala — must NOT strip.
          {
            'number': 1230,
            'numberInSurah': 1,
            'text': '$_basmala তাওবা প্রথম আয়াত',
            'page': 3,
            'juz': 2,
          },
          for (var i = 2; i <= 3; i++)
            {'number': 1229 + i, 'numberInSurah': i, 'text': 'তাওবা আয়াত $i'},
        ],
      },
      {
        'number': 114,
        'ayahs': [
          for (var i = 1; i <= 6; i++)
            {'number': 6230 + i, 'numberInSurah': i, 'text': 'নাস আয়াত $i'},
        ],
      },
    ],
  },
});

String _bnPack() => jsonEncode({
  'data': {
    'surahs': [
      for (final (n, count) in [(1, 7), (2, 3), (9, 3), (114, 6)])
        {
          'number': n,
          'ayahs': [
            for (var i = 1; i <= count; i++) {'text': 'অনুবাদ $n:$i'},
          ],
        },
    ],
  },
});

class _FakeAssets {
  final Map<String, String> files;
  final Map<String, int> reads = {};
  int failNextCalls = 0;

  _FakeAssets()
    : files = {
        'assets/content/quran-meta-bn.json': _metaPack(),
        'assets/content/quran-uthmani.json': _uthmaniPack(),
        'assets/content/quran-bn.json': _bnPack(),
      };

  Future<String> load(String path) async {
    if (failNextCalls > 0) {
      failNextCalls--;
      throw StateError('simulated asset failure: $path');
    }
    reads[path] = (reads[path] ?? 0) + 1;
    return files[path]!;
  }
}

void main() {
  setUp(QuranRepository.resetForTesting);
  tearDown(QuranRepository.resetForTesting);

  group('Dart 3.13.4 hazard regression — map ??= whenComplete(remove)', () {
    // The W3a memoization originally read
    //   _pendingSurah[n] ??= _buildSurah(n).whenComplete(() => _pendingSurah.remove(n));
    // and the SURAH FUTURE NEVER COMPLETED on Dart 3.13.4 (Flutter 3.47.5,
    // 2026-09-17) — the reader deadlocked on every first open. The body ran to
    // completion (caches filled) but the awaited wrapper future never
    // resolved. Minimal repro below, asserted with a timeout so the suite
    // stays green while pinning the behavior; the repository avoids the shape.
    Future<int> body() async {
      await Future<void>.value();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 42;
    }

    test('map-memoized whenComplete never completes on Dart 3.13.4', () async {
      final pending = <int, Future<int>>{};
      Future<int> toxic(int n) =>
          pending[n] ??= body().whenComplete(() => pending.remove(n));
      await expectLater(
        toxic(1).timeout(const Duration(seconds: 2)),
        throwsA(isA<TimeoutException>()),
      );
      expect(pending, isEmpty,
          reason: 'the body ran and the callback removed the entry — '
              'only the WRAPPER future never resolved');
    });

    test('the restructured shape resolves (inner stored, wrapper local)',
        () async {
      final pending = <int, Future<int>>{};
      Future<int> safe(int n) {
        final inFlight = pending[n];
        if (inFlight != null) return inFlight;
        final inner = body();
        pending[n] = inner;
        return inner.whenComplete(() => pending.remove(n));
      }
      final a = safe(1);
      final b = safe(1);
      expect(await a, 42);
      expect(await b, 42);
      expect(pending, isEmpty);
    });
  });

  group('ayahAudioUrl — padding + reciter', () {
    test('alafasy fatiha 1:1 pads to 001001.mp3', () {
      expect(
        ayahAudioUrl(
          reciter: reciterById('alafasy'),
          surah: 1,
          ayah: 1,
        ),
        'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
      );
    });

    test('last surah + last ayah: 114006', () {
      expect(
        ayahAudioUrl(reciter: reciterById('sudais'), surah: 114, ayah: 6),
        'https://everyayah.com/data/'
        'Abdurrahmaan_As-Sudais_192kbps/114006.mp3',
      );
    });

    test('double padding across the reciter catalog', () {
      for (final r in kQuranReciters) {
        expect(
          ayahAudioUrl(reciter: r, surah: 2, ayah: 255),
          'https://everyayah.com/data/${r.path}/002255.mp3',
        );
      }
    });

    test('unknown/null reciter falls back to Alafasy (the config default)',
        () {
      expect(reciterById(null).id, 'alafasy');
      expect(reciterById('does-not-exist').id, 'alafasy');
      expect(reciterById('husary').id, 'husary');
    });

    test('catalog: unique ids and paths, ≥ 3 reciters, non-empty names', () {
      expect(kQuranReciters.length, greaterThanOrEqualTo(3));
      expect(
        kQuranReciters.map((r) => r.id).toSet().length,
        kQuranReciters.length,
      );
      expect(
        kQuranReciters.map((r) => r.path).toSet().length,
        kQuranReciters.length,
      );
      for (final r in kQuranReciters) {
        expect(r.nameBn, isNotEmpty);
        expect(r.nameEn, isNotEmpty);
        expect(r.nameAr, isNotEmpty);
        expect(r.nameFor('en'), r.nameEn);
        expect(r.nameFor('ar'), r.nameAr);
        expect(r.nameFor('bn'), r.nameBn);
        expect(r.nameFor('xx'), r.nameBn);
      }
    });
  });

  group('parseBnDigits — Bengali + ASCII input', () {
    test('ASCII digits', () {
      expect(parseBnDigits('7'), 7);
      expect(parseBnDigits('286'), 286);
      expect(parseBnDigits('114'), 114);
    });

    test('Bengali digits', () {
      expect(parseBnDigits('৭'), 7);
      expect(parseBnDigits('২৮৬'), 286);
      expect(parseBnDigits('১১৪'), 114);
    });

    test('trims whitespace; allows a leading plus', () {
      expect(parseBnDigits('  ৫ '), 5);
      expect(parseBnDigits('\t৩\n'), 3);
      expect(parseBnDigits('+7'), 7);
      expect(parseBnDigits('+২৮৬'), 286);
    });

    test('rejects empty, sign-only, mixed-script and non-digits', () {
      expect(parseBnDigits(''), isNull);
      expect(parseBnDigits('   '), isNull);
      expect(parseBnDigits('+'), isNull);
      expect(parseBnDigits('+ '), isNull);
      expect(parseBnDigits('a7'), isNull);
      expect(parseBnDigits('৭a'), isNull);
      expect(parseBnDigits('1৭'), isNull, reason: 'mixed scripts');
      expect(parseBnDigits('7.5'), isNull);
      expect(parseBnDigits('-7'), isNull);
      expect(parseBnDigits('৭৫-'), isNull);
    });
  });

  group('estimateJumpOffset — coarse jump math', () {
    test('degenerate lists/extents stay at zero', () {
      expect(estimateJumpOffset(ayahIndex: 0, totalAyahs: 0, maxScrollExtent: 1000), 0);
      expect(estimateJumpOffset(ayahIndex: 0, totalAyahs: 1, maxScrollExtent: 1000), 0);
      expect(estimateJumpOffset(ayahIndex: 3, totalAyahs: 7, maxScrollExtent: 0), 0);
      expect(
        estimateJumpOffset(ayahIndex: 3, totalAyahs: 7, maxScrollExtent: -5),
        0,
      );
    });

    test('first ayah → top, last ayah → very bottom', () {
      expect(estimateJumpOffset(ayahIndex: 0, totalAyahs: 7, maxScrollExtent: 2400), 0);
      expect(estimateJumpOffset(ayahIndex: 6, totalAyahs: 7, maxScrollExtent: 2400), 2400);
    });

    test('monotonic in the ayah index', () {
      var prev = -1.0;
      for (var i = 0; i < 286; i++) {
        final v = estimateJumpOffset(ayahIndex: i, totalAyahs: 286, maxScrollExtent: 9000);
        expect(v, greaterThan(prev));
        expect(v, greaterThanOrEqualTo(0), reason: 'index 0 legitimately maps to 0');
        expect(v, lessThanOrEqualTo(9000),
            reason: 'the last index legitimately maps to the extent');
        prev = v;
      }
    });

    test('out-of-range indices clamp instead of overshooting', () {
      expect(estimateJumpOffset(ayahIndex: 99, totalAyahs: 7, maxScrollExtent: 1000), 1000);
      expect(estimateJumpOffset(ayahIndex: -5, totalAyahs: 7, maxScrollExtent: 1000), 0);
    });
  });

  group('QuranRepository.filterSurahs — list search', () {
    final surahs = [
      SurahMeta(
        number: 1,
        name: 'س1',
        nameBn: 'আল-ফাতিহা',
        englishName: 'Al-Fatihah',
        englishNameTranslation: 'The Opening',
        revelationType: 'মাক্কী',
        ayahCount: 7,
      ),
      SurahMeta(
        number: 2,
        name: 'س2',
        nameBn: 'আল-বাকারা',
        englishName: 'Al-Baqarah',
        englishNameTranslation: 'The Cow',
        revelationType: 'মাদানী',
        ayahCount: 286,
      ),
      SurahMeta(
        number: 12,
        name: 'س12',
        nameBn: 'ইউসুফ',
        englishName: 'Yusuf',
        englishNameTranslation: 'Joseph',
        revelationType: 'মাক্কী',
        ayahCount: 111,
      ),
    ];

    test('empty and whitespace queries return the full list', () {
      expect(QuranRepository.filterSurahs(surahs, ''), same(surahs));
      expect(QuranRepository.filterSurahs(surahs, '   '), same(surahs));
      expect(
        QuranRepository.filterSurahs(surahs, '\t\n').length,
        surahs.length,
      );
    });

    test('Bengali name substring', () {
      final r = QuranRepository.filterSurahs(surahs, 'ফাতিহা');
      expect(r.map((s) => s.number), [1]);
      expect(QuranRepository.filterSurahs(surahs, 'ইউ').map((s) => s.number), [
        12,
      ]);
    });

    test('English name is case-insensitive', () {
      expect(
        QuranRepository.filterSurahs(surahs, 'baqarah').map((s) => s.number),
        [2],
      );
      expect(
        QuranRepository.filterSurahs(surahs, 'AL-FATIHAH').map((s) => s.number),
        [1],
      );
    });

    test('exact surah number in ASCII digits — not a prefix match', () {
      final r = QuranRepository.filterSurahs(surahs, '1');
      expect(r.map((s) => s.number), [1], reason: "'1' must not match 12");
      expect(QuranRepository.filterSurahs(surahs, '12').map((s) => s.number), [
        12,
      ]);
    });

    test('exact surah number in Bengali digits', () {
      expect(QuranRepository.filterSurahs(surahs, '২').map((s) => s.number), [
        2,
      ]);
      expect(QuranRepository.filterSurahs(surahs, '১২').map((s) => s.number), [
        12,
      ]);
    });

    test('no match → empty; garbage query does not throw', () {
      expect(QuranRepository.filterSurahs(surahs, 'zzz'), isEmpty);
      expect(QuranRepository.filterSurahs(surahs, '৩x'), isEmpty);
    });
  });

  group('QuranRepository — single-flight load + caching', () {
    test('concurrent callers share ONE load (the first-open race)', () async {
      final assets = _FakeAssets();
      QuranRepository.assetLoaderForTesting = assets.load;

      // The W3a bug: the list screen's AppBar + body (or two surah() calls
      // in one build pass) raced _ensureLoaded's `_loading` bool and the
      // loser read empty packs → ArgumentError. Now all callers await the
      // same memoized future.
      final results = await Future.wait([
        QuranRepository.surahList(),
        QuranRepository.surah(2),
        QuranRepository.surah(2),
        QuranRepository.surah(9),
      ]);

      expect(results[0], hasLength(4));
      expect((results[1] as Surah).ayahs, hasLength(3));
      expect(identical(results[1], results[2]), isTrue,
          reason: 'two surah(2) calls in the same pass share one build');
      expect((results[3] as Surah).ayahs.first.text, contains('তাওবা'));

      // Each pack read exactly once despite five concurrent callers.
      expect(assets.reads['assets/content/quran-meta-bn.json'], 1);
      expect(assets.reads['assets/content/quran-uthmani.json'], 1);
      expect(assets.reads['assets/content/quran-bn.json'], 1);
    });

    test('second open after success hits the cache (no re-reads)', () async {
      final assets = _FakeAssets();
      QuranRepository.assetLoaderForTesting = assets.load;
      await QuranRepository.surahList();
      await QuranRepository.surah(1);
      await QuranRepository.surah(2);

      expect(assets.reads['assets/content/quran-meta-bn.json'], 1);
      expect(assets.reads['assets/content/quran-uthmani.json'], 1);
      expect(assets.reads['assets/content/quran-bn.json'], 1);

      final again = await QuranRepository.surah(1);
      expect(assets.reads['assets/content/quran-uthmani.json'], 1);
      expect(again.meta.nameBn, 'আল-ফাতিহা');
    });

    test('a failed load stays retryable', () async {
      final assets = _FakeAssets()..failNextCalls = 1;
      QuranRepository.assetLoaderForTesting = assets.load;

      await expectLater(
        QuranRepository.surahList(),
        throwsStateError,
      );

      final surahs = await QuranRepository.surahList();
      expect(surahs, hasLength(4), reason: 'second open retried and loaded');
    });

    test('surah(n) for a missing surah still throws ArgumentError', () async {
      QuranRepository.assetLoaderForTesting = _FakeAssets().load;
      await QuranRepository.surahList();
      await expectLater(
        QuranRepository.surah(999),
        throwsArgumentError,
      );
    });

    test('Bismillah strip: surah ≠ 1,9 loses the first 4 words; 1 and 9 keep',
        () async {
      QuranRepository.assetLoaderForTesting = _FakeAssets().load;
      final s2 = await QuranRepository.surah(2);
      expect(s2.bismillahPre, isTrue);
      expect(s2.ayahs.first.text, 'বাকারা প্রথম আয়াত');

      final s1 = await QuranRepository.surah(1);
      expect(s1.bismillahPre, isFalse);
      expect(s1.ayahs.first.text, 'فاتحة آية 1');

      final s9 = await QuranRepository.surah(9);
      expect(s9.bismillahPre, isFalse);
      expect(s9.ayahs.first.text, contains(_basmala),
          reason: 'At-Tawbah never carries the Basmala');
    });

    test('translation merge + meta fallback', () async {
      QuranRepository.assetLoaderForTesting = _FakeAssets().load;
      final s1 = await QuranRepository.surah(1);
      expect(s1.ayahs.first.translationBn, 'অনুবাদ 1:1');
      expect(s1.ayahs.first.juz, 1);
      expect(s1.meta.ayahCount, 7);
    });
  });
}
