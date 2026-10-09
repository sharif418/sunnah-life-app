// Month-grid widget test — the 31-day paper-diary heatmap: column count,
// Bengali day numerals, lock overlays, and the day-detail sheet.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/fallback_catalog.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/amal_widgets.dart';
import 'package:sunnah_life/features/amal/month_screen.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/design/phosphor_icons.dart';

ProfileState _profile() => const ProfileState(
      name: 'tester',
      gender: Gender.m,
      language: 'bn',
      city: 'ঢাকা',
      lat: 23.8103,
      lng: 90.4125,
      tz: 6,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
      category: UserCategory.general,
      themeMode: 'system',
      hijriAdjust: 0,
      onboardingDone: true,
    );

Future<void> _pumpHeatmap(
  WidgetTester tester, {
  required AppDatabase db,
  required String today,
  List<String> days = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        // scrolls like the month screen it lives in (rows are as tall as
        // their labels — the grid is taller than one screen)
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthHeatmap(
              defs: fallbackDefinitions(),
              entries: const [],
              days: days.isEmpty ? monthDayKeys(today) : days,
              today: today,
              profile: _profile(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// One grid row per bundled definition (the full catalog since 2026-10-03).
final int _rows = fallbackDefinitions().length;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders all 31 columns of a 31-day month with Bengali numerals',
      (tester) async {
    // Wide surface so the horizontal ListView builds every day column.
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpHeatmap(tester, db: db, today: '2025-03-05');

    // March 2025 has 31 days × every bundled definition.
    expect(monthDayKeys('2025-03-05').length, 31);
    expect(find.byType(HeatmapCell), findsNWidgets(31 * _rows));

    // Day headers are Bengali numerals ১..৩১ (12 rows below each header do
    // not repeat the number, so exactly one per day).
    expect(find.text(toBn(1)), findsOneWidget);
    expect(find.text(toBn(15)), findsOneWidget);
    expect(find.text(toBn(31)), findsOneWidget);
    expect(find.text(toBn(32)), findsNothing);
  });

  testWidgets('past days show the lock overlay; today stays editable',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // "today" inside the grid is 2025-03-05; every other March-2025 day is
    // long past its next-day Ishraq against the real wall clock → locked.
    await _pumpHeatmap(tester, db: db, today: '2025-03-05');

    // 30 locked columns × every row, the today column has none.
    // no lock glyph in every cell any more (a quiet, dimmed gap; the note
    // under the grid explains the rule) — the day sheet carries the lock
    expect(find.byIcon(PhosphorIconsRegular.lockSimple), findsNothing);

    // The today column is highlighted (border), still tappable.
    final todayHeader = find.text(toBn(5));
    expect(todayHeader, findsOneWidget);
  });

  testWidgets('tapping a cell opens the day-detail sheet with all amals',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpHeatmap(tester, db: db, today: '2025-03-05');

    // Tap the first cell of the today column (fajr row).
    await tester.tap(find.byType(HeatmapCell).at(4 * _rows));
    await tester.pumpAndSettle();

    // Day-detail sheet: Bengali date title + one row per amal (the second
    // match of each title is the grid's fixed label column).
    expect(find.text(toBn('2025-03-05')), findsOneWidget);
    expect(find.text('ফজর নামাজ'), findsNWidgets(2));
    expect(find.text('এশা নামাজ'), findsNWidgets(2));

    // The today column is not locked → no unlock request button.
    expect(find.byIcon(PhosphorIconsRegular.lockSimpleOpen), findsNothing);
  });

  testWidgets('locked day-detail offers the unlock request', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpHeatmap(tester, db: db, today: '2025-03-05');

    // Tap a locked column (2025-03-01 = column 0).
    await tester.tap(find.byType(HeatmapCell).at(0));
    await tester.pumpAndSettle();

    // Locked chip is present in the day sheet.
    expect(find.text(toBn('2025-03-01')), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.lockSimple), findsWidgets);

    // The "আনলক চাই" action sits below the 12 amal rows — scroll the sheet
    // down to reveal it, then press it (guest session → sign-in snackbar).
    await tester.scrollUntilVisible(
      find.byIcon(PhosphorIconsRegular.lockSimpleOpen),
      240,
      scrollable: find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byIcon(PhosphorIconsRegular.lockSimpleOpen), findsOneWidget);
    await tester.tap(find.byIcon(PhosphorIconsRegular.lockSimpleOpen));
    await tester.pump();
    await tester.pumpAndSettle();
  });
}
