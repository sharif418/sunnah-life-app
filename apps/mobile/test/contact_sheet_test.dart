// The headset button (2026-10-10): its sheet leads with help for the app,
// then the institutions as one compact list — a row opens the website, a
// mail button shows only where the Foundation gave an address.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/phosphor_icons.dart';
import 'package:sunnah_life/features/more/support_screen.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

class _ContactsApi extends GoldenApi {
  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
    contacts: [
      ConfigContact(
        org: 'দাওয়াতুস সুন্নাহ',
        descBn: 'দাওয়াত ও তারবিয়াত বিভাগ',
        website: 'https://as-sunnah.org',
      ),
      ConfigContact(
        org: 'আস-সুন্নাহ ফাউন্ডেশন',
        descBn: 'মূল সংস্থা',
        website: 'https://as-sunnah.org',
        email: 'info@as-sunnah.org',
      ),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('help first, then the institutions; live support opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(824, 1600);
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
        apiProvider.overrideWithValue(_ContactsApi()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const BootstrapGate()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('সাহায্য ও যোগাযোগ'));
    await tester.pumpAndSettle();
    expect(find.text('লাইভ সাপোর্ট'), findsOneWidget);
    expect(find.text('সাধারণ প্রশ্নোত্তর'), findsOneWidget);
    expect(find.text('মাসআলা জিজ্ঞাসা'), findsOneWidget);
    expect(find.text('আমাদের প্রতিষ্ঠান'), findsOneWidget);
    // mail only where an address was given; no phone given → no call
    expect(
      find.byTooltip('আস-সুন্নাহ ফাউন্ডেশন-কে ইমেইল করুন'),
      findsOneWidget,
    );
    expect(find.byTooltip('দাওয়াতুস সুন্নাহ-কে ইমেইল করুন'), findsNothing);
    expect(find.byIcon(PhosphorIconsRegular.phone), findsNothing);

    await tester.tap(find.byKey(const ValueKey('contact_support')));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
    c.dispose();
  });
}
