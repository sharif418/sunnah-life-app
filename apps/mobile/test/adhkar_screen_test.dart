// আযকার after the 2026-10-09 rework: counts survive leaving the screen,
// long-press takes one back, the diary ticks at FIVE dhikr (the paper row
// reads "কমপক্ষে ৫ টি") with the catalog's auto source, and the screen
// opens on the period due now.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/adhkar_screen.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

Future<ProviderContainer> pumpAdhkar(
  WidgetTester tester, {
  String? focus = 'morning',
}) async {
  tester.view.physicalSize = const Size(412 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      prayerProvider.overrideWith(GoldenPinnedPrayer.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => ContentPack.adhkar());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: AdhkarScreen(focus: focus),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleAndUnmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  final today = dateKey(DateTime.now());

  setUp(() {
    ContentPack.assetLoaderForTesting = (path) => File(path).readAsString();
  });
  tearDown(ContentPack.resetForTesting);

  test('the period due now: morning Fajr–Dhuhr, after-salah to Asr, '
      'evening after', () {
    String at(double m) =>
        adhkarPeriodAt(m, fajr: 4 * 60.0, dhuhr: 12 * 60.0, asr: 15.5 * 60);
    expect(at(5 * 60), 'morning');
    expect(at(13 * 60), 'post_salat');
    expect(at(18 * 60), 'evening');
    expect(at(2 * 60), 'evening'); // late night
  });

  testWidgets('counts come back after leaving; yesterday\'s do not', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'adhkar_counts_v1': jsonEncode({
        'day': today,
        'counts': {'morning:m2-ikhlas': 2},
      }),
    });
    await pumpAdhkar(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dhikr_m2-ikhlas')),
        matching: find.text('${toBn(2)} / ${toBn(3)}'),
      ),
      findsOneWidget,
    );
    await settleAndUnmount(tester);

    SharedPreferences.setMockInitialValues({
      'adhkar_counts_v1': jsonEncode({
        'day': '2000-01-01',
        'counts': {'morning:m2-ikhlas': 2},
      }),
    });
    await pumpAdhkar(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dhikr_m2-ikhlas')),
        matching: find.text('${toBn(0)} / ${toBn(3)}'),
      ),
      findsOneWidget,
    );
    await settleAndUnmount(tester);
  });

  testWidgets('long-press takes one count back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'adhkar_counts_v1': jsonEncode({
        'day': today,
        'counts': {'morning:m2-ikhlas': 2},
      }),
    });
    await pumpAdhkar(tester);
    await tester.longPress(find.byKey(const ValueKey('dhikr_m2-ikhlas')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dhikr_m2-ikhlas')),
        matching: find.text('${toBn(1)} / ${toBn(3)}'),
      ),
      findsOneWidget,
    );
    await settleAndUnmount(tester);
  });

  testWidgets('the fifth finished dhikr ticks the diary, as auto:adhkar', (
    tester,
  ) async {
    // four done, the fifth one tap away
    SharedPreferences.setMockInitialValues({
      'adhkar_counts_v1': jsonEncode({
        'day': today,
        'counts': {
          'morning:m1-ayatul-kursi': 1,
          'morning:m2-ikhlas': 3,
          'morning:m3-falaq': 3,
          'morning:m4-nas': 3,
        },
      }),
    });
    final container = await pumpAdhkar(tester);
    expect(container.read(amalProvider).entry(today, 'adhkar_morning'), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('dhikr_m8-allahumma-bika-asbahna')),
    );
    await tester.pumpAndSettle();
    // on the Arabic (the tile's middle may hold the ফযীলত toggle)
    final g = await tester.startGesture(
      tester.getTopLeft(
            find.byKey(const ValueKey('dhikr_m8-allahumma-bika-asbahna')),
          ) +
          const Offset(40, 24),
    );
    await g.up();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dhikr_m8-allahumma-bika-asbahna')),
        matching: find.text('${toBn(1)} / ${toBn(1)}'),
      ),
      findsOneWidget,
      reason: 'the tap counted',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dhikr_m4-nas')),
        matching: find.text('${toBn(3)} / ${toBn(3)}'),
      ),
      findsOneWidget,
      reason: 'restored',
    );
    final entry = container.read(amalProvider).entry(today, 'adhkar_morning');
    expect(entry?.value, true);
    expect(entry?.source, 'auto:adhkar:morning');
    expect(
      find.byKey(const ValueKey('adhkar_ticked_morning')),
      findsOneWidget,
    );
    await settleAndUnmount(tester);
  });

  testWidgets('without a focus: one tab per period', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpAdhkar(tester, focus: null);
    expect(find.byKey(const ValueKey('adhkar_tab_morning')), findsOneWidget);
    expect(find.byKey(const ValueKey('adhkar_tab_evening')), findsOneWidget);
    expect(find.byKey(const ValueKey('adhkar_tab_post_salat')), findsOneWidget);
    await settleAndUnmount(tester);
  });
}
