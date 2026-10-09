/// Typed content-pack models + the bundled asset loader (offline-first).
/// Packs mirror /content/*.json; small in-app fallbacks keep guest features
/// alive when a pack ships empty (the packs are owned by the content agent).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/honorific.dart';

// ── Pack models (mirror domain.ts content interfaces) ────────────────────────

class DuaCategory {
  const DuaCategory({required this.key, required this.labelBn});
  final String key;
  final String labelBn;
}

class DuaItem {
  const DuaItem({
    required this.id,
    required this.category,
    required this.titleBn,
    required this.arabic,
    this.translitBn,
    required this.translationBn,
    required this.reference,
    this.virtue,
  });
  final String id;
  final String category;
  final String titleBn;
  final String arabic;
  final String? translitBn;
  final String translationBn;
  final String reference;
  final String? virtue;

  factory DuaItem.fromJson(Map<String, dynamic> m) => DuaItem(
    id: m['id'] as String? ?? '',
    category: m['category'] as String? ?? '',
    titleBn: m['titleBn'] as String? ?? '',
    arabic: m['arabic'] as String? ?? '',
    translitBn: m['translitBn'] as String?,
    translationBn: m['translationBn'] as String? ?? '',
    reference: m['reference'] as String? ?? '',
    virtue: m['virtue'] as String?,
  );
}

class DhikrItem {
  const DhikrItem({
    required this.id,
    required this.order,
    required this.arabic,
    required this.translitBn,
    required this.translationBn,
    required this.count,
    required this.reference,
    this.virtue,
  });
  final String id;
  final int order;
  final String arabic;
  final String translitBn;
  final String translationBn;
  final int count;
  final String reference;
  final String? virtue;

  factory DhikrItem.fromJson(Map<String, dynamic> m) => DhikrItem(
    id: m['id'] as String? ?? '',
    order: (m['order'] as num?)?.toInt() ?? 0,
    arabic: m['arabic'] as String? ?? '',
    translitBn: m['translitBn'] as String? ?? '',
    translationBn: m['translationBn'] as String? ?? '',
    count: (m['count'] as num?)?.toInt() ?? 1,
    reference: m['reference'] as String? ?? '',
    virtue: m['virtue'] as String?,
  );
}

class DhikrSet {
  const DhikrSet({
    required this.id,
    required this.titleBn,
    required this.period,
    this.totalMin,
    required this.items,
  });
  final String id;
  final String titleBn;
  final String period; // morning | evening | post_salat | other
  final int? totalMin;
  final List<DhikrItem> items;

