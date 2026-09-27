// L10n table completeness — every key must cover bn/en/ar (Bengali-first).
import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/l10n/app_strings.dart';

void main() {
  test('every string table entry covers bn, en and ar', () {
    final missing = <String, List<Lang>>{};
    for (final entry in kStringTable.entries) {
      for (final lang in Lang.values) {
        final v = entry.value[lang];
        if (v == null || v.trim().isEmpty) {
          missing.putIfAbsent(entry.key, () => []).add(lang);
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'keys with missing translations: $missing',
    );
  });

  test('Bengali is the fallback for a missing key', () {
    expect(S.tr(Lang.ar, '__missing_key__'), '__missing_key__');
    expect(S.tr(Lang.bn, 'ok'), 'ঠিক আছে');
    expect(S.tr(Lang.en, 'ok'), 'OK');
  });

  test('lang codes round-trip', () {
    for (final lang in Lang.values) {
      expect(LangX.fromCode(lang.code), lang);
    }
    expect(LangX.fromCode(null), Lang.bn);
    expect(LangX.fromCode('xx'), Lang.bn);
    expect(Lang.ar.isRtl, isTrue);
    expect(Lang.bn.isRtl, isFalse);
  });
}
