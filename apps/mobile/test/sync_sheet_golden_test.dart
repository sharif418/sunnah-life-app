// Sync sheet golden (C-W3d, the PLAN's golden for the sync state UI) — the
// sheet in bn light with pending=2 + dead=1 (a reason captured from a
// newerVersion rejection) + a fixed last-sync time, opened through the REAL
// badge tap.
//
// Determinism contract (mirrors test/quran_golden_test.dart):
//  * GoogleFonts.allowRuntimeFetching = false — fonts come from the
//    committed assets/google_fonts/ bundle; families warmed by calling the
//    style builders under tester.runAsync(...) with a 400 ms real delay.
//  * In-memory Drift DB seeded with 2 alive + 1 dead outbox rows on FIXED
//    dates (no wall-clock dates anywhere in the capture).
//  * syncProvider overridden with a fixed state (pending=2, dead=1,
//    lastSyncedAt = fixed instant) and syncClockProvider pinned to a fixed
//    `now` — the relative "৫ মিনিট আগে" label is pure arithmetic on the
//    difference, so it never drifts.
//  * amalDefinitionsProvider resolves through the guest fallback catalog
//    (no network) — the dead row's label comes from the committed pack.
//  * Fixed 800×1600 surface, DPR 1.0, default text scale.
//
// Regenerate with: flutter test --update-goldens test/sync_sheet_golden_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/shared/sync_sheet.dart'
    show syncClockProvider;
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/l10n/generated/app_localizations.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/providers.dart';

/// The pinned instant: 2025-06-15 12:00 (local-wall irrelevant — only the
/// FIXED difference between `now` and `lastSyncedAt` is ever rendered).
final DateTime _kNow = DateTime(2025, 6, 15, 12);

class _FixedSyncNotifier extends SyncNotifier {
  _FixedSyncNotifier(this.fixed);
  final SyncState fixed;

  @override
  SyncState build() => fixed; // no auth listener, no count refresh — pinned
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('sync sheet golden — bn light (pending 2, dead 1, reason)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Warm the theme's family through google_fonts' own loader (asset-backed
    // since runtime fetching is off) — first capture would show tofu.
    await tester.runAsync(() async {
      GoogleFonts.hindSiliguri(fontSize: 10);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.writeEntry(
        amalKey: 'salat_fajr',
        date: '2025-06-15',
        value: 'alone',
        source: 'manual',
        clientUpdatedAt: DateTime(2025, 6, 15, 8));
    await db.writeEntry(
        amalKey: 'salat_dhuhr',
        date: '2025-06-15',
        value: 'jamaat',
        source: 'manual',
        clientUpdatedAt: DateTime(2025, 6, 15, 9));
    await db.writeEntry(
        amalKey: 'tilawat',
        date: '2025-06-14',
        value: 5,
        source: 'manual',
        clientUpdatedAt: DateTime(2025, 6, 14, 22));
    // The dead row: a newerVersion rejection (the server's reason string).
    await db.recordRejection(
      amalKey: 'tilawat',
      date: '2025-06-14',
      reason: 'নতুন সংস্করণ আছে',
      dead: true,
      now: DateTime(2025, 6, 15, 10),
    );

    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      // Pinned clock: the relative "last synced" label is pure arithmetic
      // on now − lastSyncedAt, so the golden never drifts with the calendar.
      syncClockProvider.overrideWithValue(() => _kNow),
      syncProvider.overrideWith(
        () => _FixedSyncNotifier(
          SyncState(
            pending: 2,
            dead: 1,
            syncing: false,
            lastSyncedAt: _kNow.subtract(const Duration(minutes: 5)),
            lastMessage: 'সার্ভার জানিয়েছে: নতুন সংস্করণ আছে',
          ),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildSunnahLightTheme(),
          locale: const Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: SyncBadge())),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Open the sheet through the real affordance (badge tap).
    await tester.tap(find.byType(SyncBadge));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Deterministic font guard: every Bengali string in the sheet must
    // resolve to the theme's Hind Siliguri family — a style falling back to
    // the test default font would render tofu (labelLarge/titleSmall are NOT
    // part of the app text theme, so the sheet derives from body* styles).
    final nowLabel = S.tr(Lang.bn, 'sync_now');
    final buttonLabel = tester.widget<Text>(
      find.descendant(of: find.byType(FilledButton), matching: find.text(nowLabel)),
    );
    expect(buttonLabel.style?.fontFamily, contains('HindSiliguri'),
        reason: 'the button label must not fall back to the default font');
    final failedLabel = S.tr(Lang.bn, 'sync_failed_entries');
    final failedHeader = tester.widget<Text>(find.textContaining(failedLabel));
    expect(failedHeader.style?.fontFamily, contains('HindSiliguri'));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sync_sheet_bn_light.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
