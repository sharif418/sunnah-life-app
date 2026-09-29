// Icon-font warmer for golden tests.
//
// flutter test loads TEXT families through google_fonts' asset-backed
// loader (the golden tests warm those explicitly), but ICON families are
// never warmed anywhere — every icon in every committed golden rendered
// as a tofu box. The Phosphor TTFs are pubspec assets, so the test
// binding's asset channel serves them from the real filesystem; loading
// them through FontLoader under runAsync (the real-event-loop zone the
// platform channels need) makes goldens render the actual glyphs.
//
// MaterialIcons is deliberately NOT warmed here: after the W4f migration
// the only Material glyphs left in the app (zakat debts, city-picker
// GPS-off) sit on screens no golden covers, and the SDK font lives
// outside the package (an environment-dependent golden would flake CI).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the three vendored Phosphor families in the test engine.
/// Call before the first capture; pump once after so any already-built
/// frames re-render with the real glyphs.
Future<void> warmPhosphorFonts(WidgetTester tester) async {
  const fonts = (
    regular: 'assets/fonts/phosphor-regular.ttf',
    fill: 'assets/fonts/phosphor-fill.ttf',
    bold: 'assets/fonts/phosphor-bold.ttf',
  );
  await tester.runAsync(() async {
    for (final entry in [
      ('PhosphorRegular', fonts.regular),
      ('PhosphorFill', fonts.fill),
      ('PhosphorBold', fonts.bold),
    ]) {
      final data = await rootBundle.load(entry.$2);
      final loader = FontLoader(entry.$1)..addFont(Future.value(data));
      await loader.load();
    }
  });
  await tester.pump();
}
