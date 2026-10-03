// W4f — the 360×640 + 1.3× overflow sweep: the KEY surfaces pumped at the
// smallest supported viewport (physical 360×640 @ DPR 1 — logical 360×640)
// with textScale 1.3 (WCAG 1.4.4) and asserted exception-free after
// settling, scrolling through the lazy lists where the fold matters.
// A RenderFlex overflow / pixel overflow throws in widget tests —
// `tester.takeException() == null` after a real settle IS the proof.
//
// Surfaces: Home, Amal Today, Dawah overview + madu tree, Ilm, More,
// Support list + thread, Detox, FAQ, the W4e referral preview sheet, and
// the W4f kit gallery (/__gallery).
//
// Fixtures are SMALL LOCAL COPIES (the dead-agent rule: never import
// between test files) of the established patterns — _TreeApi/_DaeeAuth
// (w4e_dawah_craft_test), FakeW4dApi/SignedInAuth (w4d_more_widget_test),
// the quietRemote packs (w4_home_widget_test) and the FaqRepository
// runAsync prewarm.
//
// Timer discipline (smoke_test pattern): every container that starts a
// periodic timer (Home's 1s prayer ticker) is disposed INSIDE the test
// body — never via addTearDown — so the binding's pending-timer
// invariant check stays clean.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/catalog/kit_gallery.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/today_screen.dart';
import 'package:sunnah_life/features/dawah/dawah_screen.dart';
import 'package:sunnah_life/features/dawah/referral_card.dart';
import 'package:sunnah_life/features/home/home_screen.dart';
import 'package:sunnah_life/features/ilm/ilm_screen.dart';
import 'package:sunnah_life/features/more/detox_screen.dart';
import 'package:sunnah_life/features/more/faq_screen.dart';
import 'package:sunnah_life/features/more/more_screen.dart';
import 'package:sunnah_life/features/more/support_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart'
    show configProvider, coursePackProvider, liveProvider, quizPackProvider;

/// The pinned app clock — the dawah tree's relative labels never drift.
final DateTime _kNow = DateTime(2026, 9, 29, 12, 0);

// ── Small local fixtures ────────────────────────────────────────────────────

const _member = User(
  id: 'u1',
  name: 'টেস্ট সদস্য',
  gender: Gender.m,
  role: Role.user,
  category: UserCategory.general,
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

class _SignedInAuth extends AuthNotifier {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.signedIn, user: _member);
}

class _DaeeAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u1',
      name: 'রাফিউল ইসলাম',
      gender: Gender.m,
      role: Role.daee,
      category: UserCategory.general,
      memberCode: 'DS-000004',
      level: Level.muhibbusSunnah,
      createdAt: '2025-01-01T00:00:00.000Z',
      lastActiveAt: '2025-01-01T00:00:00.000Z',
    ),
  );
}

/// The §4.3 enriched config — one contact + one group + detox on (w4d).
const _enrichedConfig = AppConfig(
  donationUrl: 'https://as-sunnah.org/donation',
  domain: 'sunnahlife.app',
  hijriAdjust: 0,
  goldPerGramBdt: 16500,
  silverPerGramBdt: 220,
  contacts: [
    ConfigContact(
      org: 'আস-সুন্নাহ ফাউন্ডেশন',
      descBn: 'মূল সংস্থা — দাওয়াত, শিক্ষা ও সমাজকল্যাণমূলক কার্যক্রম।',
      website: 'https://as-sunnah.org',
      phone: '+8801711111111',
      email: 'info@as-sunnah.org',
    ),
  ],
  groups: [
    ConfigGroup(
      titleBn: 'সুন্নাহ লাইফ অ্যাপ গ্রুপ (টেলিগ্রাম)',
      url: 'https://t.me/sunnahlife',
      descBn: 'নিয়মিত আপডেট ও ঘোষণা',
    ),
  ],
  detoxEnabled: true,
);

