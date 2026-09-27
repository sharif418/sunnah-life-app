// L10n consistency — ARB catalogs (bn template / en / ar):
//   · identical key sets across all three locales
//   · every value non-empty in all three locales
//   · every ARB key resolves through the generated AppLocalizations adapter
//     (guards the _translate key map in app_strings.dart against drift)
//   · Bengali-fallback semantics: missing keys fall back to the template
//     language inside the generated classes; unknown keys surface themselves.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunnah_life/l10n/app_strings.dart';

Map<String, String> _load(String loc) {
  final file = File('lib/l10n/app_$loc.arb');
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in map.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

void main() {
  test('every ARB key exists in bn, en and ar with a non-empty value', () {
    final catalogs = {
      for (final loc in ['bn', 'en', 'ar']) loc: _load(loc),
    };
    final keys = catalogs['bn']!.keys.toSet();
    expect(keys, isNotEmpty);
    for (final loc in ['en', 'ar']) {
      expect(
        catalogs[loc]!.keys.toSet(),
        keys,
        reason: 'app_$loc.arb keys must match app_bn.arb exactly',
      );
    }
    final empty = <String, String>{
      for (final loc in catalogs.keys)
        for (final e in catalogs[loc]!.entries)
          if (e.value.trim().isEmpty) '$loc:${e.key}': e.value,
    };
    expect(empty, isEmpty, reason: 'empty translations: $empty');
  });

  test('every ARB key resolves through the AppLocalizations adapter', () {
    final keys = _load('bn').keys;
    final unresolved = <(Lang, String)>[];
    for (final lang in Lang.values) {
      for (final key in keys) {
        if (S.tr(lang, key) == key) unresolved.add((lang, key));
      }
    }
    expect(
      unresolved,
      isEmpty,
      reason:
          'keys that fell through the _translate map (update '
          'tool/make_arbs.py --keymap): $unresolved',
    );
  });

  test('Bengali is the fallback; unknown keys surface themselves', () {
    expect(S.tr(Lang.ar, '__missing_key__'), '__missing_key__');
    expect(S.tr(Lang.bn, 'ok'), 'ঠিক আছে');
    expect(S.tr(Lang.en, 'ok'), 'OK');
    expect(S.tr(Lang.ar, 'ok'), 'حسنًا');
    // Sample the sweep additions too.
    expect(S.tr(Lang.en, 'app_title'), 'Sunnah Life');
    expect(S.tr(Lang.ar, 'app_title'), 'سنّة لايف');
    expect(S.tr(Lang.en, 'waqt_fajr'), 'Fajr');
    expect(S.tr(Lang.ar, 'waqt_fajr'), 'الفجر');
  });

  test('lang codes round-trip', () {
    for (final lang in Lang.values) {
      expect(LangX.fromCode(lang.code), lang);
    }
    expect(LangX.fromCode(null), Lang.bn);
    expect(LangX.fromCode('xx'), Lang.bn);
    expect(Lang.ar.isRtl, isTrue);
    expect(Lang.bn.isRtl, isFalse);
    expect(Lang.en.isRtl, isFalse);
  });
}
