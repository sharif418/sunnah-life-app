// C-W4b home rewiring widget tests — the ring hero (existence + per-second
// state flow), the সর্বাধিক ব্যবহৃত section (empty for a fresh guest, seeded
// cards with the days chip, the quick-log write), the quick-access grid's
// navigation, the amal preview ring's numbers and the live preview card.
//
// Pattern: in-memory Drift + provider overrides (today_diary_widget_test).
// Remote packs (courses/quizzes/live) are overridden so nothing touches the
// network and every assertion is deterministic.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/core/amal_engine.dart' show isAmalDay;
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/amal_widgets.dart' show CompletionRing;
import 'package:sunnah_life/features/home/home_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppDatabase makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

  /// Deterministic remote packs: empty courses/quizzes/live (individual
  /// tests override live with a program).
  List<Override> quietRemote() => [
        coursePackProvider.overrideWith((ref) async => <CourseSummary>[]),
        quizPackProvider.overrideWith((ref) async => <Quiz>[]),
        liveProvider.overrideWith((ref) async => <LiveProgramItem>[]),
      ];

  Future<ProviderContainer> bootHome(
    WidgetTester tester,
    AppDatabase db, {
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db), ...extra],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The home ListView is lazy — everything below the fold needs a scroll.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'countdown ring hero renders and the waqt state flows every second',
      (tester) async {
    final db = makeDb();
    final container = await bootHome(tester, db, extra: quietRemote());

    // The hero card + its painted ring + the countdown text + the
    // in-page-schedule affordance all exist.
    final hero = find.byKey(const ValueKey('home_ring_hero'));
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    final countdown = find.byKey(const ValueKey('home_countdown_text'));
    expect(countdown, findsOneWidget);
    expect(find.byKey(const ValueKey('home_to_schedule')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'prayer_schedule')), findsOneWidget);

    // The tick: pumping two seconds fires the 1s ticker twice and the
    // provider re-emits NEW state each fire (a fresh PrayerNow carrying
    // the advanced nowMinutes — the ring fraction + HH:MM:SS both derive
    // from it). NB: DateTime.now() is NOT faked by the test binding (only
    // timers are), so the rendered string is compared against the latest
    // state's own countdownText instead of differing across a fake second.
    final s0 = container.read(prayerProvider)!;
    await tester.pump(const Duration(seconds: 2));
    final s1 = container.read(prayerProvider)!;
    expect(identical(s0, s1), isFalse); // per-second re-emission
    expect(s1.nowMinutes, greaterThanOrEqualTo(s0.nowMinutes));
    expect(
      (tester.widget(countdown) as Text).data,
      s1.countdownText(bengali: true),
    );

    container.dispose();
    await db.close();
  });

  testWidgets('most-used section: fresh guest sees the empty state',
      (tester) async {
    final db = makeDb();
    final container = await bootHome(tester, db, extra: quietRemote());

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'most_used')));
    expect(find.text(S.tr(Lang.bn, 'most_used')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'most_used_empty')), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets(
      'most-used section: seeded history renders the card + days chip, '
      'and আজ লিখুন quick-logs with source quick:home', (tester) async {
    final db = makeDb();
    final today = dateKey(DateTime.now());
    // Two distinct full-point days → above the minDays=2 bar.
    await db.writeEntry(
      amalKey: 'salat_fajr',
      date: addDays(today, -1),
      value: 'jamaat',
      source: 'manual',
      clientUpdatedAt: DateTime.now(),
    );
    await db.writeEntry(
      amalKey: 'salat_fajr',
      date: addDays(today, -2),
      value: 'jamaat',
      source: 'manual',
      clientUpdatedAt: DateTime.now(),
    );

    final container = await bootHome(tester, db, extra: quietRemote());

    final quickLog = find.text(S.tr(Lang.bn, 'most_used_log_today'));
    await scrollTo(tester, quickLog);
    expect(find.text('ফজর নামাজ'), findsOneWidget);
    // The days chip: 2 days in Bengali digits.
    expect(
      find.text('${toBn(2)} ${S.tr(Lang.bn, 'most_used_days')}'),
      findsOneWidget,
    );
    // Tristate def → quickLogValue = 'jamaat' → the button exists.
    expect(quickLog, findsOneWidget);
    expect(container.read(amalProvider).entry(today, 'salat_fajr'), isNull);

    await tester.tap(quickLog);
    await tester.pumpAndSettle();

    final entry = container.read(amalProvider).entry(today, 'salat_fajr');
    expect(entry, isNotNull);
    expect(entry!.value, 'jamaat');
    expect(entry.source, 'quick:home');

    container.dispose();
    await db.close();
  });

  testWidgets('quick-access grid navigates to its destinations',
      (tester) async {
    final db = makeDb();
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db), ...quietRemote()],
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/ilm/quran',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('QURAN_ROUTE_MARKER')),
          ),
        ),
        GoRoute(
          path: '/ilm/duas',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('DUAS_ROUTE_MARKER')),
          ),
        ),
        GoRoute(
          path: '/amal',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('AMAL_ROUTE_MARKER')),
          ),
        ),
        GoRoute(
          path: '/more/live',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('LIVE_ROUTE_MARKER')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildSunnahLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All four tiles render (scrolled into view first — lazy list).
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'quick_access')));
    for (final title in [
      S.tr(Lang.bn, 'ilm_quran'),
      S.tr(Lang.bn, 'ilm_duas'),
      S.tr(Lang.bn, 'tab_amal'),
      S.tr(Lang.bn, 'more_live'),
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    // Tap the Qur'an tile → the route mounts its destination.
    await tester.tap(find.text(S.tr(Lang.bn, 'ilm_quran')));
    await tester.pumpAndSettle();
    expect(find.text('QURAN_ROUTE_MARKER'), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets('amal preview ring shows today\'s completed/total from seed',
      (tester) async {
    final db = makeDb();
    final today = dateKey(DateTime.now());
    await db.writeEntry(
      amalKey: 'salat_fajr',
      date: today,
      value: 'jamaat',
      source: 'manual',
      clientUpdatedAt: DateTime.now(),
    );

    final container = await bootHome(tester, db, extra: quietRemote());

    // The same grouping rule the screen uses (guest = fallback catalog,
    // effective hijri adjust 0 in tests).
    final total = fallbackDefinitions()
        .where((d) => isAmalDay(d, today, hijriAdjust: 0))
        .length;

    await scrollTo(tester, find.byKey(const ValueKey('home_amal_preview')));
    expect(find.byType(CompletionRing), findsOneWidget);
    expect(
      find.text('${toBn(1)}/${toBn(total)} ${S.tr(Lang.bn, 'done')}'),
      findsOneWidget,
    );

    container.dispose();
    await db.close();
  });

  testWidgets('live preview renders the NEXT upcoming program (not the past '
      'one)', (tester) async {
    final db = makeDb();
    final container = await bootHome(
      tester,
      db,
      extra: [
        ...quietRemote(),
        liveProvider.overrideWith(
          (ref) async => [
            const LiveProgramItem(
              id: 'live-1',
              titleBn: 'সাপ্তাহিক তাফসির সেশন',
              hostName: 'মাওলানা অমুক',
              startsAt: '2026-10-01T20:00:00.000Z',
              gender: Gender.m,
              status: 'upcoming',
            ),
            const LiveProgramItem(
              id: 'live-2',
              titleBn: 'পুরনো পর্ব',
              startsAt: '2026-09-01T20:00:00.000Z',
              gender: Gender.m,
              status: 'past',
            ),
          ],
        ),
      ],
    );

    await scrollTo(tester, find.byKey(const ValueKey('home_live_preview')));
    // The NEXT upcoming program (not the past one) + chip + time + hint.
    expect(find.text('সাপ্তাহিক তাফসির সেশন'), findsOneWidget);
    expect(find.text('পুরনো পর্ব'), findsNothing);
    expect(find.byKey(const ValueKey('home_live_chip')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'live_next')), findsOneWidget);
    expect(find.text('2026-10-01 20:00'), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'live_join_hint')), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets('live preview section hides when nothing is upcoming',
      (tester) async {
    final db = makeDb();
    final container = await bootHome(
      tester,
      db,
      extra: [
        ...quietRemote(),
        liveProvider.overrideWith(
          (ref) async => const [
            LiveProgramItem(
              id: 'live-2',
              titleBn: 'পুরনো পর্ব',
              startsAt: '2026-09-01T20:00:00.000Z',
              gender: Gender.m,
              status: 'past',
            ),
          ],
        ),
      ],
    );

    // Scroll to the very bottom (the footer carries the offline-chip line)
    // — no live preview card, no live_next chip anywhere.
    await scrollTo(
      tester,
      find.textContaining(S.tr(Lang.bn, 'prayer_offline_chip')),
    );
    expect(
      find.byKey(const ValueKey('home_live_preview')),
      findsNothing,
    );
    expect(find.text(S.tr(Lang.bn, 'live_next')), findsNothing);

    container.dispose();
    await db.close();
  });
}
