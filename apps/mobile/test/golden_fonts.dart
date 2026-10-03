// Font warmer for golden tests — BOTH layers the engine needs.
//
// flutter test does NOT load pubspec-declared font families (only the SDK's
// MaterialIcons comes pre-registered). The old comment in pubspec.yaml and
// design_tokens.dart claimed the opposite — "golden tests render the real
// glyphs with zero warm-up" — and that claim hid two failures at once:
//
//  1. Every committed fonts_*.png golden was tofu (□) for all Bengali text —
//     only the Phosphor icons (warmed since W4b) rendered. The pixel layer
//     of the tofu guard compared tofu against tofu and proved nothing.
//  2. With the text families genuinely loaded, two real bugs surfaced:
//     color-less ListTile/chip theme styles that render near-white text on
//     the cream surface (fixed in design_tokens.dart — see
//     test/theme_contrast_test.dart).
//
// Loading rule (both live here now):
//  * ICON families: PhosphorRegular / PhosphorFill / PhosphorBold (vendored).
//  * TEXT families: NotoSansBengali (Regular w400 + Medium w500 + SemiBold w600 + Bold w700 —
//    FontLoader style-matches by each TTF's intrinsic OS/2 weight), Amiri
//    and AmiriQuran (du'a / Uthmani Qur'an).
//
// Call before the first capture; pump once after so any already-built frames
// re-render with the real glyphs. test/tofu_guard_test.dart FAILS if this
// ever regresses back to tofu.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<(String, String)> _phosphorFonts = [
  ('PhosphorRegular', 'assets/fonts/phosphor-regular.ttf'),
  ('PhosphorFill', 'assets/fonts/phosphor-fill.ttf'),
  ('PhosphorBold', 'assets/fonts/phosphor-bold.ttf'),
];

const List<(String, List<String>)> _textFonts = [
  // One FontLoader per FAMILY; every weight's TTF is added to it (the engine
  // picks w400/w600/w700 from the intrinsic OS/2 weight of each file).
  ('NotoSansBengali', [
    'assets/google_fonts/NotoSansBengali-Regular.ttf',
    'assets/google_fonts/NotoSansBengali-Medium.ttf',
    'assets/google_fonts/NotoSansBengali-SemiBold.ttf',
    'assets/google_fonts/NotoSansBengali-Bold.ttf',
  ]),
  ('Amiri', ['assets/google_fonts/Amiri-Regular.ttf']),
  ('AmiriQuran', ['assets/google_fonts/AmiriQuran-Regular.ttf']),
];

/// Registers every bundled family — text AND icons — in the test engine.
Future<void> warmAppFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final (family, paths) in _textFonts) {
      final loader = FontLoader(family);
      for (final path in paths) {
        final data = await rootBundle.load(path);
        loader.addFont(Future.value(data));
      }
      await loader.load();
    }
    for (final (family, path) in _phosphorFonts) {
      final data = await rootBundle.load(path);
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
    }
  });
  await tester.pump();
}

/// Icon-only warm (kept for tests that render no text through the bundled
/// families). Golden tests must use [warmAppFonts] instead.
Future<void> warmPhosphorFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final (family, path) in _phosphorFonts) {
      final data = await rootBundle.load(path);
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
    }
  });
  await tester.pump();
}
