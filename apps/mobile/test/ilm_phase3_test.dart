// Ilm, last round (2026-10-09): a sunnah ticked as practised today is kept;
// the Ilm hub offers "continue" at the last Qur'an place.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/sunnahs_screen.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/models/quran_models.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart';
import 'package:sunnah_life/features/ilm/ilm_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.assetLoaderForTesting = (p) => File(p).readAsString();
    QuranRepository.assetLoaderForTesting = (p) => File(p).readAsString();
  });
  tearDown(() {
    ContentPack.resetForTesting();
    QuranRepository.resetForTesting();
  });

  testWidgets('a sunnah ticked today is kept for today', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final raw = jsonDecode(File('assets/content/sunnahs.json').readAsStringSync());
    final first = ((raw is Map ? raw['items'] ?? raw['sunnahs'] : raw) as List)
        .cast<Map>()
        .first;
    await tester.runAsync(() => ContentPack.sunnahs());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const SunnahsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('sunnah_done_${first['id']}')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('sunnah_done_v1')!) as Map;
    expect(saved['day'], dateKey(DateTime.now()));
    expect(saved['ids'], contains(first['id']));
  });

  testWidgets('the Ilm hub offers the last Qur\'an place', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveLastRead(36, 12);
    // the surah names (real file I/O cannot finish inside fake async)
    await tester.runAsync(() => QuranRepository.surahList());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          coursePackProvider.overrideWith((ref) async => const []),
          enrollmentsProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const IlmScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ilm_continue_quran')), findsOneWidget);
    expect(find.textContaining('ইয়া-সীন'), findsOneWidget);
  });
}
