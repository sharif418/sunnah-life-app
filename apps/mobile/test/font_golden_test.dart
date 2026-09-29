// Font-consistency goldens (V1) — the five tab surfaces (Home, Amal Today,
// Dawah, Ilm, More) in bn light, rendered with ONLY the bundled fonts:
// the families are pubspec-declared (engine-registered before the first
// frame) and this test deliberately does NOT warm any google_fonts family,
// so a widget that falls back to the platform font shows tofu in the
// golden AND trips the explicit RenderParagraph family walk below.
//
// Tofu guard, two layers:
//  1. matchesGoldenFile — pixel truth; tofu boxes change pixels → CI fails.
//  2. expectNoPlatformFont — walks every RenderParagraph/EditableText in
//     the tree and requires the resolved family to be one of the app's
//     bundled families. Reports the offending text, so a regression says
//     exactly which widget fell back.
//
// Determinism contract:
//  * headerNowProvider pinned to 2025-06-15 14:30 — the header date bar,
//    the day-of-week amals and the diary keys never flake across days.
//  * prayerProvider overridden with a fixed PrayerNow (no ticker) — the
//    countdown HH:MM:SS is frozen.
//  * Every remote pack (config/dawah/usrah/reviews/live/courses/quizzes)
//    overridden with fixed payloads via a fake ApiClient — no network.
// Regenerate with:
//   flutter test --update-goldens test/font_golden_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/core/prayer_engine.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/prayer_state.dart';
import 'package:sunnah_life/state/providers.dart';

/// The pinned instant (a Sunday — mon/thu fast + kahf stay hidden).
final DateTime _kNow = DateTime(2025, 6, 15, 14, 30);
final String _kToday = dateKey(_kNow);

/// Families that carry real bundled glyphs. Everything else = platform
/// fallback = tofu on a bundle-only device.
const Set<String> _bundledFamilies = {
  'HindSiliguri',
  'Amiri',
  'AmiriQuran',
  'MaterialIcons',
  'PhosphorRegular',
  'PhosphorFill',
  'PhosphorBold',
};

class _PinnedPrayer extends PrayerNotifier {
  @override
  PrayerNow? build() {
    final times = PrayerEngine.compute(
      _kToday,
      lat: 23.8103,
      lng: 90.4125,
      tz: 6,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
    );
    final nowMinutes = 14 * 60.0 + 30;
    final (nextKey, mins) = PrayerEngine.nextPrayer(times, nowMinutes);
    return PrayerNow(
      dateKey: _kToday,
      times: times,
      nowMinutes: nowMinutes,
      currentWaqt: PrayerEngine.currentWaqt(times, nowMinutes),
      nextKey: nextKey,
      minutesToNext: mins,
      forbiddenLabel: PrayerEngine.inForbiddenWindow(times, nowMinutes),
      postPrayerKey: PrayerEngine.activePostPrayerPrompt(times, nowMinutes),
    );
  }
}

class _SignedInDaee extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u-font-daee',
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

