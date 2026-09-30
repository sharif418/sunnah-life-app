/// W4j — unified content search contract (GET /api/search): grouped rows
/// over the five indexed packs. The same model serves the OFFLINE fallback
/// (the bundled-pack matcher in features/ilm/search_offline.dart) so the
/// results list renders identically wherever the rows came from.
library;

enum SearchKind { dua, dhikr, name99, islamicName, article }

/// Bengali kind labels — content labels are bn by design (the same register
/// the API's kindLabelBn uses; ROLE/LEVEL label maps follow this pattern).
const Map<SearchKind, String> kSearchKindLabelBn = {
  SearchKind.dua: 'দোয়া',
  SearchKind.dhikr: 'আযকার',
  SearchKind.name99: 'আল্লাহর নাম',
  SearchKind.islamicName: 'ইসলামিক নাম',
  SearchKind.article: 'আর্টিকেল',
};

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    required this.kindLabelBn,
  });
  final SearchKind kind;
  final String id;
  final String title;
  final String? subtitle;
  final String kindLabelBn;

  factory SearchHit.fromJson(Map<String, dynamic> m) => SearchHit(
    kind: switch (m['kind']) {
      'dua' => SearchKind.dua,
      'dhikr' => SearchKind.dhikr,
      'name99' => SearchKind.name99,
      'islamic_name' => SearchKind.islamicName,
      'article' => SearchKind.article,
      _ => SearchKind.article,
    },
    id: m['id']?.toString() ?? '',
    title: m['title'] as String? ?? '',
    subtitle: m['subtitle'] as String?,
    kindLabelBn: m['kindLabelBn'] as String? ?? '',
  );
}

class SearchResults {
  const SearchResults({required this.query, required this.results});
  final String query;
  final List<SearchHit> results;

  factory SearchResults.fromJson(Map<String, dynamic> m) => SearchResults(
    query: m['query'] as String? ?? '',
    results: ((m['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SearchHit.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false),
  );
}
