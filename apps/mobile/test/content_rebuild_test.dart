// A content screen must not reload its pack on every rebuild: a FutureBuilder
// handed a fresh `ContentPack.x()` future in build() drops back to the
// skeleton on each setState — the list is rebuilt, the scroll jumps to the
// top, a search field inside it loses its text focus. (Found 2026-10-09: each
// tap on a dhikr in আযকার threw the reader back to the first item.)
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/adhkar_screen.dart';
import 'package:sunnah_life/features/ilm/names99_screen.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.assetLoaderForTesting = (path) => File(path).readAsString();
  });
  tearDown(ContentPack.resetForTesting);

  testWidgets('আযকার: counting a dhikr keeps the reader where they are', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412 * 3, 860 * 3);
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
          home: const AdhkarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -900));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(500));

    // tap the dhikr tile now in the middle of the screen
    await tester.tapAt(const Offset(206, 430));
    await tester.pump();
    // no skeleton flash…
    expect(find.byType(Skeleton), findsNothing);
    await tester.pumpAndSettle();
    // …and the reader stays where they were
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    // (finishing a one-count dhikr moves on to the next — forward, never
    // back to the top)
    expect(after, greaterThanOrEqualTo(before - 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('৯৯ নাম: typing in search keeps the text and the field', (
    tester,
  ) async {
    await tester.runAsync(() => ContentPack.names99());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const Names99Screen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'রহ');
    await tester.pump();
    expect(find.byType(Skeleton), findsNothing);
    await tester.pumpAndSettle();
    // the same field, still holding what was typed
    expect(find.widgetWithText(TextField, 'রহ'), findsOneWidget);
  });
}