/// Dawah overview with a depth-1/2/3 tree (the w4e fixture).
class _TreeApi extends ApiClient {
  @override
  Future<AppConfig> config() async => _enrichedConfig;

  @override
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) async =>
      ApiCached(
        DawahOverview(
          memberCode: 'DS-000004',
          referralLink: 'https://sunnahlife.app/join/DS-000004',
          invitedCount: 4,
          downline: const [
            DownlineNode(
              id: 'm1',
              name: 'আব্দুল্লাহ আল মামুন',
              gender: Gender.m,
              level: Level.none,
              memberCode: 'DS-000101',
              depth: 1,
              lastActiveAt: '2026-09-28T10:00:00Z',
            ),
            DownlineNode(
              id: 'm2',
              name: 'সাইফুল ইসলাম',
              gender: Gender.m,
              level: Level.muhibbusSunnah,
              depth: 1,
              lastActiveAt: '2026-09-27T10:00:00Z',
            ),
            DownlineNode(
              id: 'm3',
              name: 'মাহমুদা খাতুন',
              gender: Gender.f,
              level: Level.none,
              depth: 2,
              lastActiveAt: '2026-09-26T10:00:00Z',
            ),
            DownlineNode(
              id: 'm4',
              name: 'তানভীর হাসান',
              gender: Gender.m,
              level: Level.none,
              depth: 3,
              lastActiveAt: '2026-09-25T10:00:00Z',
            ),
          ],
          level: Level.muhibbusSunnah,
          monthsInLevel: 2,
          requirements: const [],
          nextLevel: Level.farzeAin1,
          assessments: const [],
        ),
        fetchedAt: _kNow,
      );

  @override
  Future<ApiCached<(Usrah?, List<Announcement>)>> usrah({
    String? scope,
  }) async => ApiCached((
    Usrah(
      id: 'u1',
      name: 'আল-হুদা উসরা',
      gender: Gender.m,
      headName: 'উসরা প্রধান',
      memberCount: 5,
    ),
    const [],
  ), fetchedAt: _kNow);

  @override
  Future<ApiCached<List<WeeklyReview>>> reviews({String? scope}) async =>
      ApiCached([
        WeeklyReview(
          id: 'r1',
          userId: 'u1',
          reviewerId: 'h1',
          weekStart: '2026-09-21',
          comment: 'আলহামদুলিল্লাহ, এই সপ্তাহে নিয়মিত আমল হয়েছে।',
          rating: 4,
          status: 'done',
          createdAt: '2026-09-25',
          completedAt: '2026-09-25',
          userName: 'রাফিউল ইসলাম',
          reviewerName: 'উসরা প্রধান',
        ),
      ], fetchedAt: _kNow);
}

/// Support list + thread fake (the FakeW4dApi subset).
class _SupportApi extends ApiClient {
  @override
  Future<AppConfig> config() async => _enrichedConfig;

  @override
  Future<List<SupportThread>> supportThreads() async => const [
    SupportThread(
      id: 't1',
      userId: 'u1',
      subject: 'ওয়াক্তের নোটিফিকেশন আসছে না',
      status: SupportStatus.answered,
      createdAt: '2026-09-20T10:00:00Z',
      updatedAt: '2026-09-29T09:00:00Z',
      messageCount: 3,
      lastMessageAt: '2026-09-29T09:00:00Z',
      lastPreview: 'ফজরের বেলা বাজছে না কীভাবে ঠিক করব?',
      unreadForUser: true,
    ),
    SupportThread(
      id: 't2',
      userId: 'u1',
      subject: 'সমস্যা সমাধান',
      status: SupportStatus.closed,
      createdAt: '2026-09-20T10:00:00Z',
      updatedAt: '2026-09-29T09:00:00Z',
      messageCount: 2,
      lastMessageAt: '2026-09-29T09:00:00Z',
      lastPreview: 'ধন্যবাদ, ঠিক হয়েছে।',
      closedAt: '2026-09-29T09:30:00Z',
    ),
  ];

