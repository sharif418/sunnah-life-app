// C-W4c mobile widget/unit tests — the goals lifecycle UI (propose →
// status chips; head queue approve/reject), the local per-day checklist,
// the tilawat beginner ramp card, the leaderboard percentile band card and
// the fard/salah-sunnah/nafl group headers over the REAL catalog file.
//
// Pattern: in-memory Drift + provider overrides (today_diary_widget_test,
// w4_home_widget_test); the remote calls go through a fake ApiClient that
// never touches the network.
//
// Repair note (C-W4c-UI-TAIL): the W4c-UI agent died leaving this file
// non-compiling — the helper classes were declared INSIDE main()/test
// bodies (Dart has no local classes), `toBnString` didn't exist (→ toBn),
// `find.ancestorOf` isn't an API (→ find.ancestor), the usrah fake's record
// literal didn't infer, and goalQueueProvider's import was missing. All
// helpers are now top-level and the file compiles and runs.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/api/fallback_catalog.dart' show fallbackDefinitions;
import 'package:sunnah_life/core/amal_engine.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/core/date_keys.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/amal_widgets.dart';
import 'package:sunnah_life/features/amal/goals_screen.dart'
    show GoalStatusChip, GoalsScreen;
import 'package:sunnah_life/features/amal/today_screen.dart';
import 'package:sunnah_life/features/dawah/dawah_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/amal_state.dart';
import 'package:sunnah_life/state/goals_state.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart';
import 'package:sunnah_life/state/prayer_state.dart';

import 'golden_fixtures.dart';

// ── Top-level test fixtures (hoisted out of main) ────────────────────────────

AppDatabase makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

