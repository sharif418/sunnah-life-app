/// Qur'an reader models + bundled-pack repository (offline-first).
/// Mirrors src/lib/server/quran.ts including the Bismillah strip rule
/// (the first 4 space-separated words of ayah 1 are the Basmala for
/// surahs ≠ 1, 9 — Uthmani datasets embed it with varying diacritics).
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../core/bn_digits.dart' show parseBnDigits;

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
  static final Map<int, Future<Surah>> _pendingSurah = <int, Future<Surah>>{};

  /// Asset loader — `rootBundle` in the app; tests inject `dart:io` reads
  /// (rootBundle platform-channel responses cannot complete inside
  /// `tester.runAsync`, while `compute` cannot cross the plain fake-async
  /// zone — the injectable loader lets tests pre-warm both together).
  static Future<String> Function(String path) _loadAsset =
      rootBundle.loadString;

  /// Test seam for the asset source. Call [resetForTesting] to restore.
  @visibleForTesting
  static set assetLoaderForTesting(
    Future<String> Function(String path) loader,
  ) {
    _loadAsset = loader;
  }

  /// Clears every static (packs, caches, in-flight futures) and restores
  /// the production asset loader — keeps repository unit tests isolated.
  @visibleForTesting
  static void resetForTesting() {
    _loadAsset = rootBundle.loadString;
    _meta = null;
    _uthmaniBySurah.clear();
    _bnBySurah.clear();
    _cache.clear();
    _pendingSurah.clear();
    _loading = null;
  }

  /// Decodes the 38KB metadata pack off the main isolate.
  static List<SurahMeta> _decodeMetaPack(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ((decoded['surahs'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SurahMeta.fromJson(e.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  /// Decodes the 2.1MB Uthmani pack off the main isolate.
  static Map<int, List<Map<String, dynamic>>> _decodeUthmaniPack(String raw) {
    final uthmani =
        (jsonDecode(raw) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final out = <int, List<Map<String, dynamic>>>{};
    for (final s in (uthmani['surahs'] as List? ?? []).whereType<Map>()) {
      out[(s['number'] as num?)?.toInt() ?? 0] = ((s['ayahs'] as List?) ?? [])
          .whereType<Map>()
          .toList()
          .cast<Map<String, dynamic>>();
    }
    return out;
  }

  /// Decodes the 2.9MB Bengali translation pack off the main isolate.
  static Map<int, List<String>> _decodeBnPack(String raw) {
    final bn =
        (jsonDecode(raw) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final out = <int, List<String>>{};
    for (final s in (bn['surahs'] as List? ?? []).whereType<Map>()) {
      out[(s['number'] as num?)?.toInt() ?? 0] = ((s['ayahs'] as List?) ?? [])
          .whereType<Map>()
          .map((a) => a['text'] as String? ?? '')
          .toList();
    }
    return out;
  }

  static Future<void>? _loading;

  /// Single-flight load: the FIRST caller starts the load and every concurrent
  /// caller awaits the SAME future (previously a `_loading` bool made the
  /// AppBar-title and body FutureBuilders race — the second caller returned
  /// before the packs were in and hit `সূরা পাওয়া যায়নি`).
  static Future<void> _ensureLoaded() {
    if (_meta != null) return Future<void>.value();
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    // The inner future is stored FIRST and the completion wrapper built on a
    // local — `map[k] ??= f.whenComplete(() => map.remove(k))` was empirically
    // a NEVER-COMPLETING future on Dart 3.13.4 (the awaited wrapper future
    // never resolved even though the body finished — reproduced minimal in
    // test/quran_reader_test.dart 'map-memoized whenComplete never completes
    // on Dart 3.13.4'). The reader would have deadlocked on every first open.
    final inner = _loadAll();
    _loading = inner;
    return inner.whenComplete(() {
      // A failed load must stay retryable; a successful one keeps the
      // memoized (already-completed) future — later awaits are free.
      if (_meta == null) _loading = null;
    });
  }

  static Future<void> _loadAll() async {
    final metaRaw = await _loadAsset('assets/content/quran-meta-bn.json');
    final uthmaniRaw = await _loadAsset('assets/content/quran-uthmani.json');
    final bnRaw = await _loadAsset('assets/content/quran-bn.json');
    // jsonDecode of ~5MB takes hundreds of ms — it must never run on the UI
    // isolate (W3a). The three packs decode in background isolates via
    // `compute`; the raw strings cross as a one-time copy.
    //
    // `flutter test` sets FLUTTER_TEST=true — `compute` (Isolate.run) under
    // the test harness leaves the runner awaiting an isolate message that
    // the fake-async zone never delivers (flutter#98362), so tests decode
    // inline instead. Production boots with no such env var.
    final useIsolate = Platform.environment['FLUTTER_TEST'] != 'true';
    final results = useIsolate
        ? await Future.wait([
            compute(_decodeMetaPack, metaRaw, debugLabel: 'quran-meta'),
            compute(_decodeUthmaniPack, uthmaniRaw, debugLabel: 'quran-uthmani'),
            compute(_decodeBnPack, bnRaw, debugLabel: 'quran-bn'),
          ])
        : await Future.wait([
            Future(() => _decodeMetaPack(metaRaw)),
            Future(() => _decodeUthmaniPack(uthmaniRaw)),
            Future(() => _decodeBnPack(bnRaw)),
          ]);
    _meta = results[0] as List<SurahMeta>;
    _uthmaniBySurah
      ..clear()
      ..addAll(results[1] as Map<int, List<Map<String, dynamic>>>);
    _bnBySurah
      ..clear()
      ..addAll(results[2] as Map<int, List<String>>);
  }

  /// 114 surah metadata records.
  static Future<List<SurahMeta>> surahList() async {
    await _ensureLoaded();
    return _meta ?? const <SurahMeta>[];
  }

  /// Pure list-screen search filter (unit-tested): Bengali or English name
  /// substring (English case-insensitive) or an exact surah number typed in
  /// either ASCII or Bengali digits (`2` and `২` both find আল-বাকারা).
  static List<SurahMeta> filterSurahs(List<SurahMeta> surahs, String query) {
    final q = query.trim();
    if (q.isEmpty) return surahs;
    final lower = q.toLowerCase();
    final n = parseBnDigits(q);
    return surahs
        .where(
          (s) =>
              s.nameBn.contains(q) ||
              s.englishName.toLowerCase().contains(lower) ||
              (n != null && s.number == n),
        )
        .toList();
  }

  /// Full surah with Bengali translation merged, Bismillah stripped for ≠1,9.
  /// The per-surah future is memoized too: the AppBar title and the body of
  /// the reader both call this in the same build pass and now share one
  /// in-flight build instead of racing two.
  static Future<Surah> surah(int n) {
    final cached = _cache[n];
    if (cached != null) return Future.value(cached);
    final inFlight = _pendingSurah[n];
    if (inFlight != null) return inFlight;
    // Same Dart 3.13.4 hazard as _ensureLoaded: never assign the
    // whenComplete-wrapper into the map it is removing itself from.
    final inner = _buildSurah(n);
    _pendingSurah[n] = inner;
    return inner.whenComplete(() => _pendingSurah.remove(n));
  }

  static Future<Surah> _buildSurah(int n) async {
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
