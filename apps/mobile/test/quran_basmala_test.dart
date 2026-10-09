// The Basmala is stripped from ayah 1 of every surah but al-Fatiha (where it
// IS ayah 1) and at-Tawbah (which has none) — so the reader must draw it
// above the first ayah itself. It never did (found 2026-10-09).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/quran_reader_screen.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/models/quran_models.dart';
import 'package:sunnah_life/state/providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> openSurah(WidgetTester tester, String number) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    QuranRepository.assetLoaderForTesting = (p) => File(p).readAsString();
    addTearDown(QuranRepository.resetForTesting);
    await tester.runAsync(() async {
      await QuranRepository.surahList();
      await QuranRepository.surah(int.parse(number));
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.guestProfile();
    await db.saveGuestProfile(
      const GuestProfilesCompanion(onboardingDone: Value(true)),
    );
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const QuranReaderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.enterText(find.byType(TextField).first, number);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppCard).first);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('সূরা ইখলাস opens under the Basmala', (tester) async {
    await openSurah(tester, '112');
    expect(find.byKey(const ValueKey('quran_basmala')), findsOneWidget);
  });

  testWidgets('আল-ফাতিহা has no extra Basmala (it is ayah 1)', (tester) async {
    await openSurah(tester, '1');
    expect(find.byKey(const ValueKey('quran_basmala')), findsNothing);
  });
}