  @override
  Future<(SupportThread, List<SupportMessage>)> supportThread(
    String id,
  ) async => const (
    SupportThread(
      id: 't1',
      userId: 'u1',
      subject: 'ওয়াক্তের নোটিফিকেশন আসছে না',
      status: SupportStatus.answered,
      createdAt: '2026-09-20T10:00:00Z',
      updatedAt: '2026-09-29T09:00:00Z',
      messageCount: 3,
      lastMessageAt: '2026-09-29T09:00:00Z',
    ),
    [
      SupportMessage(
        id: 'm1',
        threadId: 't1',
        authorId: 'u1',
        isAdmin: false,
        body: 'আসসালামু আলাইকুম, একটি বিষয়ে সাহায্য দরকার। ফজরের নোটিফিকেশন আসছে না।',
        createdAt: '2026-09-29T09:00:00Z',
      ),
      SupportMessage(
        id: 'm2',
        threadId: 't1',
        authorId: 'admin1',
        isAdmin: true,
        body: 'ওয়া আলাইকুমুস সালাম। সেটিংসে বেল চালু আছে কি দেখে জানান, ইনশাআল্লাহ সাহায্য করব।',
        createdAt: '2026-09-29T09:30:00Z',
        authorName: 'সাপোর্ট',
      ),
    ],
  );
}

// ── Harness ─────────────────────────────────────────────────────────────────

