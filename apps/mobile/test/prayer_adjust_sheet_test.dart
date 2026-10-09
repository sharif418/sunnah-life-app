// নিজের মসজিদের সাথে মেলান (2026-10-09): Profile → the sheet → +/− per waqt
// → সংরক্ষণ — kept on the phone and shown back on the Profile row.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/core/prayer_adjust.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('+2 on Fajr, saved: kept and summarised on the Profile row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(824, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.guestProfile();
    await db.saveGuestProfile(
      const GuestProfilesCompanion(onboardingDone: Value(true)),
    );
    final c = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(GoldenSignedInDaee.new),
        prayerProvider.overrideWith(GoldenPinnedPrayer.new),
        headerNowProvider.overrideWithValue(kGoldenNow),
        apiProvider.overrideWithValue(GoldenApi()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const BootstrapGate()),
    );
    await tester.pumpAndSettle();
    c.read(routerProvider).go('/more/profile');
    await tester.pumpAndSettle();

    expect(find.text('সমন্বয় নেই'), findsOneWidget);
    await tester.ensureVisible(find.text('নিজের মসজিদের সাথে মেলান'));
    await tester.tap(find.text('নিজের মসজিদের সাথে মেলান'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('ফজর এক মিনিট পরে'));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    expect(find.text('+২'), findsOneWidget);
    // nothing earlier → no caution
    expect(find.textContaining('ওয়াক্ত শুরুর আগে'), findsNothing);
    await tester.tap(find.text('সংরক্ষণ করুন'));
    await tester.pumpAndSettle();

    expect(
      c.read(profileProvider).prayerAdjust,
      PrayerAdjust.parse({'fajr': 2}),
    );
    expect(
      PrayerAdjust.parse((await db.guestProfile()).prayerAdjust).toJson(),
      {'fajr': 2},
    );
    expect(find.text('ফজর +২'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
    c.dispose();
  });
}
