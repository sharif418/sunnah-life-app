/// Amal (Muhasaba diary) models — port of the amal group in
/// src/types/domain.ts: definitions, entries (tristate/boolean/count/
/// quantity/text), upsert results and the admin month grid.
library;

import 'user.dart';

enum TriState { jamaat, alone, qaza }

enum AmalInputType { tristate, boolean, count, quantity, text }

enum AmalCategory {
  salah,
  quran,
  dhikr,
  akhlaq,
  dawat,
  lifestyle,
  sunnah,
  personal,
}

extension AmalCategoryJson on AmalCategory {
  String get json => name;
  static AmalCategory fromJson(String v) => switch (v) {
    'quran' => AmalCategory.quran,
    'dhikr' => AmalCategory.dhikr,
    'akhlaq' => AmalCategory.akhlaq,
    'dawat' => AmalCategory.dawat,
    'lifestyle' => AmalCategory.lifestyle,
    'sunnah' => AmalCategory.sunnah,
    'personal' => AmalCategory.personal,
    _ => AmalCategory.salah,
  };
  String get labelBn => switch (this) {
    AmalCategory.salah => 'নামাজ',
    AmalCategory.quran => 'কুরআন',
    AmalCategory.dhikr => 'যিকর ও দোয়া',
    AmalCategory.akhlaq => 'আখলাক',
    AmalCategory.dawat => 'দাওয়াত',
    AmalCategory.lifestyle => 'জীবনাচরণ',
    AmalCategory.sunnah => 'সাপ্তাহিক ও মাসিক সুন্নাহ',
    AmalCategory.personal => 'ব্যক্তিগত লক্ষ্য',
  };
}

class AmalDefinition {
  const AmalDefinition({
    required this.key,
    required this.titleBn,
    required this.titleEn,
    required this.category,
    required this.inputType,
    required this.cadence,
    this.target,
    this.unit,
    this.minLevel = Level.none,
    this.sortOrder = 0,
    this.autoSource,
  });

  final String key;
  final String titleBn;
  final String titleEn;
  final AmalCategory category;
  final AmalInputType inputType;
  final String cadence; // daily | weekly:any | weekly:fri | weekly:mon_thu | monthly:ayyam_beez
  final Map<String, num>? target; // {"general":1,"hafez":1,"alim":10}
  final String? unit;
  final Level minLevel;
  final int sortOrder;
  final String? autoSource;

  factory AmalDefinition.fromJson(Map<String, dynamic> j) => AmalDefinition(
    key: j['key'] as String,
    titleBn: j['titleBn'] as String? ?? j['key'] as String,
    titleEn: j['titleEn'] as String? ?? '',
    category: AmalCategoryJson.fromJson(j['category'] as String? ?? 'salah'),
    inputType: switch (j['inputType'] as String? ?? 'boolean') {
      'tristate' => AmalInputType.tristate,
      'count' => AmalInputType.count,
      'quantity' => AmalInputType.quantity,
      'text' => AmalInputType.text,
      _ => AmalInputType.boolean,
    },
    cadence: j['cadence'] as String? ?? 'daily',
    target: (j['target'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    unit: j['unit'] as String?,
    minLevel: LevelJson.fromJson(j['minLevel'] as String? ?? 'none'),
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
    autoSource: j['autoSource'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'titleBn': titleBn,
    'titleEn': titleEn,
    'category': category.json,
    'inputType': inputType.name,
    'cadence': cadence,
    'target': target,
    'unit': unit,
    'minLevel': minLevel.json,
    'sortOrder': sortOrder,
    'autoSource': autoSource,
  };

  num targetFor(UserCategory category) =>
      target?[category.json] ?? target?['general'] ?? 1;
}

/// One diary cell: (amalKey, date) → value + provenance.
class AmalEntry {
  const AmalEntry({
    required this.amalKey,
    required this.date,
    required this.clientUpdatedAt,
    required this.value,
    required this.source,
    this.id,
    this.serverUpdatedAt,
  });

  final String? id;
  final String amalKey;
  final String date; // YYYY-MM-DD
  final String clientUpdatedAt; // ISO — conflict winner
  final Object? value; // TriState | bool | num | String
  final String source; // manual | auto:<feature>
  final String? serverUpdatedAt;

  AmalEntry copyWith({
    Object? value,
    String? source,
    String? clientUpdatedAt,
  }) => AmalEntry(
    id: id,
    amalKey: amalKey,
    date: date,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    value: value ?? this.value,
    source: source ?? this.source,
    serverUpdatedAt: serverUpdatedAt,
  );

  factory AmalEntry.fromJson(Map<String, dynamic> j) => AmalEntry(
    id: j['id'] as String?,
    amalKey: j['amalKey'] as String,
    date: j['date'] as String,
    clientUpdatedAt:
        j['clientUpdatedAt'] as String? ?? DateTime.now().toIso8601String(),
    value: j['value'],
    source: j['source'] as String? ?? 'manual',
    serverUpdatedAt: j['serverUpdatedAt'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'amalKey': amalKey,
    'date': date,
    'clientUpdatedAt': clientUpdatedAt,
    'value': value,
    'source': source,
    if (serverUpdatedAt != null) 'serverUpdatedAt': serverUpdatedAt,
  };
}

class AmalUpsertResult {
  const AmalUpsertResult({required this.accepted, required this.rejected});
  final List<AmalEntry> accepted;
  final List<AmalRejectInfo> rejected;

  factory AmalUpsertResult.fromJson(Map<String, dynamic> j) => AmalUpsertResult(
    accepted: ((j['accepted'] as List?) ?? [])
        .map((e) => AmalEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    rejected: ((j['rejected'] as List?) ?? [])
        .map((e) => AmalRejectInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class AmalRejectInfo {
  const AmalRejectInfo({
    required this.date,
    required this.amalKey,
    required this.reason,
  });
  final String date;
  final String amalKey;
  final String reason;

  factory AmalRejectInfo.fromJson(Map<String, dynamic> j) => AmalRejectInfo(
    date: j['date'] as String? ?? '',
    amalKey: j['amalKey'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
  );
}

class MonthGridCell {
  const MonthGridCell({required this.date, this.value, this.source = 'none'});
  final String date;
  final Object? value;
  final String source;
}

class MonthGrid {
  const MonthGrid({
    required this.amalKeys,
    required this.definitions,
    required this.days,
    required this.rows,
  });
  final List<String> amalKeys;
  final List<AmalDefinition> definitions;
  final List<String> days;
  final Map<String, List<MonthGridCell>> rows;
}