  factory DhikrSet.fromJson(Map<String, dynamic> m) => DhikrSet(
    id: m['id'] as String? ?? '',
    titleBn: m['titleBn'] as String? ?? '',
    period: m['period'] as String? ?? 'other',
    totalMin: (m['totalMin'] as num?)?.toInt(),
    items: ((m['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => DhikrItem.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

class NameOfAllah {
  const NameOfAllah({
    required this.id,
    required this.arabic,
    required this.translitBn,
    required this.meaningBn,
    this.virtue,
  });
  final int id;
  final String arabic;
  final String translitBn;
  final String meaningBn;
  final String? virtue;

  factory NameOfAllah.fromJson(Map<String, dynamic> m) => NameOfAllah(
    id: (m['id'] as num?)?.toInt() ?? 0,
    arabic: m['arabic'] as String? ?? '',
    translitBn: m['translitBn'] as String? ?? '',
    meaningBn: m['meaningBn'] as String? ?? '',
    virtue: m['virtue'] as String?,
  );
}

class IslamicName {
  const IslamicName({
    required this.id,
    required this.name,
    required this.gender,
    required this.meaningBn,
    this.genderNote,
  });
  final int id;
  final String name;
  final String gender; // boy | girl
  final String meaningBn;
  final String? genderNote;

  factory IslamicName.fromJson(Map<String, dynamic> m) => IslamicName(
    id: (m['id'] as num?)?.toInt() ?? 0,
    name: m['name'] as String? ?? '',
    gender: m['gender'] as String? ?? 'boy',
    meaningBn: m['meaningBn'] as String? ?? '',
    genderNote: m['gender_note'] as String? ?? m['genderNote'] as String?,
  );
}

class ImanBranch {
  const ImanBranch({
    required this.id,
    required this.group,
    required this.titleBn,
    this.detailBn,
  });
  final int id;
  final String group; // heart | tongue | body
  final String titleBn;
  final String? detailBn;

  factory ImanBranch.fromJson(Map<String, dynamic> m) => ImanBranch(
    id: (m['id'] as num?)?.toInt() ?? 0,
    group: m['group'] as String? ?? 'heart',
    titleBn: m['titleBn'] as String? ?? '',
    detailBn: m['detailBn'] as String?,
  );
}

class SunnahItem {
  const SunnahItem({
    required this.id,
    required this.category,
    required this.titleBn,
    required this.detailBn,
    this.reference,
  });
  final String id;
  final String category; // daily | forgotten | salah
  final String titleBn;
  final String detailBn;
  final String? reference;

  factory SunnahItem.fromJson(Map<String, dynamic> m) => SunnahItem(
    id: m['id'] as String? ?? '',
    category: m['category'] as String? ?? 'daily',
    titleBn: m['titleBn'] as String? ?? '',
    detailBn: m['detailBn'] as String? ?? '',
    reference: m['reference'] as String?,
  );
}

class ArticleItem {
  const ArticleItem({
    required this.id,
    required this.titleBn,
    required this.excerptBn,
    required this.bodyBn,
    this.category,
    this.publishedAt,
    this.readMinutes,
  });
  final String id;
  final String titleBn;
  final String excerptBn;
  final String bodyBn;
  final String? category;
  final String? publishedAt;
  final int? readMinutes;

  factory ArticleItem.fromJson(Map<String, dynamic> m) => ArticleItem(
    id: m['id'] as String? ?? '',
    titleBn: m['titleBn'] as String? ?? '',
    excerptBn: m['excerptBn'] as String? ?? '',
    bodyBn: m['bodyBn'] as String? ?? '',
    category: m['category'] as String?,
    publishedAt: m['publishedAt'] as String?,
    readMinutes: (m['readMinutes'] as num?)?.toInt(),
  );
}

class MosqueInfo {
  const MosqueInfo({
    required this.id,
    required this.nameBn,
    required this.addressBn,
    required this.lat,
    required this.lng,
    this.nameEn,
    this.area,
    this.verified = false,
  });
  final String id;

  /// Empty when the mosque is on the map without a name.
  final String nameBn;
  final String addressBn;
  final double lat;
  final double lng;
  final String? nameEn;
  final String? area;

  /// From the Foundation's own list (the bundled pack is all verified).
  final bool verified;

  bool get named => nameBn.trim().isNotEmpty;

  /// The bundled/admin pack (curated by the Foundation).
  factory MosqueInfo.fromJson(Map<String, dynamic> m) => MosqueInfo(
    id: m['id'] as String? ?? '',
    nameBn: m['nameBn'] as String? ?? '',
    addressBn: m['addressBn'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
    nameEn: m['nameEn'] as String?,
    area: m['area'] as String?,
    verified: m['verified'] as bool? ?? true,
  );

  /// GET /api/mosques/near (OpenStreetMap + the verified list).
  factory MosqueInfo.fromApi(Map<String, dynamic> m) => MosqueInfo(
    id: m['id'] as String? ?? '',
    nameBn: m['name'] as String? ?? '',
    addressBn: m['address'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
    nameEn: m['nameEn'] as String?,
    area: m['area'] as String?,
    verified: m['verified'] as bool? ?? false,
  );

  /// For "আমার মসজিদ" kept on the phone (round-trips through [fromJson]).
  Map<String, dynamic> toJson() => {
    'id': id,
    'nameBn': nameBn,
    'addressBn': addressBn,
    'lat': lat,
    'lng': lng,
    if (nameEn != null) 'nameEn': nameEn,
    if (area != null) 'area': area,
    'verified': verified,
  };
}

class FaqItem {
  const FaqItem({required this.q, required this.a});
  final String q;
  final String a;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.questionBn,
    required this.options,
    required this.answerIndex,
    this.explanationBn,
  });
  final String id;
  final String questionBn;
  final List<String> options;
  final int answerIndex;
  final String? explanationBn;

  factory QuizQuestion.fromJson(Map<String, dynamic> m) => QuizQuestion(
    id: m['id'] as String? ?? '',
    questionBn: m['questionBn'] as String? ?? '',
    options: (m['options'] as List? ?? []).map((e) => e.toString()).toList(),
    answerIndex: (m['answerIndex'] as num?)?.toInt() ?? 0,
    explanationBn: m['explanationBn'] as String?,
  );
}

class Quiz {
  const Quiz({
    required this.id,
    required this.titleBn,
    this.descBn,
    required this.category,
    required this.minutes,
    this.live = false,
    required this.questions,
  });
  final String id;
  final String titleBn;
  final String? descBn;
  final String category;
  final int minutes;

  /// Live-quiz eligible (played in the usrah room over socket.io).
  final bool live;
  final List<QuizQuestion> questions;

  factory Quiz.fromJson(Map<String, dynamic> m) => Quiz(
    id: m['id'] as String? ?? '',
    titleBn: m['titleBn'] as String? ?? '',
    descBn: m['descBn'] as String?,
    category: m['category'] as String? ?? 'general',
    minutes: (m['minutes'] as num?)?.toInt() ?? 5,
    live: m['live'] as bool? ?? false,
    questions: ((m['questions'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => QuizQuestion.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

// ── In-app fallbacks for packs that shipped as placeholders ──────────────────
// (The bundled amal catalog lives in lib/api/fallback_catalog.dart.)

const List<Map<String, dynamic>> kFallbackMosques = [
  {
    'id': 'baytul-mukarram',
    'nameBn': 'বায়তুল মুকাররম জাতীয় মসজিদ',
    'addressBn': 'বাংলাদেশ সচিবালয়, ঢাকা',
    'lat': 23.7275391,
    'lng': 90.4122566,
  },
  {
    'id': 'masjid-al-haram',
    'nameBn': 'মসজিদুল হারাম',
    'addressBn': 'মক্কা মুকাররমা, সৌদি আরব',
    'lat': 21.4224779,
    'lng': 39.8251832,
  },
  {
    'id': 'masjid-an-nabawi',
    'nameBn': 'মসজিদে নববী',
    'addressBn': 'মদিনা মুনাওয়ারা, সৌদি আরব',
    'lat': 24.4672108,
    'lng': 39.6111068,
  },
  {
    'id': 'sixty-dome',
    'nameBn': 'ষাট গম্বুজ মসজিদ',
    'addressBn': 'বাগেরহাট, খুলনা',
    'lat': 22.6745,
    'lng': 89.7418,
  },
];

const List<Map<String, dynamic>> kFallbackFaq = [
  {
    'q': 'আমলনামার দিন কবে লক হয়ে যায়?',
    'a': 'পরের দিনের ইশরাকের পর আগের দিনের আমল লক হয়ে যায়। লক হয়ে গেলে উসরা প্রধানের অনুমতিতে আনলক করা যায়।',
  },
  {
    'q': 'গেস্ট হিসেবে থাকলে কি ডেটা সংরক্ষিত হয়?',
    'a': 'জি, অ্যাপের ভেতরে সুরক্ষিত থাকে। রেজিস্ট্রেশন করলে গেস্ট আমল একই সাথে আপনার একাউন্টে চলে যাবে।',
  },
  {
    'q': 'মেয়েদের তথ্য কারা দেখতে পারেন?',
    'a': 'শুধুমাত্র মহিলা পরিদর্শক ও মহিলা উসরা প্রধান। ছেলে পরিদর্শক বা অ্যাডমিন-ও মহিলা সদস্যের আমল দেখতে পারেন না।',
  },
  {
    'q': 'নামাজের সময় কোন মাযহাব অনুযায়ী হিসাব হয়?',
    'a': 'আসরের সময় আপনার নির্বাচিত মাযহাব অনুযায়ী (হানাফি/শাফেয়ি) হিসাব হয়; ডিফল্ট হানাফি।',
  },
];

const List<Map<String, dynamic>> kFallbackQuizzes = [
  {
    'id': 'iman-self-test',
    'titleBn': 'ঈমান আত্মযাচাই',
    'descBn': 'ঈমানের মূল বিষয়গুলো কতটা জানেন যাচাই করুন',
    'category': 'iman',
    'minutes': 5,
    'questions': [
      {
        'id': 'q1',
        'questionBn': 'ঈমানের খাস সংজ্ঞা কোনটি?',
        'options': [
          'মুখে স্বীকার করা',
          'অন্তরে বিশ্বাস করা',
          'মুখে স্বীকার + অন্তরে বিশ্বাস',
          'আমল করা',
        ],
        'answerIndex': 2,
        'explanationBn':
            'ঈমানে মুফাসসালের সংজ্ঞা: মুখে স্বীকার করা ও অন্তরে বিশ্বাস রাখা।',
      },
      {
        'id': 'q2',
        'questionBn': 'তাওহীদের প্রকারভেদ কতটি?',
        'options': ['২টি', '৩টি', '৪টি', '৫টি'],
        'answerIndex': 1,
        'explanationBn': 'রুবুবিয়াহ, উলুহিয়াহ ও আসমা-ওয়া-সিফাত — মোট ৩টি।',
      },
      {
        'id': 'q3',
        'questionBn': 'ঈমানের শাখা কতটি?',
        'options': ['৭০টি', '৬০টি', '৭৭টি', '৭০+১টি'],
        'answerIndex': 0,
        'explanationBn':
            'হাদীসে এসেছে — ঈমানের শাখা ৭০টিরও অধিক; সর্বোচ্চ হলো কালিমা।',
      },
      {
        'id': 'q4',
        'questionBn': 'শিরক কোন জিনিসের বিপরীত?',
        'options': ['নবুওয়াত', 'তাওহীদ', 'রিসালাত', 'আখিরাত'],
        'answerIndex': 1,
      },
      {
        'id': 'q5',
        'questionBn': 'নবীজি ﷺ কোন বিষয়ে সর্বাধিক হুঁশিয়ার করেছেন?',
        'options': ['হারাম খাওয়া', 'শিরক ও বিদআত', 'নামাজে অলসতা', 'সুদ'],
        'answerIndex': 1,
        'explanationBn': 'শিরক ও বিদআত সম্পর্কে সাহাবীদের বারবার সতর্ক করেছেন।',
      },
    ],
  },
  {
    'id': 'taqwa-self-test',
    'titleBn': 'তাকওয়া আত্মযাচাই',
    'descBn': 'দৈনন্দিন জীবনে তাকওয়ার অনুশীলন যাচাই করুন',
    'category': 'taqwa',
    'minutes': 5,
    'questions': [
      {
        'id': 'q1',
        'questionBn': 'তাকওয়ার আক্ষরিক অর্থ কী?',
        'options': [
          'ইবাদত বেশি করা',
          'বেঁচে থাকা',
          'আত্মরক্ষা / বাঁচন',
          'দান করা',
        ],
        'answerIndex': 2,
      },
      {
        'id': 'q2',
        'questionBn': 'কোনটি তাকওয়ার প্রকৃত চিহ্ন?',
        'options': [
          'মানুষের ভয়',
          'একা থাকলেও গুনাহ থেকে বেঁচে থাকা',
          'বেশি কথা বলা',
          'শুধু জামাতে নামাজ',
        ],
        'answerIndex': 1,
      },
      {
        'id': 'q3',
        'questionBn': 'মুহাসাবা কী?',
        'options': [
          'দান করা',
          'নিজের আমলের হিসাব নেওয়া',
          'জিকির গণনা',
          'রোজা রাখা',
        ],
        'answerIndex': 1,
      },
      {
        'id': 'q4',
        'questionBn': 'গুনাহ থেকে তাওবা করলে কী হয়?',
        'options': [
          'কবুল হওয়া নিশ্চিত নয়',
          'নিষ্ঠার সাথে করলে আল্লাহ ক্ষমা করেন',
          'শুধু বড় গুনাহতে',
          'তাওবার প্রয়োজন নেই',
        ],
        'answerIndex': 1,
      },
    ],
  },
];

// ── Loader ───────────────────────────────────────────────────────────────────

class ContentPack {
  const ContentPack._();

  static Future<String> Function(String path) _loadAsset =
      rootBundle.loadString;

  /// Completed cache — decoded DATA per file, zone-free (the FaqRepository/
  /// QuranRepository lesson: memoizing the FUTURE instead breaks fake-zone
  /// listeners, because a future completed inside runAsync's real-async zone
  /// never resolves them). Production wins too: reopening a pack screen
  /// resolves on the next microtask instead of re-reading + re-decoding.
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Single-flight for concurrent same-zone opens.
  static final Map<String, Future<Map<String, dynamic>>> _loading = {};

  /// Test seam (the FaqRepository pattern): rootBundle platform-channel
  /// loads cannot complete inside the fake-async zone — tests inject a
  /// File-based loader and prewarm the pack cache under runAsync.
  @visibleForTesting
  static set assetLoaderForTesting(
    Future<String> Function(String path) loader,
  ) {
    _loadAsset = loader;
    _cache.clear();
    _loading.clear();
  }

  @visibleForTesting
  static void resetForTesting() {
    remote = null;
    _loadAsset = rootBundle.loadString;
    _cache.clear();
    _loading.clear();
    _revalidated.clear();
  }

  /// The admin-managed packs (everything but the Qur'an), by file → API
  /// pack key. A scholar-approved edit reaches the app without a release.
  static const Map<String, String> _remotePacks = {
    'adhkar.json': 'adhkar',
    'duas.json': 'duas',
    'sunnahs.json': 'sunnahs',
    'names99.json': 'names99',
    'islamic-names.json': 'islamic-names',
    'iman-branches.json': 'iman-branches',
    'articles.json': 'articles',
    'faq.json': 'faq',
    'mosques.json': 'mosques',
    'quizzes.json': 'quizzes',
  };

  /// Set at app start (GET /api/content/:pack). Null in tests → the bundle.
  static Future<Map<String, dynamic>?> Function(String packKey)? remote;

  /// Packs already refreshed from the server this session.
  static final Set<String> _revalidated = {};

  static String _prefsKey(String file) => 'content_pack_cache_$file';

  /// The copy kept on the phone from the last refresh (null: none yet).
  static Future<Map<String, dynamic>?> _phoneCopy(String file) async {
    if (!_remotePacks.containsKey(file)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(file));
      if (raw != null) {
        // a copy kept by an older version may predate the honorific rule
        final d = withHonorific(jsonDecode(raw));
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  /// Stale-while-revalidate: a screen opens at once on the phone's copy (or
  /// the bundle), never waiting on the network — the adhkar must open on a
  /// weak connection at Fajr. Meanwhile the server's copy is fetched (once a
  /// session) and kept, so the next open shows the newest approved content.
  static void _revalidate(String file) {
    final key = _remotePacks[file];
    final fetch = remote;
    if (key == null || fetch == null || !_revalidated.add(file)) return;
    () async {
      try {
        final data = await fetch(key).timeout(const Duration(seconds: 20));
        if (data == null || data.isEmpty) return;
        _cache[file] = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey(file), jsonEncode(data));
      } catch (_) {
        _revalidated.remove(file); // offline — try again on the next open
      }
    }();
  }

  static Future<Map<String, dynamic>> _load(String file) {
    final cached = _cache[file];
    if (cached != null) {
      _revalidate(file);
      return Future.value(cached);
    }
    return _loading[file] ??= () async {
      try {
        var data = await _phoneCopy(file);
        if (data == null) {
          final raw = await _loadAsset('assets/content/$file');
          final decoded = withHonorific(jsonDecode(raw));
          data = decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{};
        }
        // a refresh that landed while this was loading is newer — keep it
        final result = _cache[file] ??= data;
        _loading.remove(file);
        _revalidate(file);
        return result;
      } catch (e) {
        debugPrint('$file load failed: $e');
        // A failed load must not poison future opens — drop the in-flight
        // memo so the next caller refetches.
        _loading.remove(file);
        rethrow;
      }
    }();
  }

  /// A whole pack document, for a screen that reads its own shape (the
  /// FAQ screen's grouped entries).
  static Future<Map<String, dynamic>> document(String file) => _load(file);

  static List<T> _list<T>(
    Map<String, dynamic> j,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = (j[key] as List? ?? [])
        .whereType<Map>()
        .map((e) => fromJson(e.cast<String, dynamic>()))
        .toList();
    return items;
  }

  static List<Map<String, dynamic>> _rawList(
    Map<String, dynamic> j,
    String key,
    List<Map<String, dynamic>> fallback,
  ) {
    final items = (j[key] as List? ?? []).whereType<Map>().toList();
    if (items.isEmpty) {
      return [
        for (final m in fallback) withHonorific(m) as Map<String, dynamic>,
      ];
    }
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Duas
  static Future<(List<DuaCategory>, List<DuaItem>)> duas() async {
    final j = await _load('duas.json');
    final cats = _list(
      j,
      'categories',
      (m) => DuaCategory(
        key: m['key'] as String? ?? '',
        labelBn: m['labelBn'] as String? ?? '',
      ),
    );
    final items = _list(j, 'items', DuaItem.fromJson);
    return (cats, items);
  }

  // Adhkar
  static Future<List<DhikrSet>> adhkar() async {
    final j = await _load('adhkar.json');
    final sets = _list(j, 'sets', DhikrSet.fromJson);
    for (final s in sets) {
      s.items.sort((a, b) => a.order.compareTo(b.order));
    }
    return sets;
  }

  static Future<List<NameOfAllah>> names99() async {
    final j = await _load('names99.json');
    return _list(j, 'names', NameOfAllah.fromJson);
  }

  static Future<List<IslamicName>> islamicNames() async {
    final j = await _load('islamic-names.json');
    return _list(j, 'names', IslamicName.fromJson);
  }

  static Future<List<ImanBranch>> imanBranches() async {
    final j = await _load('iman-branches.json');
    return _list(j, 'branches', ImanBranch.fromJson);
  }

  static Future<List<SunnahItem>> sunnahs() async {
    final j = await _load('sunnahs.json');
    return _list(j, 'items', SunnahItem.fromJson);
  }

  static Future<List<ArticleItem>> articles() async {
    final j = await _load('articles.json');
    return _list(j, 'items', ArticleItem.fromJson);
  }

  static Future<List<MosqueInfo>> mosques() async {
    final j = await _load('mosques.json');
    return _rawList(
      j,
      'mosques',
      kFallbackMosques,
    ).map(MosqueInfo.fromJson).toList();
  }

  static Future<List<FaqItem>> faq() async {
    final j = await _load('faq.json');
    return _rawList(j, 'items', kFallbackFaq)
        .map(
          (m) =>
              FaqItem(q: m['q'] as String? ?? '', a: m['a'] as String? ?? ''),
        )
        .toList();
  }

  static Future<List<Quiz>> quizzes() async {
    final j = await _load('quizzes.json');
    return _rawList(j, 'quizzes', kFallbackQuizzes).map(Quiz.fromJson).toList();
  }
}
