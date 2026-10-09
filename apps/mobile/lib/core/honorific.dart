/// How the salawat mark after the Prophet's name is shown in Bengali text.
///
/// The content keeps the mark as written (ﷺ, U+FDFA — the admin and the
/// scholars see the source). At body size the single-glyph ligature is three
/// lines of microscopic Arabic in SolaimanLipi (and barely larger in Arabic
/// faces), unreadable for older members — so Bengali sentences show the
/// form Bengali Islamic print uses: "(সা.)". Arabic text keeps the ligature.
///
/// Decided 2026-10-09 pending the Foundation's word: to show the full
/// phrase or keep the symbol instead, change [kHonorificBn] only.
library;

const kHonorificBn = '(সা.)';

final _bengali = RegExp(r'[ঀ-৿]');
final _mark = RegExp(r'\s*ﷺ');

/// "নবীজি ﷺ বলেছেন" → "নবীজি (সা.) বলেছেন"; Arabic-only text unchanged.
String honorificText(String s) {
  if (!s.contains('ﷺ') || !_bengali.hasMatch(s)) return s;
  return s.replaceAll(_mark, ' $kHonorificBn').trimLeft();
}

/// [honorificText] over every string of a decoded JSON document.
Object? withHonorific(Object? v) {
  if (v is String) return honorificText(v);
  if (v is List) return [for (final x in v) withHonorific(x)];
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key.toString(): withHonorific(e.value),
    };
  }
  return v;
}