/// The small-phone profile: 360×640 logical @ DPR 1, text scaled 1.3×.
void smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps [home] over the overrides; returns the LIVE container so the test
/// body can dispose it (and its periodic timers) before it ends.
Future<ProviderContainer> boot(
  WidgetTester tester,
  Widget home, {
  List<Override> extra = const [],
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [dbProvider.overrideWithValue(db), ...extra],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildSunnahLightTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  // Caller OWNS the disposal (in-body) — see the timer note at the top.
  return container;
}

/// The first VERTICAL scrollable in the tree (the dawah screen's
/// Scrollable.first is the TabBarView's horizontal PageView — the w4e
/// lesson).
Finder _verticalScrollable() => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: _verticalScrollable(),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Home — 360×640 @1.3× lays out clean through the fold', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(
      tester,
      const HomeScreen(),
      extra: [
        coursePackProvider.overrideWith((ref) async => <CourseSummary>[]),
        quizPackProvider.overrideWith((ref) async => <Quiz>[]),
        liveProvider.overrideWith((ref) async => <LiveProgramItem>[]),
      ],
    );

    // Scroll the whole page: the illustrated most-used empty state, the
    // quick-access grid, forbidden times and the footer all lay out.
    await scrollTo(
      tester,
      find.text(S.tr(Lang.bn, 'most_used_empty')),
    );
    expect(find.text(S.tr(Lang.bn, 'most_used_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      await tester.drag(_verticalScrollable(), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    container.dispose();
  });

  testWidgets('Amal Today — 360×640 @1.3× lays out clean through the fold', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(tester, const AmalHubScreen());

    expect(find.text('আজকের মুহাসাবা'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 8; i++) {
      await tester.drag(_verticalScrollable(), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    container.dispose();
  });

  testWidgets('Dawah overview + madu tree — 360×640 @1.3× clean', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(
      tester,
      const DawahScreen(),
      extra: [
        authProvider.overrideWith(_DaeeAuth.new),
        apiProvider.overrideWithValue(_TreeApi()),
        headerNowProvider.overrideWithValue(_kNow),
      ],
    );

    // The overview: member code card, requirements, share CTA…
    expect(find.text('DS-000004'), findsWidgets);
    expect(tester.takeException(), isNull);
    // …down to the deep tree node (depth 3 forces every indent level).
    await scrollTo(tester, find.text('তানভীর হাসান'));
    expect(find.text('তানভীর হাসান'), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('Ilm hub — 360×640 @1.3× lays out the whole grid', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(tester, const IlmScreen());

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'ilm_articles')));
    expect(find.text(S.tr(Lang.bn, 'ilm_articles')), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('More (§4.3 enriched) — 360×640 @1.3× through the footer', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(
      tester,
      const MoreScreen(),
      extra: [
        authProvider.overrideWith(_SignedInAuth.new),
        apiProvider.overrideWithValue(_TreeApi()),
        configProvider.overrideWith((ref) async => _enrichedConfig),
      ],
    );

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'org_footer')));
    expect(find.text(S.tr(Lang.bn, 'org_footer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('Support list + thread — 360×640 @1.3× clean', (tester) async {
    smallPhone(tester);
    var container = await boot(
      tester,
      const SupportScreen(),
      extra: [
        authProvider.overrideWith(_SignedInAuth.new),
        apiProvider.overrideWithValue(_SupportApi()),
      ],
    );

    expect(find.text('ওয়াক্তের নোটিফিকেশন আসছে না'), findsOneWidget);
    expect(find.text('সমস্যা সমাধান'), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();

    // The conversation view (bubbles + the reply box under the keyboard
    // inset math).
    container = await boot(
      tester,
      const SupportThreadScreen(id: 't1'),
      extra: [
        authProvider.overrideWith(_SignedInAuth.new),
        apiProvider.overrideWithValue(_SupportApi()),
      ],
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      await tester.drag(_verticalScrollable(), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    container.dispose();
  });

  testWidgets('Detox — 360×640 @1.3× through the reminder section', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(
      tester,
      const DetoxScreen(),
      extra: [
        authProvider.overrideWith(_SignedInAuth.new),
        configProvider.overrideWith((ref) async => _enrichedConfig),
      ],
    );

    // This test bed is not Android → the honest explainer + reminder.
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'detox_reminder')));
    expect(find.text(S.tr(Lang.bn, 'detox_reminder')), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('FAQ — 360×640 @1.3× through the last question', (tester) async {
    // rootBundle platform-channel loads cannot complete inside fake-async —
    // the real File loader + runAsync prewarm (the w4d pattern).
    FaqRepository.assetLoaderForTesting = (path) => File(path).readAsString();
    addTearDown(FaqRepository.resetForTesting);
    await tester.runAsync(FaqRepository.entries);

    smallPhone(tester);
    final container = await boot(
      tester,
      const FaqScreen(),
      extra: [authProvider.overrideWith(_SignedInAuth.new)],
    );

    await scrollTo(tester, find.textContaining('মাসআলা জিজ্ঞাসা করলে'));
    expect(find.textContaining('মাসআলা জিজ্ঞাসা করলে'), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('Referral preview sheet — 360×640 @1.3× bounded + clean', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(
      tester,
      const DawahScreen(),
      extra: [
        authProvider.overrideWith(_DaeeAuth.new),
        apiProvider.overrideWithValue(_TreeApi()),
        headerNowProvider.overrideWithValue(_kNow),
      ],
    );

    await tester.tap(find.byKey(const Key('dawahShareCardButton')));
    await tester.pumpAndSettle();
    expect(find.byType(ReferralCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Close the sheet — the dismissal animation must also be clean.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ReferralCard), findsNothing);
    expect(tester.takeException(), isNull);
    container.dispose();
  });

  testWidgets('Kit gallery (/__gallery) — 360×640 @1.3× + dark flip clean', (
    tester,
  ) async {
    smallPhone(tester);
    final container = await boot(tester, const KitGalleryScreen());

    // The shared kit renders at the small viewport…
    expect(find.text('Buttons — states'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // …through every section (the leaderboard card, the illustrated
    // states, the texture panels). NB: plain pump, not pumpAndSettle —
    // the Skeleton section runs an infinite shimmer and never settles.
    for (var i = 0; i < 8; i++) {
      await tester.drag(_verticalScrollable(), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    // …and the dark toggle (an AppBar action — always visible) re-themes
    // the whole catalog without overflow.
    await tester.tap(find.byTooltip('Light / Dark'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    container.dispose();
  });
}
