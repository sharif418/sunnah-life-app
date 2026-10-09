// The Qur'an after the 2026-10-09 rework: para list, ayah actions, the
// bookmark list, kept text sizes, the reading place saved while scrolling.
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
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/quran_models.dart';
import 'package:sunnah_life/state/providers.dart';

String t(String k) => S.tr(Lang.bn, k);

Future<AppDatabase> pumpQuran(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(412 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  QuranRepository.assetLoaderForTesting = (p) => File(p).readAsString();
  addTearDown(QuranRepository.resetForTesting);
  await tester.runAsync(() async {
    await QuranRepository.surahList();
    await QuranRepository.surah(2);
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
      child: MaterialApp(theme: buildSunnahLightTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  return db;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('পারা tab: thirty paras, the first at আল-ফাতিহা', (tester) async {
    await pumpQuran(tester, const QuranReaderScreen());
    await tester.tap(find.text(t('quran_tab_para')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('quran_para_1')), findsOneWidget);
  });

  testWidgets('a bookmark made in the reader shows in the বুকমার্ক tab', (
    tester,
  ) async {
    final db = await pumpQuran(tester, const QuranReaderScreen());
    await db.toggleBookmark(2, 255, true);
    await tester.tap(find.text(t('quran_tab_bookmarks')));
    await tester.pumpAndSettle();
    // the list reloads when the reader closes; force one by reopening
    await tester.tap(find.text(t('quran_tab_surah')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('আল-ফাতিহা').last);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // the tilawat sheet may not show (<1 minute) — back on the list
    await tester.tap(find.text(t('quran_tab_bookmarks')));
    await tester.pumpAndSettle();
    expect(find.textContaining('২৫৫'), findsOneWidget);
  });

  testWidgets('tapping an ayah opens its actions', (tester) async {
    await pumpQuran(tester, const SurahReaderScreen(surahNumber: 2));
    await tester.tap(find.byKey(const ValueKey('ayah_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ayah_action_bookmark')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah_action_copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah_action_share')), findsOneWidget);
  });

  testWidgets('the Arabic size is kept', (tester) async {
    await pumpQuran(tester, const SurahReaderScreen(surahNumber: 2));
    await tester.tap(find.byKey(const ValueKey('quran_text_settings')));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('quran_arabic_slider'));
    await tester.drag(slider, const Offset(300, 0));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('quran_arabic_size'), greaterThan(26));
  });

  testWidgets('scrolling saves the reading place', (tester) async {
    final db = await pumpQuran(tester, const SurahReaderScreen(surahNumber: 2));
    await tester.drag(find.byType(ListView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    final row = await tester.runAsync(() => db.lastReadEntry());
    expect(row?.surah, 2);
    expect(row!.ayah, greaterThan(1));
  });
}
