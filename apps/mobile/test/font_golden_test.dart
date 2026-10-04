// Font-consistency goldens (V1→W5) — the five tab surfaces (Home, Amal
// Today, Dawah, Ilm, More) in bn light. The engine in flutter test loads
// NO pubspec-declared family on its own, so warmAppFonts (see
// test/golden_fonts.dart) registers the real Noto Sans Bengali / Amiri /
// AmiriQuran / Phosphor TTFs first: the committed pixels must show real
// glyphs, never tofu boxes (the W5 lesson — every golden in this suite
// used to be tofu because only the icons were warmed).
//
// Tofu guard, three layers:
//  1. matchesGoldenFile — pixel truth; with the real TTFs warmed (see
//     warmAppFonts), tofu boxes change pixels → CI fails.
//  2. expectNoPlatformFont — walks every RenderParagraph/EditableText in
//     the tree and requires the resolved family to be one of the app's
//     bundled families. Reports the offending text, so a regression says
//     exactly which widget fell back.
//  3. test/tofu_guard_test.dart — advance-width truth: a glyph that falls
//     back to the test engine's Ahem renders as a fontSize-advance box; the
//     guard fails if any bundled family stops carrying real glyphs.
//
// Determinism contract:
//  * headerNowProvider pinned to 2025-06-15 14:30 — the header date bar,
//    the day-of-week amals and the diary keys never flake across days.
//  * prayerProvider overridden with a fixed PrayerNow (no ticker) — the
//    countdown HH:MM:SS is frozen.
//  * Every remote pack (config/dawah/usrah/reviews/live/courses/quizzes)
//    overridden with fixed payloads via a fake ApiClient — no network.
// Regenerate with:
//   flutter test --update-goldens test/font_golden_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart' show configProvider;

import 'golden_fixtures.dart';
import 'golden_fonts.dart';

/// Families that carry real bundled glyphs. Everything else = platform
/// fallback = tofu on a bundle-only device.
const Set<String> _bundledFamilies = {
  'NotoSansBengali',
  'Amiri',
  'AmiriQuran',
  'MaterialIcons',
  'PhosphorRegular',
  'PhosphorFill',
  'PhosphorBold',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Layer 2 of the tofu guard — every resolved text family must be a
  /// bundled family (or inherit one).
  void expectNoPlatformFont(WidgetTester tester, String screen) {
    final offenders = <String>[];

    void checkSpan(InlineSpan span, String? inheritedFamily) {
      if (span is! TextSpan) return;
      final family = span.style?.fontFamily ?? inheritedFamily;
      final text = span.toPlainText();
      if (text.trim().isNotEmpty &&
          (family == null || !_bundledFamilies.contains(family))) {
        offenders.add('"$text" → ${family ?? '(null — platform default)'}');
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        checkSpan(child, family);
      }
    }

    for (final element in find.byType(RichText).evaluate()) {
      final paragraph = element.renderObject;
      if (paragraph is RenderParagraph) {
        checkSpan(paragraph.text, null);
      }
    }
    for (final element in find.byType(EditableText).evaluate()) {
      final editable = element.widget as EditableText;
      final family = editable.style.fontFamily;
      final text = editable.controller.text;
      if (text.trim().isNotEmpty &&
          (family == null || !_bundledFamilies.contains(family))) {
        offenders.add('[input] "$text" → ${family ?? '(null)'}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '$screen renders text through a non-bundled font family — on a '
          'bundle-only device that is tofu (□□□). Offenders:\n'
          '${offenders.join('\n')}',
    );
  }

  Future<ProviderContainer> bootAt(
    WidgetTester tester,
    String path, {
    List<Override> extra = const [],
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.guestProfile();
    await db.saveGuestProfile(
      const GuestProfilesCompanion(onboardingDone: Value(true)),
    );

    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(GoldenSignedInDaee.new),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
        headerNowProvider.overrideWithValue(kGoldenNow),
        apiProvider.overrideWithValue(GoldenApi()),
        ...extra,
      ],
    );
    // NB: NOT addTearDown — the container must be disposed INSIDE the test
    // body (smoke_test pattern) so the 60s sync-flush periodic timer is
    // cancelled before the binding checks for pending timers.
    addTearDown(db.close);

    // Real glyphs before the first capture — BOTH text families and icons
    // (test/golden_fonts.dart). Pixel truth only means something when the
    // pixels show actual Bengali/Arabic shaping, not tofu boxes.
    await warmAppFonts(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BootstrapGate(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
    return container;
  }

  for (final (screen, path) in [
    ('home', '/'),
    ('amal_today', '/amal'),
    ('dawah', '/dawah'),
    ('ilm', '/ilm'),
    ('more', '/more'),
  ]) {
    testWidgets('$screen — bn light renders only bundled fonts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(824, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The More golden renders the §4.3 sections over a fixed contact +
      // group row (see GoldenApi.moreEnrichedConfig).
      final container = await bootAt(
        tester,
        path,
        extra: path == '/more'
            ? [
                configProvider.overrideWith(
                  (ref) async => GoldenApi.moreEnrichedConfig,
                ),
              ]
            : const <Override>[],
      );

      expectNoPlatformFont(tester, screen);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/fonts_${screen}_bn_light.png'),
      );

      // Inside the body — cancels the periodic sync-flush timer in time.
      container.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
