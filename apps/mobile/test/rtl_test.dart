// RTL + hot-swap — switching the persisted profile language to Arabic must
// rebuild MaterialApp with the ar locale: labels switch AND the ambient
// Directionality flips to RTL, without any restart.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/providers.dart';

Future<AppDatabase> _seededDb(String language) async {
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

  for (final (lang, rtl, homeLabel) in [
    ('ar', true, 'الرئيسية'),
    ('en', false, 'Home'),
    ('bn', false, 'হোম'),
  ]) {
    testWidgets('locale $lang boots with labels + direction '
        '${rtl ? 'RTL' : 'LTR'}', (tester) async {
      final db = await _seededDb(lang);
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BootstrapGate(),
        ),
      );
      await tester.pumpAndSettle();

      // The bottom nav shows the localized label.
      final label = find.text(homeLabel).last;
      expect(label, findsOneWidget);

      // The ambient direction at that label flipped with the locale
      // (this is the real RTL check — not just an icon mirror).
      final ctx = tester.element(label);
      expect(
          Directionality.of(ctx), rtl ? TextDirection.rtl : TextDirection.ltr);

      // Dispose inside the test body so provider timers (prayer ticker,
      // 60s sync flush) are cancelled before the binding checks.
      container.dispose();
    });
  }

  testWidgets('switching language hot-swaps locale + direction (no restart)',
      (tester) async {
    final db = await _seededDb('bn');
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BootstrapGate(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('হোম'), findsOneWidget);
    var ctx = tester.element(find.text('হোম'));
    expect(Directionality.of(ctx), TextDirection.ltr);

    // Flip the persisted profile language — the same running app must
    // re-localize + flip direction immediately.
    await container
        .read(profileProvider.notifier)
        .update(language: 'ar');
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    ctx = tester.element(find.text('الرئيسية'));
    expect(Directionality.of(ctx), TextDirection.rtl);

    // Dispose inside the test body so provider timers are cancelled first.
    container.dispose();
  });
}
