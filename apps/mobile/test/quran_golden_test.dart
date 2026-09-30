// Qur'an reader goldens (W3a) — the PLAN's "golden tests bn light/dark +
// ar RTL". Four pixels: the surah LIST (bn light) and the READER for
// Al-Fatihah in bn light, bn dark and ar RTL — reached through the REAL
// navigation (tap the first surah card), with the REAL bundled content packs
// (114-surah metadata, Uthmani text, Bengali translation) loading through
// the repository's single-flight path.
//
// Determinism contract:
//  * configProvider overridden — audio affordances are OFF regardless of
//    any network reachability on the runner (the audioBase gate).
//  * In-memory Drift DB with a seeded guest profile (language + theme mode);
//    no last-read chip (nothing stored).
//  * GoogleFonts.allowRuntimeFetching = false — fonts come from the committed
//    assets/google_fonts/ bundle, never the network.
//  * Fixed 800×1600 surface, DPR 1.0, default text scale.
//  * compute() is bypassed under FLUTTER_TEST (see quran_models.dart), so the
//    pack decode is inline and identical on every Linux runner.
//
// Regenerate with: flutter test --update-goldens test/quran_golden_test.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/l10n/generated/app_localizations.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/quran_reader_screen.dart';
import 'package:sunnah_life/models/quran_models.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart';

import 'golden_fonts.dart' show warmAppFonts;

/// Offline-shaped config with NO audioBase — the reader's play buttons are
/// hidden on every machine that runs this, CI or laptop. Nisab prices use
/// the shared offline fallback constants (remote_state.dart) so a pack
/// change can never leave this copy drifting.
const AppConfig _kGoldenConfig = AppConfig(
  donationUrl: kFallbackDonationUrl,
  domain: 'sunnahlife.app',
  hijriAdjust: 0,
  goldPerGramBdt: kFallbackGoldPerGramBdt,
  silverPerGramBdt: kFallbackSilverPerGramBdt,
);

Future<AppDatabase> _dbFor(String language) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.guestProfile(); // create the single row
  await db.saveGuestProfile(
    GuestProfilesCompanion(
      onboardingDone: const Value(true),
      language: Value(language),
    ),
  );
  return db;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // rootBundle platform-channel loads cannot complete inside the widget
  // test's fake-async zone (the load would hang the skeleton shimmer and
  // pumpAndSettle would time out). Inject a real-File loader and pre-warm
  // the repository's static caches under tester.runAsync — the real 5MB
  // packs from assets/content, decoded through the same single-flight path
  // the app uses.
  Future<void> prewarmPacks(WidgetTester tester) async {
    QuranRepository.assetLoaderForTesting =
        (path) => File(path).readAsString();
    addTearDown(QuranRepository.resetForTesting);
    await tester.runAsync(() async {
      await QuranRepository.surahList();
    });
    // W5: the real text families (Hind Siliguri ×3 weights, Amiri,
    // AmiriQuran) + the Phosphor icons, registered through the shared
    // FontLoader helper — deterministic, no google_fonts lazy-load race
    // and no 400ms settle guess (the old approach could still capture
    // tofu on a slow first frame).
    await warmAppFonts(tester);
  }

  for (final scenario in [
    (lang: 'bn', mode: ThemeMode.light, name: 'bn_light'),
    (lang: 'bn', mode: ThemeMode.dark, name: 'bn_dark'),
    (lang: 'ar', mode: ThemeMode.light, name: 'ar_rtl'),
  ]) {
    testWidgets('reader golden — ${scenario.name}', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await prewarmPacks(tester);

      final db = await _dbFor(scenario.lang);
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
        configProvider.overrideWith((ref) async => _kGoldenConfig),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildSunnahLightTheme(),
            darkTheme: buildSunnahDarkTheme(),
            themeMode: scenario.mode,
            // Locale wiring mirrors app.dart — ar flips the whole tree.
            locale: Locale(scenario.lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const QuranReaderScreen(),
          ),
        ),
      );
      // The ~5MB packs were pre-warmed under runAsync; the list settles
      // (fonts + l10n + one frame).
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (scenario.name == 'bn_light') {
        // The LIST golden only for bn light — the other scenarios tap
        // straight through to the reader.
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/quran_list_bn_light.png'),
        );
      }

      // Open Al-Fatihah through the real navigation (first surah card).
      await tester.tap(find.text('আল-ফাতিহা').last);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quran_reader_${scenario.name}.png'),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