const member = User(
  id: 'u1',
  name: 'টেস্ট সদস্য',
  gender: Gender.m,
  role: Role.user,
  category: UserCategory.general,
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

const head = User(
  id: 'h1',
  name: 'উসরা প্রধান',
  gender: Gender.m,
  role: Role.usrahHead,
  category: UserCategory.general,
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

/// A da'ee — sees the Dawah tabs but is NOT a supervisor: the boundary
/// case for the head-only goal-approval queue.
const daee = User(
  id: 'd1',
  name: 'দাঈ সদস্য',
  gender: Gender.m,
  role: Role.daee,
  category: UserCategory.general,
  createdAt: '2025-01-01T00:00:00Z',
  lastActiveAt: '2025-01-01T00:00:00Z',
);

class SignedInAuth extends AuthNotifier {
  SignedInAuth(this.user);
  final User user;
  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: user);
}

/// Fake API — scriptable goals/queue/leaderboard; never touches the
/// network (the sync_pull_test _FakeApi pattern).
class FakeGoalsApi extends ApiClient {
  FakeGoalsApi({this.goals = const [], this.queue = const []});

  List<PersonalGoal> goals;
  List<GoalQueueItem> queue;

  int proposeCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  String? lastRejectReason;
  String? proposedAmalKey;
  String? proposedTitle;
  String? proposedStartDate;

  @override
  Future<List<AmalDefinition>> amalDefinitions() async => fallbackDefinitions();

  @override
  Future<List<PersonalGoal>> fetchGoals() async => goals;

  @override
  Future<PersonalGoal> proposeGoal({
    required String amalKey,
    required String title,
    required String startDate,
    String? note,
    String? target,
  }) async {
    proposeCalls++;
    proposedAmalKey = amalKey;
    proposedTitle = title;
    proposedStartDate = startDate;
    final goal = PersonalGoal(
      id: 'g-$proposeCalls',
      userId: 'u1',
      amalKey: amalKey,
      title: title,
      note: note,
      target: target,
      startDate: startDate,
      active: true,
      status: GoalStatus.proposed,
      createdAt: '2025-06-01T00:00:00Z',
    );
    goals = [goal, ...goals];
    return goal;
  }

  @override
  Future<void> deleteGoal(String id) async {
    goals = goals.where((g) => g.id != id).toList();
  }

  @override
  Future<List<GoalQueueItem>> usrahGoals() async => queue;

  @override
  Future<PersonalGoal> approveGoal(String id) async {
    approveCalls++;
    final item = queue.firstWhere((q) => q.goal.id == id);
    queue = queue.where((q) => q.goal.id != id).toList();
    return item.goal.copyWith(status: GoalStatus.approved);
  }

  @override
  Future<PersonalGoal> rejectGoal(String id, {String? reason}) async {
    rejectCalls++;
    lastRejectReason = reason;
    final item = queue.firstWhere((q) => q.goal.id == id);
    queue = queue.where((q) => q.goal.id != id).toList();
    return item.goal.copyWith(status: GoalStatus.rejected, reason: reason);
  }

  @override
  Future<ApiCached<(Usrah?, List<Announcement>)>> usrah({
    String? scope,
  }) async =>
      ApiCached((null, const <Announcement>[]), fetchedAt: DateTime(2026));
}

/// Flag-on config (the leaderboard gating tests build their own variants).
class OkApi extends FakeGoalsApi {
  @override
  Future<LeaderboardMe> leaderboardMe() async => LeaderboardMe.fromJson(const {
    'band': 'top10',
    'myPoints': 25,
    'windowDays': 30,
  });
}

class ThrowingApi extends FakeGoalsApi {
  @override
  Future<LeaderboardMe> leaderboardMe() async =>
      throw ApiException(404, 'লিডারবোর্ড সাময়িকভাবে বন্ধ');
}

GoalQueueItem queueItem(String id, {String title = 'তাহাজ্জুদ নিয়মিত করা'}) =>
    GoalQueueItem(
      goal: PersonalGoal(
        id: id,
        userId: 'u1',
        amalKey: 'tahajjud',
        title: title,
        note: null,
        target: null,
        startDate: '2025-06-01',
        active: true,
        status: GoalStatus.proposed,
        decidedById: null,
        decidedAt: null,
        reason: null,
        createdAt: '2025-06-01T00:00:00Z',
      ),
      userName: 'করিম',
    );

/// Deterministic remote surface: in-memory db + empty packs + a static
/// config (no /api/config network attempt) + optional extras.
List<Override> quietRemote(AppDatabase db, {List<Override> extra = const []}) =>
    [
      dbProvider.overrideWithValue(db),
      prayerProvider.overrideWith(GoldenPinnedPrayer.new),
      coursePackProvider.overrideWith((ref) async => <CourseSummary>[]),
      quizPackProvider.overrideWith((ref) async => <Quiz>[]),
      liveProvider.overrideWith((ref) async => <LiveProgramItem>[]),
      configProvider.overrideWith(
        (ref) async => const AppConfig(
          donationUrl: '',
          domain: 'sunnahlife.app',
          hijriAdjust: 0,
          goldPerGramBdt: 0,
          silverPerGramBdt: 0,
        ),
      ),
      ...extra,
    ];

/// The today ListView is lazy-rendered wide — everything below the fold
/// needs a scroll (the w4_home_widget_test helper).
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// The ramp chip's label — the `tilawat_ramp_chip` key sits on the pill
/// CONTAINER, the Text is its descendant (the committed card's shape).
String rampChipText(WidgetTester tester) => (tester.widget(
  find
      .descendant(
        of: find.byKey(const ValueKey('tilawat_ramp_chip')),
        matching: find.byType(Text),
      )
      .first,
) as Text).data!;

/// The committed catalog file (assets/content/amal-catalog.json) parsed
/// into definitions — the catalog-driven rendering proof.
List<AmalDefinition> catalogDefs() {
  final raw = jsonDecode(
    File('assets/content/amal-catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final e in (raw['definitions'] as List).whereType<Map>())
      () {
        final m = Map<String, dynamic>.from(e);
        final tj = m['targetJson'] as String?;
        if (tj != null && tj.isNotEmpty) {
          m['target'] = jsonDecode(tj);
        }
        return AmalDefinition.fromJson(m);
      }(),
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// Serves a fixed definition list (no API, no bundled fallback).
class StaticDefs extends AmalDefinitionsNotifier {
  StaticDefs(this.defs);
  final List<AmalDefinition> defs;
  @override
  Future<List<AmalDefinition>> build() async => defs;
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── Units ───────────────────────────────────────────────────────────────────

  group('units', () {
    test('GoalStatus round-trip + terminal flags', () {
      for (final s in GoalStatus.values) {
        expect(GoalStatusJson.fromJson(s.json), s);
      }
      expect(GoalStatus.proposed.isTerminal, isFalse);
      expect(GoalStatus.approved.isTerminal, isFalse);
      expect(GoalStatus.rejected.isTerminal, isTrue);
      expect(GoalStatus.completed.isTerminal, isTrue);
      expect(GoalStatus.withdrawn.isTerminal, isTrue);
      // Unknown wire values degrade to proposed, never crash.
      expect(GoalStatusJson.fromJson('weird'), GoalStatus.proposed);
    });

    test('LeaderboardMe.fromJson — the /api/leaderboard/me shape verbatim', () {
      final me = LeaderboardMe.fromJson({
        'band': 'top25',
        'myPoints': 25,
        'windowDays': 30,
      });
      expect(me.band, LeaderboardBand.top25);
      expect(me.myPoints, 25);
      expect(me.windowDays, 30);
      expect(me.myPointsDisplay, 25);
      // Fractional points keep one decimal; whole numbers drop the .0.
      expect(
        LeaderboardMe.fromJson({
          'band': 'bottom',
          'myPoints': 25.5,
          'windowDays': 30,
        }).myPointsDisplay,
        25.5,
      );
      expect(me.toJson()['band'], 'top25');
    });

    test('tilawatMinutesDaysDone — distinct days, positive values only', () {
      AmalEntry e(String date, Object value) => AmalEntry(
        amalKey: kTilawatMinutesKey,
        date: date,
        clientUpdatedAt: '2025-06-01T00:00:00Z',
        value: value,
        source: 'manual',
      );
      expect(
        tilawatMinutesDaysDone([
          e('2025-06-01', 5),
          e('2025-06-01', 10), // same day counts once
          e('2025-06-02', 0.5),
          e('2025-06-03', 0), // zero never counts
          e('2025-06-04', 'not-a-number'), // junk ignored
        ]),
        2,
      );
      // Pages-only history (the tilawat key) does NOT feed the ramp.
      expect(
        tilawatMinutesDaysDone([
          AmalEntry(
            amalKey: 'tilawat',
            date: '2025-06-01',
            clientUpdatedAt: '2025-06-01T00:00:00Z',
            value: 20,
            source: 'manual',
          ),
        ]),
        0,
      );
    });

    test('amalGroupKey — fard / salah-sunnah / nafl + categories', () {
      AmalDefinition d(
        String key,
        AmalInputType type, {
        AmalCategory cat = AmalCategory.salah,
      }) => AmalDefinition(
        key: key,
        titleBn: key,
        titleEn: key,
        category: cat,
        inputType: type,
        cadence: 'daily',
      );

      expect(
        amalGroupKey(d('salat_fajr', AmalInputType.tristate)),
        'group_fard',
      );
      expect(
        amalGroupKey(d('salat_isha', AmalInputType.tristate)),
        'group_fard',
      );
      expect(
        amalGroupKey(d('salat_witr', AmalInputType.boolean)),
        'group_salah_sunnah',
      );
      expect(
        amalGroupKey(d('sunnah_muakkadah_12', AmalInputType.boolean)),
        'group_salah_sunnah',
      );
      expect(amalGroupKey(d('tahajjud', AmalInputType.boolean)), 'group_nafl');
      expect(
        amalGroupKey(d('ishraq_salat', AmalInputType.boolean)),
        'group_nafl',
      );
      expect(
        amalGroupKey(
          d('tilawat', AmalInputType.quantity, cat: AmalCategory.quran),
        ),
        'cat_quran',
      );
      expect(
        amalGroupKey(
          d('akhlaq_truthful', AmalInputType.boolean, cat: AmalCategory.akhlaq),
        ),
        'cat_akhlaq',
      );
    });
  });

  // ── Leaderboard provider gating (config flag / guest / 404) ─────────────────

  group('leaderboardMeProvider gating', () {
    // Riverpod 2.6.1 quirk: a FutureProvider that nobody listens to never
    // flushes its pending build, so a cold `read(provider.future)` hangs
    // forever. The UI always listens (ref.watch in AmalHubScreen) — the
    // tests must too (probe-verified: with a listener the future settles).
    ProviderSubscription<AsyncValue<LeaderboardMe?>> listenTo(
      ProviderContainer container,
    ) => container.listen(leaderboardMeProvider, (_, _) {});

    test('flag off → null even when signed in', () async {
      final db = makeDb();
      final api = FakeGoalsApi();
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(api),
          authProvider.overrideWith(() => SignedInAuth(member)),
          configProvider.overrideWith(
            (ref) async => const AppConfig(
              donationUrl: '',
              domain: 'sunnahlife.app',
              hijriAdjust: 0,
              goldPerGramBdt: 0,
              silverPerGramBdt: 0,
              leaderboardEnabled: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final sub = listenTo(container);
      addTearDown(sub.close);
      expect(await container.read(leaderboardMeProvider.future), isNull);
    });

    test('flag on + guest → null', () async {
      final db = makeDb();
      final api = FakeGoalsApi();
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(api),
          configProvider.overrideWith(
            (ref) async => const AppConfig(
              donationUrl: '',
              domain: 'sunnahlife.app',
              hijriAdjust: 0,
              goldPerGramBdt: 0,
              silverPerGramBdt: 0,
              leaderboardEnabled: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final sub = listenTo(container);
      addTearDown(sub.close);
      expect(await container.read(leaderboardMeProvider.future), isNull);
    });

    test('flag on + signed in → the band payload', () async {
      final db = makeDb();
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(OkApi()),
          authProvider.overrideWith(() => SignedInAuth(member)),
          configProvider.overrideWith(
            (ref) async => const AppConfig(
              donationUrl: '',
              domain: 'sunnahlife.app',
              hijriAdjust: 0,
              goldPerGramBdt: 0,
              silverPerGramBdt: 0,
              leaderboardEnabled: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final sub = listenTo(container);
      addTearDown(sub.close);
      final me = await container.read(leaderboardMeProvider.future);
      expect(me, isNotNull);
      expect(me!.band, LeaderboardBand.top10);
      expect(me.myPoints, 25);
    });

    test(
      'flag on + server 404 (flag off server-side) → null, no throw',
      () async {
        final db = makeDb();
        final container = ProviderContainer(
          overrides: [
            dbProvider.overrideWithValue(db),
            apiProvider.overrideWithValue(ThrowingApi()),
            authProvider.overrideWith(() => SignedInAuth(member)),
            configProvider.overrideWith(
              (ref) async => const AppConfig(
                donationUrl: '',
                domain: 'sunnahlife.app',
                hijriAdjust: 0,
                goldPerGramBdt: 0,
                silverPerGramBdt: 0,
                leaderboardEnabled: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(db.close);
        final sub = listenTo(container);
        addTearDown(sub.close);
        expect(await container.read(leaderboardMeProvider.future), isNull);
      },
    );
  });

  // ── Goals screen: propose → status chips ────────────────────────────────────

  group('GoalsScreen', () {
    testWidgets('guest sees the sign-in gate, never a crash', (tester) async {
      final db = makeDb();
      final container = ProviderContainer(overrides: quietRemote(db));
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GoalsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.tr(Lang.bn, 'goals_signin_needed')), findsOneWidget);
    });

    testWidgets('propose a goal → proposed chip + toast; pre-seeded statuses '
        'render their chips incl. the rejected reason', (tester) async {
      final db = makeDb();
      final api = FakeGoalsApi(
        goals: [
          PersonalGoal(
            id: 'g-approved',
            userId: 'u1',
            amalKey: 'tahajjud',
            title: 'তাহাজ্জুদ নিয়মিত করা',
            startDate: '2025-06-01',
            active: true,
            status: GoalStatus.approved,
            createdAt: '2025-06-01T00:00:00Z',
          ),
          PersonalGoal(
            id: 'g-rejected',
            userId: 'u1',
            amalKey: 'salat_fajr',
            title: 'ফজরে জামাতে যাওয়া',
            startDate: '2025-06-01',
            active: false,
            status: GoalStatus.rejected,
            reason: 'আগে ফজরের জামাতে যাওয়া শুরু করুন',
            createdAt: '2025-06-01T00:00:00Z',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: quietRemote(
          db,
          extra: [
            apiProvider.overrideWithValue(api),
            authProvider.overrideWith(() => SignedInAuth(member)),
          ],
        ),
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GoalsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Pre-seeded statuses render as localized chips.
      expect(
        find.byKey(const ValueKey('goal_status_chip_approved')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goal_status_chip_rejected')),
        findsOneWidget,
      );
      expect(
        find.text(
          '${S.tr(Lang.bn, 'goals_reject_reason_label')}: আগে ফজরের জামাতে যাওয়া শুরু করুন',
        ),
        findsOneWidget,
      );
      expect(find.byType(GoalStatusChip), findsNWidgets(2));

      // Propose: open the sheet, pick an amal, title, submit.
      await tester.tap(find.text(S.tr(Lang.bn, 'goals_new')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.tr(Lang.bn, 'goals_amal_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ফজর নামাজ').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, S.tr(Lang.bn, 'goals_title_label')),
        'ফজর জামাতে পড়া',
      );
      await tester.tap(find.text(S.tr(Lang.bn, 'goals_submit')));
      await tester.pumpAndSettle();

      // The API was called exactly once with the form's values.
      expect(api.proposeCalls, 1);
      expect(api.proposedAmalKey, 'salat_fajr');
      expect(api.proposedTitle, 'ফজর জামাতে পড়া');
      expect(api.proposedStartDate, dateKey(DateTime.now()));

      // The list refreshed: the new goal's chip + toast.
      expect(
        find.byKey(const ValueKey('goal_status_chip_proposed')),
        findsOneWidget,
      );
      expect(find.byType(GoalStatusChip), findsNWidgets(3));
      expect(find.text(S.tr(Lang.bn, 'goals_proposed_toast')), findsOneWidget);
    });
  });

  // ── Head approval queue (দাওয়াত → উসরা tab) ───────────────────────────────

  group('head goal queue', () {
    testWidgets('supervisor sees the queue; approve fires the API + toast; '
        'reject rides the reason sheet', (tester) async {
      final db = makeDb();
      final api2 = FakeGoalsApi(queue: [queueItem('q1')]);
      final container = ProviderContainer(
        overrides: quietRemote(
          db,
          extra: [
            apiProvider.overrideWithValue(api2),
            authProvider.overrideWith(() => SignedInAuth(head)),
            // The overview tab's /api/dawah never fires — offline by
            // design (deterministic test, no network).
            dawahProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DawahScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 2 (উসরা) — the queue section renders for the head.
      await tester.tap(find.text(S.tr(Lang.bn, 'dawah_tab_usrah')).first);
      await tester.pumpAndSettle();

      expect(find.text(S.tr(Lang.bn, 'goals_queue_title')), findsOneWidget);
      expect(find.text('তাহাজ্জুদ নিয়মিত করা'), findsOneWidget);
      expect(
        find.textContaining('${S.tr(Lang.bn, 'goals_member_label')}: করিম'),
        findsOneWidget,
      );

      // Approve → API called, queue empties, toast shown.
      await tester.ensureVisible(find.text(S.tr(Lang.bn, 'goals_approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.tr(Lang.bn, 'goals_approve')));
      await tester.pumpAndSettle();
      expect(api2.approveCalls, 1);
      expect(find.text(S.tr(Lang.bn, 'goals_approved_toast')), findsOneWidget);
      expect(find.text(S.tr(Lang.bn, 'goals_queue_empty')), findsOneWidget);

      // Flush the approve toast's 4s timer so the reject toast isn't
      // queued behind it (ScaffoldMessenger queues snack bars).
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Reject (with a reason) through the bottom sheet.
      api2.queue = [queueItem('q2')];
      container.invalidate(goalQueueProvider);
      await tester.pumpAndSettle();
      expect(find.text('তাহাজ্জুদ নিয়মিত করা'), findsOneWidget);

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, S.tr(Lang.bn, 'goals_reject')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, S.tr(Lang.bn, 'goals_reject')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'আগে ফজরের জামাতে যাওয়া শুরু করুন',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, S.tr(Lang.bn, 'goals_reject')),
      );
      await tester.pumpAndSettle();

      expect(api2.rejectCalls, 1);
      expect(api2.lastRejectReason, 'আগে ফজরের জামাতে যাওয়া শুরু করুন');
      expect(find.text(S.tr(Lang.bn, 'goals_rejected_toast')), findsOneWidget);
      expect(find.text(S.tr(Lang.bn, 'goals_queue_empty')), findsOneWidget);
    });

    testWidgets('a daee (dawah access, non-supervisor) never sees the queue '
        'section', (tester) async {
      final db = makeDb();
      final container = ProviderContainer(
        overrides: quietRemote(
          db,
          extra: [
            apiProvider.overrideWithValue(FakeGoalsApi()),
            authProvider.overrideWith(() => SignedInAuth(daee)),
            dawahProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DawahScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.tr(Lang.bn, 'dawah_tab_usrah')).first);
      await tester.pumpAndSettle();

      expect(find.text(S.tr(Lang.bn, 'goals_queue_title')), findsNothing);
    });
  });

  // ── Custom checklist (local, per-day) ───────────────────────────────────────

  group('custom checklist', () {
    testWidgets('add → tick → persists in Drift; delete on long-press', (
      tester,
    ) async {
      final db = makeDb();
      final container = ProviderContainer(overrides: quietRemote(db));
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

      final today = dateKey(DateTime.now());
      await scrollTo(tester, find.text(S.tr(Lang.bn, 'checklist_title')));

      // Add an item.
      await tester.enterText(
        find.byKey(const ValueKey('checklist_add_field')),
        'সকালে কুরআন পড়া',
      );
      await tester.tap(find.byKey(const ValueKey('checklist_add_button')));
      await tester.pumpAndSettle();

      final rows = await db.checklistFor(today);
      expect(rows, hasLength(1));
      expect(rows.first.title, 'সকালে কুরআন পড়া');
      expect(rows.first.done, isFalse);
      expect(find.text('সকালে কুরআন পড়া'), findsOneWidget);

      // Tick it off — persisted done=true.
      final rowFinder = find.byKey(ValueKey('checklist_item_${rows.first.id}'));
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();
      final ticked = await db.checklistFor(today);
      expect(ticked.first.done, isTrue);

      // A fresh provider scope over the SAME db still sees the row
      // (persistence through the Drift provider pattern).
      final container2 = ProviderContainer(overrides: quietRemote(db));
      addTearDown(container2.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
          child: MaterialApp(
            theme: buildSunnahLightTheme(),
            home: const AmalHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('সকালে কুরআন পড়া'));
      expect(find.text('সকালে কুরআন পড়া'), findsOneWidget);

      // Delete on long-press (confirm dialog).
      await tester.longPress(find.text('সকালে কুরআন পড়া'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.tr(Lang.bn, 'checklist_remove')));
      await tester.pumpAndSettle();
      expect(await db.checklistFor(today), isEmpty);
      expect(find.text('সকালে কুরআন পড়া'), findsNothing);
    });
  });

  // ── Tilawat beginner ramp + group headers over the REAL catalog ─────────────

  group('tilawat beginner ramp + group headers (real catalog)', () {
    testWidgets('fresh user: শুরু card day ১/৭, +৫ মিনিট writes the diary', (
      tester,
    ) async {
      final db = makeDb();
      final container = ProviderContainer(
        overrides: [
          ...quietRemote(db),
          amalDefinitionsProvider.overrideWith(() => StaticDefs(catalogDefs())),
        ],
      );
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

      // Group headers follow the PAPER diary, in its order. The ListView is
      // lazy — the lower groups need a scroll first.
      expect(find.text('সালাত ট্র্যাকার'), findsOneWidget);
      await scrollTo(tester, find.text('সুন্নাহ ও নফল সালাত'));
      expect(find.text('সুন্নাহ ও নফল সালাত'), findsOneWidget);
      await scrollTo(tester, find.text('ইলম বা জ্ঞানার্জন'));
      expect(find.text('ইলম বা জ্ঞানার্জন'), findsOneWidget);

      // The beginner card: শুরু chip + ramp দিন ১/৭ + copy.
      await scrollTo(tester, find.byKey(const ValueKey('tilawat_ramp_chip')));
      expect(find.text(S.tr(Lang.bn, 'tilawat_begin_chip')), findsOneWidget);
      expect(find.text(S.tr(Lang.bn, 'tilawat_begin_copy')), findsOneWidget);
      final ramp = rampChipText(tester);
      expect(
        ramp,
        '${S.tr(Lang.bn, 'tilawat_ramp_day')} '
        '${toBn(1)}/${toBn(7)}',
      );

      // +৫ মিনিট → optimistic diary write (value 5, source manual).
      await tester.tap(find.byKey(const ValueKey('tilawat_begin_add5')));
      await tester.pumpAndSettle();
      final today = dateKey(DateTime.now());
      final entry = container
          .read(amalProvider)
          .entry(today, kTilawatMinutesKey);
      expect(entry, isNotNull);
      expect(entry!.value, 5);
      expect(entry.source, 'manual');
      final persisted = await db.entry(kTilawatMinutesKey, today);
      expect(persisted!.value, 5);

      // exercise_minutes is not on the paper: it lives in the collapsed
      // অতিরিক্ত আমল card and renders as a quantity amal once opened.
      await scrollTo(tester, find.byKey(const ValueKey('diary_extras_toggle')));
      expect(find.text('শরীরচর্চা / হাঁটা (মিনিট)'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('diary_extras_toggle')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('শরীরচর্চা / হাঁটা (মিনিট)'));
      expect(find.text('শরীরচর্চা / হাঁটা (মিনিট)'), findsOneWidget);
    });

    testWidgets('6 days of history → ramp chip দিন ৭/৭', (tester) async {
      final db = makeDb();
      final today = dateKey(DateTime.now());
      for (var i = 1; i <= 6; i++) {
        await db.writeEntry(
          amalKey: kTilawatMinutesKey,
          date: addDays(today, -i),
          value: 10,
          source: 'manual',
          clientUpdatedAt: DateTime.now(),
        );
      }
      final container = ProviderContainer(
        overrides: [
          ...quietRemote(db),
          amalDefinitionsProvider.overrideWith(() => StaticDefs(catalogDefs())),
        ],
      );
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

      await scrollTo(tester, find.byKey(const ValueKey('tilawat_ramp_chip')));
      final ramp = rampChipText(tester);
      expect(
        ramp,
        '${S.tr(Lang.bn, 'tilawat_ramp_day')} '
        '${toBn(7)}/${toBn(7)}',
      );
    });

    testWidgets('7 days of history → plain quantity row, no beginner card', (
      tester,
    ) async {
      final db = makeDb();
      final today = dateKey(DateTime.now());
      for (var i = 1; i <= 7; i++) {
        await db.writeEntry(
          amalKey: kTilawatMinutesKey,
          date: addDays(today, -i),
          value: 10,
          source: 'manual',
          clientUpdatedAt: DateTime.now(),
        );
      }
      final container = ProviderContainer(
        overrides: [
          ...quietRemote(db),
          amalDefinitionsProvider.overrideWith(() => StaticDefs(catalogDefs())),
        ],
      );
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

      await scrollTo(tester, find.text('তিলাওয়াত (মিনিট)'));
      expect(find.byType(TilawatBeginnerCard), findsNothing);
      // The normal quantity control carries the amal instead — V2 group
      // cards put one row per amal (keyed amal_row_<key>) inside ONE card
      // per category, so the control is scoped to the ROW, not the card.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('amal_row_$kTilawatMinutesKey')),
          matching: find.byType(QuantityInput),
        ),
        findsOneWidget,
      );
    });
  });

  // ── Leaderboard band card ───────────────────────────────────────────────────

  group('leaderboard band card', () {
    testWidgets('every band renders its chip + points line', (tester) async {
      for (final band in LeaderboardBand.values) {
        final db = makeDb();
        final container = ProviderContainer(
          overrides: [
            ...quietRemote(db),
            leaderboardMeProvider.overrideWith(
              (ref) async =>
                  LeaderboardMe(band: band, myPoints: 25, windowDays: 30),
            ),
          ],
        );
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
        await scrollTo(
          tester,
          find.byKey(const ValueKey('leaderboard_band_card')),
        );

        expect(
          find.byKey(const ValueKey('leaderboard_band_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('leaderboard_band_chip_${band.json}')),
          findsOneWidget,
        );
        expect(find.text(S.tr(Lang.bn, band.labelKey)), findsOneWidget);
        expect(
          find.text(
            '${S.tr(Lang.bn, 'leaderboard_points')}: ${toBn(25)} · '
            '${toBn(30)} ${S.tr(Lang.bn, 'leaderboard_window_days')}',
          ),
          findsOneWidget,
        );
        container.dispose();
      }
    });

    testWidgets('null (flag off / guest / 404) → card hidden entirely', (
      tester,
    ) async {
      final db = makeDb();
      final container = ProviderContainer(
        overrides: [
          ...quietRemote(db),
          leaderboardMeProvider.overrideWith((ref) async => null),
        ],
      );
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
      // scroll past where the card would sit (the privacy note follows it)
      await scrollTo(
        tester,
        find.textContaining(S.tr(Lang.bn, 'diary_privacy')),
      );

      expect(find.byKey(const ValueKey('leaderboard_band_card')), findsNothing);
      expect(find.text(S.tr(Lang.bn, 'leaderboard_title')), findsNothing);
    });
  });
}
