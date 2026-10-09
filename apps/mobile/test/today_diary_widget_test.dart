// Today-diary widget test — optimistic tristate write through the real
// provider stack (in-memory Drift + fallback catalog + guest mode).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/today_screen.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('tapping জামাতে optimistically writes the fajr diary entry', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const AmalHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fallback catalog is loaded (guest, no network): the salat rows render
    // under the paper diary's wording (ফজর, not ফজর নামাজ).
    expect(find.text('সালাত ট্র্যাকার'), findsOneWidget);
    expect(find.text('ফজর'), findsOneWidget);
    expect(find.text('জামাতে'), findsWidgets);

    // Nothing written yet.
    final today = dateKey(DateTime.now());
    expect(container.read(amalProvider).entry(today, 'salat_fajr'), isNull);

    // Tap the FIRST জামাতে chip — the fajr row's (catalog order).
    await tester.tap(find.text('জামাতে').first);
    await tester.pump();

    // Optimistic state — immediate, before the Drift write lands.
    final entry = container.read(amalProvider).entry(today, 'salat_fajr');
    expect(entry, isNotNull);
    expect(entry!.value, 'jamaat');
    expect(entry.source, 'manual');

    // The persisted row exists in the local DB too.
    final persisted = await db.entry('salat_fajr', today);
    expect(persisted, isNotNull);
    expect(persisted!.value, 'jamaat');

    await tester.pumpAndSettle();

    // Tapping the same chip again clears the selection (tri-state semantics).
    await tester.tap(find.text('জামাতে').first);
    await tester.pump();
    expect(container.read(amalProvider).entry(today, 'salat_fajr')?.value, '');
    await tester.pumpAndSettle();
  });

  testWidgets('title, progress ring, instructions + shortcuts render', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const AmalHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('আজকের মুহাসাবা'), findsOneWidget);
    expect(find.byType(SyncBadge), findsOneWidget);
    // the progress ring counts the paper rows due today: ০/N
    expect(find.textContaining('০/'), findsWidgets);

    // the paper's নির্দেশনাবলী open from the header
    await tester.tap(find.byKey(const ValueKey('diary_instructions_button')));
    await tester.pumpAndSettle();
    expect(find.text('মুহাসাবা ডায়েরির নির্দেশনাবলী'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // The quick-action chips exist.
    expect(find.text('মাসের গ্রিড'), findsOneWidget);
    expect(find.text('অভ্যাস চ্যালেঞ্জ'), findsOneWidget);
    expect(find.text('শরীরচর্চা'), findsOneWidget);
    // the row scrolls sideways — the later chips are a swipe away
    await tester.dragUntilVisible(
      find.text('আত্মযাচাই'),
      find.text('মাসের গ্রিড'),
      const Offset(-200, 0),
    );
    expect(find.text('আত্মযাচাই'), findsOneWidget);
  });
}
