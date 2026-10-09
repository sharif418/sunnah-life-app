// আমার মসজিদ (2026-10-09): nearby mosques from the server (OpenStreetMap +
// verified), how far / on foot / which way, starring into "আমার মসজিদ"
// (kept on the phone), and the offline fallback to the Foundation's list.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

class _OfflineApi extends GoldenApi {
  @override
  Future<NearbyMosques> mosquesNear(double lat, double lng) async =>
      throw Exception('offline');
}

Future<ProviderContainer> _open(WidgetTester tester, ApiClient api) async {
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
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      authProvider.overrideWith(GoldenSignedInDaee.new),
      prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      headerNowProvider.overrideWithValue(kGoldenNow),
      apiProvider.overrideWithValue(api),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const BootstrapGate()),
  );
  await tester.pumpAndSettle();
  container.read(routerProvider).go('/more/mosques');
  await tester.pumpAndSettle();
  return container;
}

/// Unmount, let the screen's timers (snackbar) run out, and dispose the
/// container inside the body — it owns the periodic sync timer.
Future<void> _close(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
  c.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('nearby: distance, on foot, direction; unnamed and verified said plainly', (tester) async {
    final c = await _open(tester, GoldenApi());
    expect(find.text('Kalachadpur Paschimpara Jame Masjid'), findsOneWidget);
    expect(find.text('২৩০ মিটার · হেঁটে ~৩ মিনিট · পূর্বে'), findsOneWidget);
    expect(find.text('মসজিদ (নাম জানা নেই)'), findsNWidgets(2));
    expect(find.text('যাচাইকৃত'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap', skipOffstage: false), findsOneWidget);
    await _close(tester, c);
  });

  testWidgets('a star moves the mosque into আমার মসজিদ, kept on the phone', (tester) async {
    final c = await _open(tester, GoldenApi());
    expect(find.textContaining('তারকা চিহ্নে চাপুন'), findsOneWidget); // empty hint
    await tester.tap(find.byTooltip('আমার মসজিদে রাখুন বা সরান').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('তারকা চিহ্নে চাপুন'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('my_mosques_v1')!) as List;
    expect((saved.single as Map)['nameBn'], 'Kalachadpur Paschimpara Jame Masjid');
    await _close(tester, c);
  });

  testWidgets('offline with nothing kept: the Foundation list, and it says so', (tester) async {
    await tester.runAsync(() async {
      // the bundled pack loads through rootBundle — prewarm it off the fake clock
      ContentPack.resetForTesting();
      await ContentPack.mosques();
    });
    final c = await _open(tester, _OfflineApi());
    expect(find.text('ইন্টারনেট নেই — ফাউন্ডেশনের তালিকা থেকে দেখানো হচ্ছে'), findsOneWidget);
    expect(find.text('যাচাইকৃত'), findsWidgets);
    await _close(tester, c);
  });
}
