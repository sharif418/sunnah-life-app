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

import 'package:sunnah_life/core/day_card.dart';
import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/core/diary_layout.dart';
import 'package:sunnah_life/core/amal_engine.dart' show isAmalDay;
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
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

  testWidgets('the prayer card renders and its time left follows the clock', (
    tester,
  ) async {
    final db = makeDb();
    final container = await bootHome(tester, db, extra: quietRemote());

    // The card, its painted sky, the time left and the in-page link to
    // the schedule all exist.
    final card = find.byKey(const ValueKey('home_sun_card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null,
        ),
      ),
      findsWidgets,
    );
    final left = find.byKey(const ValueKey('home_waqt_left'));
    expect(left, findsOneWidget);
    expect(find.byKey(const ValueKey('home_to_schedule')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_today_strip')), findsOneWidget);
    // the schedule sits below the fold (built — the page caches it so the
    // card's in-page link always has a target)
    expect(
      find.text(S.tr(Lang.bn, 'prayer_schedule'), skipOffstage: false),
      findsOneWidget,
    );

    // The tick: pumping two seconds fires the 1s ticker twice and the
    // provider re-emits a fresh PrayerNow; the time left is derived from
    // the LATEST state (DateTime.now() is not faked, so compare against
    // the state's own arithmetic rather than a fixed string).
    final s0 = container.read(prayerProvider)!;
    await tester.pump(const Duration(seconds: 2));
    final s1 = container.read(prayerProvider)!;
    expect(identical(s0, s1), isFalse); // per-second re-emission
    expect(s1.nowMinutes, greaterThanOrEqualTo(s0.nowMinutes));
    final m = computeDayCard(s1.times, s1.nowMinutes).minutesLeft;
    final h = m ~/ 60, mm = m % 60;
    final expected = [
      if (h > 0) '${toBn(h)} ${S.tr(Lang.bn, 'sun_hours')}',
      '${toBn(mm)} ${S.tr(Lang.bn, 'sun_minutes')}',
    ].join(' ');
    expect(
      (tester.widget(left) as Text).data,
      '$expected ${S.tr(Lang.bn, 'sun_left')}',
    );

    container.dispose();
    await db.close();
  });

  testWidgets('most-used section: hidden for a fresh guest', (tester) async {
    final db = makeDb();
    final container = await bootHome(tester, db, extra: quietRemote());

    // nothing to rank on day one: the section stays out of the way (the
    // muhasaba card already invites the first entry)
    await scrollTo(tester, find.byKey(const ValueKey('home_amal_preview')));
    expect(find.text(S.tr(Lang.bn, 'most_used')), findsNothing);
    expect(find.text(S.tr(Lang.bn, 'most_used_empty')), findsNothing);

    container.dispose();
    await db.close();
  });

  testWidgets('most-used section: seeded history renders the card + days chip, '
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
    // The usage line: 2 days in Bengali digits.
    expect(
      find.text(S.tr(Lang.bn, 'most_used_days_fmt').replaceAll('%n', toBn(2))),
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
    // logged with full points: the button gives way to the done mark
    expect(quickLog, findsNothing);
    expect(
      find.byKey(const ValueKey('most_used_done_salat_fajr')),
      findsOneWidget,
    );

    container.dispose();
    await db.close();
  });

  testWidgets('quick-access grid navigates to its destinations', (
    tester,
  ) async {
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
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('QURAN_ROUTE_MARKER'))),
        ),
        GoRoute(
          path: '/ilm/duas',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('DUAS_ROUTE_MARKER'))),
        ),
        GoRoute(
          path: '/amal',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('AMAL_ROUTE_MARKER'))),
        ),
        GoRoute(
          path: '/more/live',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('LIVE_ROUTE_MARKER'))),
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

    // The HOME-05 set renders (scrolled into view first — lazy list):
    // সালাত পরবর্তী দোয়া, সকাল-সন্ধ্যার যিকির, কুরআন, মুহাসাবা চেকলিস্ট,
    // আমল ট্র্যাকার, লাইভ.
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'quick_access')));
    for (final title in [
      S.tr(Lang.bn, 'quick_post_salah'),
      S.tr(Lang.bn, 'quick_adhkar'),
      S.tr(Lang.bn, 'ilm_quran'),
      S.tr(Lang.bn, 'quick_muhasaba'),
      S.tr(Lang.bn, 'quick_tracker'),
      S.tr(Lang.bn, 'more_live'),
    ]) {
      await scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'ilm_quran')));

    // Tap the Qur'an tile → the route mounts its destination.
    await tester.tap(find.text(S.tr(Lang.bn, 'ilm_quran')));
    await tester.pumpAndSettle();
    expect(find.text('QURAN_ROUTE_MARKER'), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets('amal preview ring shows today\'s completed/total from seed', (
    tester,
  ) async {
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

    // The same rule the screen uses: today's PAPER diary rows (guest =
    // fallback catalog, effective hijri adjust 0 in tests).
    final total = layoutDiary(
      fallbackDefinitions()
          .where((d) => isAmalDay(d, today, hijriAdjust: 0))
          .toList(),
    ).paper.fold<int>(0, (n, g) => n + g.rows.length);

    await scrollTo(tester, find.byKey(const ValueKey('home_amal_preview')));
    expect(find.text(S.tr(Lang.bn, 'home_muhasaba_title')), findsOneWidget);
    expect(find.text('${toBn(1)}/${toBn(total)}'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_muhasaba_open')), findsOneWidget);

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
    // The NEXT upcoming program (not the past one) + chip + date tile +
    // host + remind-me.
    expect(find.text('সাপ্তাহিক তাফসির সেশন'), findsOneWidget);
    expect(find.text('পুরনো পর্ব'), findsNothing);
    expect(find.byKey(const ValueKey('home_live_chip')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'live_next')), findsOneWidget);
    // local date in the tile, Bengali (the old raw '2026-10-01 20:00' was
    // the UTC clock)
    expect(find.text(S.tr(Lang.bn, 'month_10')), findsOneWidget);
    expect(find.text('মাওলানা অমুক'), findsOneWidget);
    expect(find.byKey(const ValueKey('live_remind_live-1')), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets('HOME-10: a program live NOW wins, with এখন লাইভ + watch', (
    tester,
  ) async {
    final db = makeDb();
    final container = await bootHome(
      tester,
      db,
      extra: [
        ...quietRemote(),
        liveProvider.overrideWith(
          (ref) async => [
            const LiveProgramItem(
              id: 'up-1',
              titleBn: 'আগামী পর্ব',
              startsAt: '2026-10-01T20:00:00.000Z',
              gender: Gender.m,
              status: 'upcoming',
            ),
            const LiveProgramItem(
              id: 'live-now',
              titleBn: 'জুমার আলোচনা',
              startsAt: '2026-09-30T08:00:00.000Z',
              gender: Gender.m,
              status: 'live',
              youtubeId: 'abc123',
            ),
          ],
        ),
      ],
    );

    await scrollTo(tester, find.byKey(const ValueKey('home_live_preview')));
    expect(find.text('জুমার আলোচনা'), findsOneWidget);
    expect(find.text('আগামী পর্ব'), findsNothing);
    expect(find.text(S.tr(Lang.bn, 'live_now')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_live_watch')), findsOneWidget);

    container.dispose();
    await db.close();
  });

  testWidgets('live preview section hides when nothing is upcoming', (
    tester,
  ) async {
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
    expect(find.byKey(const ValueKey('home_live_preview')), findsNothing);
    expect(find.text(S.tr(Lang.bn, 'live_next')), findsNothing);

    container.dispose();
    await db.close();
  });
}