/// Deterministic remote payloads — no network, Bengali-rich on purpose
/// (the tofu guard only means anything when Bengali actually renders).
class _GoldenApi extends ApiClient {
  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
  );

  @override
  Future<List<AmalDefinition>> amalDefinitions() async =>
      fallbackDefinitions();

  @override
  Future<DawahOverview> dawahOverview() async => DawahOverview(
    memberCode: 'DS-000004',
    referralLink: 'https://sunnahlife.app/join/DS-000004',
    invitedCount: 3,
    downline: [
      DownlineNode(
        id: 'm1',
        name: 'আব্দুল্লাহ আল মামুন',
        gender: Gender.m,
        level: Level.none,
        depth: 1,
        lastActiveAt: '2025-06-10',
      ),
      DownlineNode(
        id: 'm2',
        name: 'মোঃ সাইফুল ইসলাম',
        gender: Gender.m,
        level: Level.none,
        depth: 1,
        lastActiveAt: '2025-06-12',
      ),
    ],
    level: Level.muhibbusSunnah,
    monthsInLevel: 2,
    requirements: [
      const LevelRequirement(
        key: 'r1',
        label: 'সাপ্তাহিক রিভিউ অংশগ্রহণ',
        done: true,
        detail: 'টানা ৪ সপ্তাহ',
      ),
      const LevelRequirement(
        key: 'r2',
        label: 'প্রতিদিন ১ পৃষ্ঠা কুরআন তিলাওয়াত',
        done: true,
        detail: '৩০ দিনের মধ্যে ২৫ দিন',
      ),
      const LevelRequirement(
        key: 'r3',
        label: '২ জনকে দাওয়াত',
        done: false,
        detail: '১/২ সম্পন্ন',
      ),
    ],
    nextLevel: Level.farzeAin1,
    assessments: const [],
  );

  @override
  Future<(Usrah?, List<Announcement>)> usrah() async => (
    Usrah(
      id: 'u1',
      name: 'আল-হুদা উসরা',
      gender: Gender.m,
      headName: 'উসরা প্রধান',
      memberCount: 5,
      members: [
        UsrahMember(id: 'm1', name: 'রাফিউল ইসলাম', gender: Gender.m),
        UsrahMember(id: 'm2', name: 'আব্দুল্লাহ আল মামুন', gender: Gender.m),
        UsrahMember(id: 'm3', name: 'সাইফুল ইসলাম', gender: Gender.m),
        UsrahMember(id: 'm4', name: 'মাহমুদ হাসান', gender: Gender.m),
      ],
    ),
    [
      const Announcement(
        id: 'a1',
        authorId: 'h1',
        kind: 'announcement',
        body: 'আগামী শুক্রবার বাদ জুমা উসরার সাপ্তাহিক মজলিস অনুষ্ঠিত হবে, ইনশাআল্লাহ।',
        pinned: true,
        createdAt: '2025-06-10',
        authorName: 'উসরা প্রধান',
      ),
    ],
  );

  @override
  Future<List<WeeklyReview>> reviews() async => [
    WeeklyReview(
      id: 'r1',
      userId: 'u-font-daee',
      reviewerId: 'h1',
      weekStart: '2025-06-09',
      comment: 'আলহামদুলিল্লাহ, এই সপ্তাহে নিয়মিত আমল হয়েছে।',
      rating: 4,
      status: 'done',
      createdAt: '2025-06-13',
      completedAt: '2025-06-13',
      userName: 'রাফিউল ইসলাম',
      reviewerName: 'উসরা প্রধান',
    ),
  ];

  @override
  Future<List<LiveProgramItem>> live() async => const [];

  @override
  Future<List<CourseSummary>> courses() async => const [];

  @override
  Future<List<Quiz>> quizPack() async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Layer 2 of the tofu guard — every resolved text family must be a
  /// bundled family (or inherit one).
  void expectNoPlatformFont(WidgetTester tester, String screen) {
    final offenders = <String>[];

    void checkSpan(InlineSpan span, String? inheritedFamily) {
      if (span is! TextSpan) return;
      final family = span.style?.fontFamily ?? inheritedFamily;
      final text = span.toPlainText();
      if (text.trim().isNotEmpty &&
          (family == null || !_bundledFamilies.contains(family))) {
        offenders.add('"$text" → ${family ?? '(null — platform default)'}');
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        checkSpan(child, family);
      }
    }

    for (final element in find.byType(RichText).evaluate()) {
      final paragraph = element.renderObject;
      if (paragraph is RenderParagraph) {
        checkSpan(paragraph.text, null);
      }
    }
    for (final element in find.byType(EditableText).evaluate()) {
      final editable = element.widget as EditableText;
      final family = editable.style.fontFamily;
      final text = editable.controller.text;
      if (text.trim().isNotEmpty &&
          (family == null || !_bundledFamilies.contains(family))) {
        offenders.add('[input] "$text" → ${family ?? '(null)'}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '$screen renders text through a non-bundled font family — on a '
          'bundle-only device that is tofu (□□□). Offenders:\n'
          '${offenders.join('\n')}',
    );
  }

  Future<ProviderContainer> bootAt(
    WidgetTester tester,
    String path, {
    List<Override> extra = const [],
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.guestProfile();
    await db.saveGuestProfile(
      const GuestProfilesCompanion(onboardingDone: Value(true)),
    );

    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(_SignedInDaee.new),
        prayerProvider.overrideWith(_PinnedPrayer.new),
        headerNowProvider.overrideWithValue(_kNow),
        apiProvider.overrideWithValue(_GoldenApi()),
        ...extra,
      ],
    );
    // NB: NOT addTearDown — the container must be disposed INSIDE the test
    // body (smoke_test pattern) so the 60s sync-flush periodic timer is
    // cancelled before the binding checks for pending timers.
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BootstrapGate(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
    return container;
  }

  for (final (screen, path) in [
    ('home', '/'),
    ('amal_today', '/amal'),
    ('dawah', '/dawah'),
    ('ilm', '/ilm'),
    ('more', '/more'),
  ]) {
    testWidgets('$screen — bn light renders only bundled fonts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(824, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = await bootAt(tester, path);

      expectNoPlatformFont(tester, screen);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/fonts_${screen}_bn_light.png'),
      );

      // Inside the body — cancels the periodic sync-flush timer in time.
      container.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
