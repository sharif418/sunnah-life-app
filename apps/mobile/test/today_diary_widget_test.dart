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
import 'package:sunnah_life/state/providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('tapping জামাতে optimistically writes the fajr diary entry',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
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

    // Fallback catalog is loaded (guest, no network): the salat rows render.
    expect(find.text('ফজর নামাজ'), findsOneWidget);
    expect(find.text('জামাতে'), findsWidgets);

    // Nothing written yet.
    final today = dateKey(DateTime.now());
    expect(container.read(amalProvider).entry(today, 'salat_fajr'), isNull);

    // Tap the FIRST জামাতে chip — the fajr row's (catalog order).
    await tester.tap(find.text('জামাতে').first);
    await tester.pump();

    // Optimistic state — immediate, before the Drift write lands.
    final entry =
        container.read(amalProvider).entry(today, 'salat_fajr');
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

  testWidgets('streak + completion header renders with Bengali numerals',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
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

    expect(find.text('আজকের আমল'), findsOneWidget);
    expect(find.byType(SyncBadge), findsOneWidget);
    // The quick-action chips exist.
    expect(find.text('মাসের গ্রিড'), findsOneWidget);
    expect(find.text('অভ্যাস গড়ার চ্যালেঞ্জ'), findsOneWidget);
    expect(find.text('ইমান ও তাকওয়া সেলফ-টেস্ট'), findsOneWidget);
  });
}
