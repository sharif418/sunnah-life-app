// The genuine tofu check — W5.
//
// The old guard's layer 2 (the RenderParagraph family walk in
// font_golden_test.dart) proves only that the resolved family NAMES are the
// bundled ones — it cannot see whether the engine actually has GLYPHS for
// them, which is exactly how five committed goldens ended up tofu with the
// guard green.
//
// Mechanism used here: in `flutter test`, a family that is not registered
// (or a glyph the loaded fonts don't cover) falls back to Ahem — the
// metafont where EVERY glyph is an opaque box advancing by EXACTLY the
// style's fontSize. Real proportional typefaces never behave that way:
// distinct base letters carry distinct advances (Noto Sans Bengali consonants
// measure ~0.6-0.9 em, Amiri letters ~0.2-0.9 em — even a letter that
// happens near 1.0 em, like Amiri seen (99.2/100), is not the exact box,
// and never identical to its neighbours). So the tofu signature is:
// every sampled glyph advances by exactly fontSize. A negative control
// asserts the detector works (an unregistered family measures exactly
// that).
//
// Fails when: a font asset is renamed/moved/emptied, the pubspec asset list
// breaks, a family name drifts, or a warmed TTF stops covering the scripts
// the app renders.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_fonts.dart';

/// Laid-out advance of [sample] at an exaggerated 100px so differences
/// can't hide in rounding.
double advanceOf(String family, String sample) {
  final painter = TextPainter(
    text: TextSpan(
      text: sample,
      style: TextStyle(fontFamily: family, fontSize: 100),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Every family the app renders, with three base letters its scripts must
/// carry (Bengali consonants; Arabic base letters for du'a + Qur'an).
const List<(String, List<String>)> _samplesByFamily = [
  ('SolaimanLipi', ['অ', 'ম', 'ক']),
  ('NotoSansBengali', ['অ', 'ম', 'ক']),
  ('Amiri', ['ب', 'م', 'ل']),
  ('AmiriQuran', ['ب', 'ل', 'م']),
];

/// True when [widths] is the Ahem signature: every advance exactly the
/// (100px) style size — the same opaque em box for every glyph.
bool _allEmBoxes(List<double> widths) =>
    widths.every((w) => w == 100.0);

void main() {
  testWidgets('bundled families carry real glyphs — not tofu boxes', (
    tester,
  ) async {
    await warmAppFonts(tester);

    for (final (family, chars) in _samplesByFamily) {
      final widths = [for (final c in chars) advanceOf(family, c)];

      // Glyphs exist at all — no zero-width holes.
      for (final (i, w) in widths.indexed) {
        expect(
          w,
          greaterThan(15),
          reason: '$family "${chars[i]}" laid out to ~zero width — the '
              'glyph is missing from the loaded TTF.',
        );
      }

      // Not every advance is the exact Ahem em box.
      expect(
        _allEmBoxes(widths),
        isFalse,
        reason:
            '$family advanced every sampled letter by exactly its fontSize '
            '— the Ahem tofu box. The family is not really loaded (or its '
            'TTFs lack the glyphs): every golden showing this script is '
            'tofu.',
      );

      // Proportional type: at least two distinct advances among the letters.
      expect(
        widths.toSet().length,
        greaterThan(1),
        reason: '$family measured identical advances for distinct letters '
            '— Ahem behaviour, i.e. tofu.',
      );
    }
  });

  testWidgets('detector control — an unregistered family IS tofu', (
    tester,
  ) async {
    await warmAppFonts(tester);
    // The mechanism itself, proven: an unknown family falls back to Ahem,
    // where every glyph advances by exactly fontSize. If this ever stops
    // holding, the guard above is checking nothing.
    final widths = [
      for (final c in ['অ', 'م', 'ক']) advanceOf('NoSuchFamilyAnywhere', c),
    ];
    expect(_allEmBoxes(widths), isTrue,
        reason: 'unregistered families must measure the Ahem em-boxes');
  });
}
