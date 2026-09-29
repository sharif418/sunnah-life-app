/// W4j — the OFFLINE search fallback: a local matcher over the SAME bundled
/// content packs the ilm screens render (assets/content/*.json via
/// ContentPack), producing the same [SearchHit] rows the API's
/// GET /api/search returns so the results list looks identical either way.
///
/// HONESTY NOTE — what this matcher is and is not:
///   · It is a NORMALIZED SUBSTRING matcher: lowercase + strip zero-width
///     joiners/spaces + collapse whitespace, then substring over the same
///     fields the server's meili indexes rank (title/translation/meaning).
///   · It is NOT typo-tolerant. No edit distance. A misspelled query that
///     meili would rescue (the server carries the Bengali typoTolerance
///     settings) finds nothing here. Shipping a half-baked fuzzy matcher
///     offline would silently disagree with the server's result set — the
///     offline banner tells the user exactly which corpus answered.
///   · The adhkar granularity matches the server: set-level (the pack's
///     id-bearing array is `sets`), subtitle = "৯টি আযকার".
library;

import '../../core/bn_digits.dart';
import '../../models/content_models.dart';
import '../../models/search.dart';

/// Zero-width joiners/spaces + whitespace collapse + lowercase (islamic
/// names are Latin script; Bengali has no case).
String normalizeSearch(String s) => s
    .replaceAll(RegExp('[\u200b\u200c\u200d]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .trim();

bool _hit(List<String> fields, String nq) =>
    fields.any((f) => normalizeSearch(f).contains(nq));

/// Search the bundled packs. The short-q rule mirrors the API: a trimmed
/// query under 2 code points answers an empty list.
Future<List<SearchHit>> searchBundledPacks(String q, {int limit = 20}) async {
  final nq = normalizeSearch(q);
  if (nq.length < 2) return const [];

  final rows = <SearchHit>[];

  // 1. duas — title / translation / transliteration
  final (_, duas) = await ContentPack.duas();
  for (final d in duas) {
    if (_hit([d.titleBn, d.translationBn, d.translitBn ?? ''], nq)) {
      rows.add(SearchHit(
        kind: SearchKind.dua,
        id: d.id,
        title: d.titleBn,
        subtitle: d.translationBn,
        kindLabelBn: kSearchKindLabelBn[SearchKind.dua]!,
      ));
    }
  }

  // 2. adhkar — set-level (mirrors the server's pack granularity)
  final sets = await ContentPack.adhkar();
  for (final s in sets) {
    final itemText = s.items
        .expand((i) => [i.translationBn, i.translitBn])
        .toList(growable: false);
    if (_hit([s.titleBn, ...itemText], nq)) {
      rows.add(SearchHit(
        kind: SearchKind.dhikr,
        id: s.id,
        title: s.titleBn,
        subtitle: '${toBn(s.items.length)}টি আযকার',
        kindLabelBn: kSearchKindLabelBn[SearchKind.dhikr]!,
      ));
    }
  }

  // 3. আল্লাহর ৯৯ নাম — transliteration / meaning
  final names = await ContentPack.names99();
  for (final n in names) {
    if (_hit([n.translitBn, n.meaningBn], nq)) {
      rows.add(SearchHit(
        kind: SearchKind.name99,
        id: n.id.toString(),
        title: n.translitBn,
        subtitle: n.meaningBn,
        kindLabelBn: kSearchKindLabelBn[SearchKind.name99]!,
      ));
    }
  }

  // 4. ইসলামিক নাম — name / meaning
  final islamic = await ContentPack.islamicNames();
  for (final n in islamic) {
    if (_hit([n.name, n.meaningBn], nq)) {
      rows.add(SearchHit(
        kind: SearchKind.islamicName,
        id: n.id.toString(),
        title: n.name,
        subtitle: n.meaningBn,
        kindLabelBn: kSearchKindLabelBn[SearchKind.islamicName]!,
      ));
    }
  }

  // 5. আর্টিকেল — title / excerpt
  final articles = await ContentPack.articles();
  for (final a in articles) {
    if (_hit([a.titleBn, a.excerptBn], nq)) {
      rows.add(SearchHit(
        kind: SearchKind.article,
        id: a.id,
        title: a.titleBn,
        subtitle: a.excerptBn,
        kindLabelBn: kSearchKindLabelBn[SearchKind.article]!,
      ));
    }
  }

  return rows.take(limit).toList(growable: false);
}
