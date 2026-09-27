/// Qur'an reader models + bundled-pack repository (offline-first).
/// Mirrors src/lib/server/quran.ts including the Bismillah strip rule
/// (the first 4 space-separated words of ayah 1 are the Basmala for
/// surahs ≠ 1, 9 — Uthmani datasets embed it with varying diacritics).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SurahMeta {
  const SurahMeta({
    required this.number,
    required this.name,
    required this.nameBn,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
    required this.ayahCount,
  });
  final int number;
  final String name; // Arabic
  final String nameBn;
  final String englishName;
  final String englishNameTranslation;
  final String revelationType;
  final int ayahCount;

  factory SurahMeta.fromJson(Map<String, dynamic> m) => SurahMeta(
    number: (m['number'] as num?)?.toInt() ?? 0,
    name: m['name'] as String? ?? '',
    nameBn: m['nameBn'] as String? ?? m['englishName'] as String? ?? '',
    englishName: m['englishName'] as String? ?? '',
    englishNameTranslation: m['englishNameTranslation'] as String? ?? '',
    revelationType: m['revelationType'] as String? ?? 'Meccan',
    ayahCount: (m['ayahCount'] as num?)?.toInt() ?? 0,
  );
}

class Ayah {
  const Ayah({
    required this.numberInSurah,
    required this.text,
    this.translationBn,
    this.page,
    this.juz,
  });
  final int numberInSurah;
  final String text;
  final String? translationBn;
  final int? page;
  final int? juz;
}

class Surah {
  const Surah({
    required this.meta,
    required this.bismillahPre,
    required this.ayahs,
  });
  final SurahMeta meta;
  final bool bismillahPre;
  final List<Ayah> ayahs;
}

class QuranRepository {
  const QuranRepository._();

  static List<SurahMeta>? _meta;
  static final Map<int, List<Map<String, dynamic>>> _uthmaniBySurah =
      <int, List<Map<String, dynamic>>>{};
  static final Map<int, List<String>> _bnBySurah = <int, List<String>>{};
  static final Map<int, Surah> _cache = <int, Surah>{};
  static bool _loading = false;

  static Future<void> _ensureLoaded() async {
    if (_meta != null || _loading) return;
    _loading = true;
    try {
      final metaRaw = await rootBundle.loadString(
        'assets/content/quran-meta-bn.json',
      );
      final metaDecoded = jsonDecode(metaRaw) as Map<String, dynamic>;
      _meta =
          ((metaDecoded['surahs'] as List?) ?? [])
              .whereType<Map>()
              .map((e) => SurahMeta.fromJson(e.cast<String, dynamic>()))
              .toList()
            ..sort((a, b) => a.number.compareTo(b.number));

      final uthmaniRaw = await rootBundle.loadString(
        'assets/content/quran-uthmani.json',
      );
      final uthmani =
          (jsonDecode(uthmaniRaw) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      for (final s in (uthmani['surahs'] as List? ?? []).whereType<Map>()) {
        _uthmaniBySurah[(s['number'] as num?)?.toInt() ??
            0] = ((s['ayahs'] as List?) ?? [])
            .whereType<Map>()
            .toList()
            .cast<Map<String, dynamic>>();
      }

      final bnRaw = await rootBundle.loadString('assets/content/quran-bn.json');
      final bn =
          (jsonDecode(bnRaw) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      for (final s in (bn['surahs'] as List? ?? []).whereType<Map>()) {
        _bnBySurah[(s['number'] as num?)?.toInt() ??
            0] = ((s['ayahs'] as List?) ?? [])
            .whereType<Map>()
            .map((a) => a['text'] as String? ?? '')
            .toList();
      }
    } finally {
      _loading = false;
    }
  }

  /// 114 surah metadata records.
  static Future<List<SurahMeta>> surahList() async {
    await _ensureLoaded();
    return _meta ?? const <SurahMeta>[];
  }

  /// Full surah with Bengali translation merged, Bismillah stripped for ≠1,9.
  static Future<Surah> surah(int n) async {
    await _ensureLoaded();
    final cached = _cache[n];
    if (cached != null) return cached;

    final ayahsRaw = _uthmaniBySurah[n];
    if (ayahsRaw == null) {
      throw ArgumentError('সূরা পাওয়া যায়নি: $n');
    }
    final bnAyahs = _bnBySurah[n] ?? const <String>[];
    final bismillahPre = n != 1 && n != 9;

    final ayahs = <Ayah>[
      for (var i = 0; i < ayahsRaw.length; i++)
        Ayah(
          numberInSurah:
              (ayahsRaw[i]['numberInSurah'] as num?)?.toInt() ?? i + 1,
          text: _stripBismillah(
            i,
            ayahsRaw[i]['text'] as String? ?? '',
            bismillahPre,
          ),
          translationBn: i < bnAyahs.length ? bnAyahs[i] : null,
          page: (ayahsRaw[i]['page'] as num?)?.toInt(),
          juz: (ayahsRaw[i]['juz'] as num?)?.toInt(),
        ),
    ];

    final meta = (_meta ?? const <SurahMeta>[]).firstWhere(
      (s) => s.number == n,
      orElse: () => SurahMeta(
        number: n,
        name: '',
        nameBn: '',
        englishName: '',
        englishNameTranslation: '',
        revelationType: 'Meccan',
        ayahCount: ayahs.length,
      ),
    );

    final surah = Surah(meta: meta, bismillahPre: bismillahPre, ayahs: ayahs);
    _cache[n] = surah;
    return surah;
  }
}

String _stripBismillah(int index, String text, bool bismillahPre) {
  final clean = text.replaceFirst('\uFEFF', '');
  if (bismillahPre && index == 0 && clean.startsWith('بِسْمِ')) {
    final words = clean.split(RegExp(' +'));
    if (words.length > 4) return words.sublist(4).join(' ');
  }
  return clean;
}
