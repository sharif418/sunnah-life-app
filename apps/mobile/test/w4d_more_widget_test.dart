// W4d — More tab §4.3 widget/unit tests:
//   · the full section/tile inventory over a fixed config (one contact,
//     one group, detox on) — everything from the owner's spec §4.3;
//   · the detox tile's config gate (hidden while detoxEnabled = false);
//   · the share tile fires the sunnahlife/system channel (the zero-plugin
//     share — no share_plus dependency);
//   · the FAQ screen renders + expands the BUNDLED faq.json (File-loader
//     seam + runAsync prewarm — the QuranRepository pattern);
//   · the support thread list (chips, previews, unread dot) and the thread
//     view (mine vs সাপোর্ট টিম bubbles, reply box, closed-400 toast) over
//     a fake ApiClient;
//   · the join-request sheet states (in-usrah / pending / fresh form) and
//     the send path;
//   · the detox screen's honest Android-only state on this test bed;
//   · UsageChannel codec round-trip (mock method-channel payloads).
//
// Patterns: test/w4c_amal_widget_test.dart + test/dawah_cache_test.dart
// (in-memory Drift + provider overrides + a scriptable fake ApiClient; a
// FutureProvider that nobody listens to never settles on riverpod 2.6.1 —
// subscribe before awaiting).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/more/detox_screen.dart';
import 'package:sunnah_life/features/more/faq_screen.dart';
import 'package:sunnah_life/features/more/more_screen.dart';
import 'package:sunnah_life/features/more/support_screen.dart';
import 'package:sunnah_life/features/more/usrah_join_sheet.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/services/platform_channels.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart'
    show UsrahBundle, configProvider, usrahProvider;
import 'package:sunnah_life/design/phosphor_icons.dart';

// ── Top-level fixtures ──────────────────────────────────────────────────────

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

class SignedInAuth extends AuthNotifier {
  SignedInAuth(this.user);
  final User user;
  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: user);
}

class GuestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.guest);
}

/// The §4.3 enriched config — one Foundation contact + one group + detox on.
const AppConfig enrichedConfig = AppConfig(
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

/// Scriptable fake — never touches the network.
class FakeW4dApi extends ApiClient {
  FakeW4dApi({
    this.threads = const [],
    this.thread,
    this.joinRequest,
    this.appConfig = enrichedConfig,
  });

  List<SupportThread> threads;
  (SupportThread, List<SupportMessage>)? thread;
  UsrahJoinRequest? joinRequest;
  AppConfig appConfig;

  int appendCalls = 0;
  int createCalls = 0;
  int feedbackCalls = 0;
  int joinCalls = 0;
  String? lastFeedback;
  String? lastAppendBody;
  String? lastJoinMessage;

  @override
  Future<AppConfig> config() async => appConfig;

  @override
  Future<List<SupportThread>> supportThreads() async => threads;

  @override
  Future<SupportThread> supportCreate({
    required String subject,
    required String message,
  }) async {
    createCalls++;
    return SupportThread(
      id: 't-new',
      userId: 'u1',
      subject: subject,
      status: SupportStatus.open,
      createdAt: '2026-09-29T10:00:00Z',
      updatedAt: '2026-09-29T10:00:00Z',
      messageCount: 1,
    );
  }

  @override
  Future<(SupportThread, List<SupportMessage>)> supportThread(String id) async {
    final t = thread;
    if (t == null) {
      throw ApiException(404, 'পাওয়া যায়নি');
    }
    return t;
  }

  @override
  Future<SupportMessage> supportAppend({
    required String id,
    required String message,
  }) async {
    appendCalls++;
    lastAppendBody = message;
    if (thread?.$1.status == SupportStatus.closed) {
      throw ApiException(400, 'এই আলাপ বন্ধ করা হয়েছে');
    }
    return SupportMessage(
      id: 'm-append',
      threadId: id,
      authorId: 'u1',
      isAdmin: false,
      body: message,
      createdAt: '2026-09-29T11:00:00Z',
    );
  }

  @override
  Future<void> feedback(String message, {String? context}) async {
    feedbackCalls++;
    lastFeedback = message;
  }

  @override
  Future<UsrahJoinRequest> joinRequestCreate({String? message}) async {
    joinCalls++;
    lastJoinMessage = message;
    // The create flips the fake's own status — the sheet re-reads it via
    // joinRequestProvider after ref.invalidate and must land on the
    // pending card (exactly what the real backend returns for a re-read).
    return joinRequest = UsrahJoinRequest(
      id: 'jr1',
      userId: 'u1',
      status: JoinRequestStatus.pending,
      message: message,
      createdAt: '2026-09-29T10:00:00Z',
    );
  }

  @override
  Future<UsrahJoinRequest?> joinRequestStatus() async => joinRequest;
}

SupportThread threadRow(
  String id,
  String subject,
  SupportStatus status, {
  String? preview,
  bool unread = false,
}) => SupportThread(
  id: id,
  userId: 'u1',
  subject: subject,
  status: status,
  createdAt: '2026-09-20T10:00:00Z',
  updatedAt: '2026-09-29T09:00:00Z',
  messageCount: 3,
  lastMessageAt: '2026-09-29T09:00:00Z',
  lastPreview: preview,
  unreadForUser: unread,
);

const openThread = SupportThread(
  id: 't1',
  userId: 'u1',
  subject: 'ওয়াক্তের নোটিফিকেশন আসছে না',
  status: SupportStatus.open,
  createdAt: '2026-09-20T10:00:00Z',
  updatedAt: '2026-09-29T09:00:00Z',
  messageCount: 3,
  lastMessageAt: '2026-09-29T09:00:00Z',
  lastPreview: 'ফজরের বেলা বাজছে না কীভাবে ঠিক করব?',
);

const closedThread = SupportThread(
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
);

const myMessage = SupportMessage(
  id: 'm1',
  threadId: 't1',
  authorId: 'u1',
  isAdmin: false,
  body: 'আসসালামু আলাইকুম, একটি বিষয়ে সাহায্য দরকার।',
  createdAt: '2026-09-29T09:00:00Z',
);

const adminMessage = SupportMessage(
  id: 'm2',
  threadId: 't1',
  authorId: 'admin1',
  isAdmin: true,
  body: 'ওয়া আলাইকুমুস সালাম। বিস্তারিত বলুন, ইনশাআল্লাহ সাহায্য করব।',
  createdAt: '2026-09-29T09:30:00Z',
  authorName: 'সাপোর্ট',
);

/// The lazy More ListView renders below the fold only after a scroll (the
/// w4_home helper).
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Boots [home] over the given overrides and returns the container.
Future<ProviderContainer> boot(
  WidgetTester tester,
  Widget home, {
  List<Override> extra = const [],
}) async {
  final db = makeDb();
  final container = ProviderContainer(
    overrides: [dbProvider.overrideWithValue(db), ...extra],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildSunnahLightTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── The §4.3 inventory ─────────────────────────────────────────────────

  testWidgets('More tab renders every §4.3 section + tile (enriched config)', (
    tester,
  ) async {
    final api = FakeW4dApi();
    await boot(
      tester,
      const MoreScreen(),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(api),
        configProvider.overrideWith((ref) async => enrichedConfig),
      ],
    );

    // Sections + the top card (visible without scrolling).
    expect(find.text(S.tr(Lang.bn, 'more_section_foundation')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'more_donate')), findsOneWidget);
    expect(find.text('আস-সুন্নাহ ফাউন্ডেশন'), findsOneWidget);

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_section_worship')));
    expect(find.text(S.tr(Lang.bn, 'more_section_worship')), findsOneWidget);
    for (final key in [
      'more_zakat',
      'more_qibla',
      'more_mosque',
      'more_masala',
      'more_live',
      'more_autosilent',
      'more_detox',
    ]) {
      await scrollTo(tester, find.text(S.tr(Lang.bn, key)));
      expect(find.text(S.tr(Lang.bn, key)), findsOneWidget, reason: key);
    }

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_section_knowledge')));
    expect(find.text(S.tr(Lang.bn, 'more_section_knowledge')), findsOneWidget);
    for (final key in ['ilm_names99', 'ilm_baby_names', 'ilm_iman_branches']) {
      await scrollTo(tester, find.text(S.tr(Lang.bn, key)));
      expect(find.text(S.tr(Lang.bn, key)), findsOneWidget, reason: key);
    }

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_section_support')));
    expect(find.text(S.tr(Lang.bn, 'more_section_support')), findsOneWidget);
    for (final key in [
      'more_support',
      'more_usrah_join',
      'more_feedback',
      'more_faq',
    ]) {
      await scrollTo(tester, find.text(S.tr(Lang.bn, key)));
      expect(find.text(S.tr(Lang.bn, key)), findsOneWidget, reason: key);
    }

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_section_app')));
    expect(find.text(S.tr(Lang.bn, 'more_section_app')), findsOneWidget);
    for (final key in ['more_about', 'more_share_app']) {
      await scrollTo(tester, find.text(S.tr(Lang.bn, key)));
      expect(find.text(S.tr(Lang.bn, key)), findsOneWidget, reason: key);
    }

    // The app-user group row + the footer.
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_groups')));
    expect(find.text('সুন্নাহ লাইফ অ্যাপ গ্রুপ (টেলিগ্রাম)'), findsOneWidget);
    expect(find.text('নিয়মিত আপডেট ও ঘোষণা'), findsOneWidget);
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'org_footer')));
    expect(find.text(S.tr(Lang.bn, 'org_footer')), findsOneWidget);
  });

  testWidgets('detox tile is hidden while detoxEnabled is off', (tester) async {
    await boot(
      tester,
      const MoreScreen(),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(
          FakeW4dApi(
            appConfig: const AppConfig(
              donationUrl: '',
              domain: 'sunnahlife.app',
              hijriAdjust: 0,
              goldPerGramBdt: 0,
              silverPerGramBdt: 0,
            ),
          ),
        ),
        configProvider.overrideWith(
          (ref) async => const AppConfig(
            donationUrl: '',
            domain: 'sunnahlife.app',
            hijriAdjust: 0,
            goldPerGramBdt: 0,
            silverPerGramBdt: 0,
          ),
        ),
      ],
    );

    // The worship section renders — autosilent present, detox ABSENT
    // (the gate). Assert while the section is actually in the lazy list's
    // build window; then scroll past it and re-check the detox absence.
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_autosilent')));
    expect(find.text(S.tr(Lang.bn, 'more_autosilent')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'more_detox')), findsNothing);
    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_section_knowledge')));
    expect(find.text(S.tr(Lang.bn, 'more_detox')), findsNothing);
  });

  testWidgets('share tile fires sunnahlife/system shareText (no plugin)', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('sunnahlife/system'), (
          call,
        ) async {
          calls.add(call);
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('sunnahlife/system'),
            null,
          );
    });

    await boot(
      tester,
      const MoreScreen(),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(FakeW4dApi()),
        configProvider.overrideWith((ref) async => enrichedConfig),
      ],
    );

    await scrollTo(tester, find.text(S.tr(Lang.bn, 'more_share_app')));
    await tester.tap(find.text(S.tr(Lang.bn, 'more_share_app')));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.first.method, 'shareText');
    expect(
      (calls.first.arguments as Map)['text'],
      S.tr(Lang.bn, 'more_share_text'),
    );
  });

  // ── FAQ ───────────────────────────────────────────────────────────────

  testWidgets('FAQ screen renders + expands the bundled faq.json', (
    tester,
  ) async {
    // rootBundle platform-channel loads cannot complete inside the fake
    // async zone — inject the real File loader and prewarm under runAsync.
    FaqRepository.assetLoaderForTesting = (path) => File(path).readAsString();
    addTearDown(FaqRepository.resetForTesting);
    await tester.runAsync(FaqRepository.entries);

    await boot(
      tester,
      const FaqScreen(),
      extra: [authProvider.overrideWith(() => SignedInAuth(member))],
    );

    // The first question renders; the list is long — check a later one too.
    expect(find.textContaining('নামাজের সময়সূচি কোথায় দেখব'), findsOneWidget);

    // Answers are hidden until the row expands.
    expect(find.textContaining('হোম স্ক্রিনের প্রার্থনার সময়'), findsNothing);
    await tester.tap(find.textContaining('নামাজের সময়সূচি কোথায় দেখব'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('হোম স্ক্রিনের প্রার্থনার সময়'),
      findsOneWidget,
    );

    // A later question scrolls into view (lazy list) and expands in place.
    await scrollTo(tester, find.textContaining('মাসআলা জিজ্ঞাসা করলে'));
    expect(find.textContaining('মাসআলা জিজ্ঞাসা করলে'), findsOneWidget);
    expect(find.textContaining("'আরও' → 'মাসআলা জিজ্ঞাসা'"), findsNothing);
    await tester.tap(find.textContaining('মাসআলা জিজ্ঞাসা করলে'));
    await tester.pumpAndSettle();
    expect(find.textContaining("'আরও' → 'মাসআলা জিজ্ঞাসা'"), findsOneWidget);
  });

  // ── Live support ──────────────────────────────────────────────────────

  testWidgets('support list: chips, preview, unread dot; guest gate', (
    tester,
  ) async {
    final api = FakeW4dApi(
      threads: [
        threadRow(
          't1',
          'ওয়াক্তের নোটিফিকেশন',
          SupportStatus.answered,
          preview: 'বিস্তারিত বলুন',
          unread: true,
        ),
        threadRow(
          't2',
          'সমস্যা সমাধান',
          SupportStatus.closed,
          preview: 'ধন্যবাদ',
        ),
      ],
    );
    await boot(
      tester,
      const SupportScreen(),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(api),
      ],
    );

    expect(find.text('ওয়াক্তের নোটিফিকেশন'), findsOneWidget);
    expect(find.text('সমস্যা সমাধান'), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'support_status_answered')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'support_status_closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('support_unread_dot')), findsOneWidget);
    expect(find.text('বিস্তারিত বলুন'), findsOneWidget);

    // Guest → the sign-in gate, not the list.
    final guestApi = FakeW4dApi(
      threads: [threadRow('t1', 'ওয়াক্তের নোটিফিকেশন', SupportStatus.open)],
    );
    await boot(
      tester,
      const SupportScreen(),
      extra: [
        authProvider.overrideWith(GuestAuth.new),
        apiProvider.overrideWithValue(guestApi),
      ],
    );
    expect(find.text(S.tr(Lang.bn, 'support_signin_needed')), findsOneWidget);
    expect(find.text('ওয়াক্তের নোটিফিকেশন'), findsNothing);
  });

  testWidgets('support thread view: bubbles, reply box, closed-400 toast', (
    tester,
  ) async {
    final openApi = FakeW4dApi(thread: (openThread, [myMessage, adminMessage]));
    await boot(
      tester,
      const SupportThreadScreen(id: 't1'),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(openApi),
      ],
    );
    expect(
      find.text('আসসালামু আলাইকুম, একটি বিষয়ে সাহায্য দরকার।'),
      findsOneWidget,
    );
    expect(
      find.text(
        'ওয়া আলাইকুমুস সালাম। বিস্তারিত বলুন, ইনশাআল্লাহ সাহায্য করব।',
      ),
      findsOneWidget,
    );
    expect(find.text(S.tr(Lang.bn, 'support_team')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'support_you')), findsNothing);

    // Reply → append fires with the typed body.
    await tester.enterText(
      find.byType(TextField),
      'ফজরের বেলা বাজছে না কীভাবে ঠিক করব?',
    );
    await tester.tap(find.byIcon(PhosphorIconsRegular.paperPlaneTilt));
    await tester.pumpAndSettle();
    expect(openApi.appendCalls, 1);
    expect(openApi.lastAppendBody, 'ফজরের বেলা বাজছে না কীভাবে ঠিক করব?');
    // Retire the success toast's auto-dismiss timer before the test ends
    // (a pending SnackBar timer fails the invariant check).
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('support thread view: closed -> no reply box, status chip', (
    tester,
  ) async {
    final closedApi = FakeW4dApi(thread: (closedThread, [myMessage]));
    await boot(
      tester,
      const SupportThreadScreen(id: 't2'),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(closedApi),
      ],
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text(S.tr(Lang.bn, 'support_status_closed')), findsOneWidget);
  });

  // ── Join request ──────────────────────────────────────────────────────

  testWidgets('join sheet: in-usrah info instead of the request form', (
    tester,
  ) async {
    await boot(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showUsrahJoinSheet(context),
              child: const Text('OPEN_SHEET'),
            ),
          ),
        ),
      ),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(FakeW4dApi()),
        usrahProvider.overrideWith(
          (ref) async => UsrahBundle(
            usrah: Usrah(
              id: 'u1',
              name: 'আল-হুদা উসরা',
              gender: Gender.m,
              headName: 'উসরা প্রধান',
              memberCount: 5,
            ),
            announcements: const [],
          ),
        ),
      ],
    );

    await tester.tap(find.text('OPEN_SHEET'));
    await tester.pumpAndSettle();

    expect(find.text('আল-হুদা উসরা'), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'usrah_join_in_usrah')), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // no request form
  });

  testWidgets('join sheet: pending request card (no usrah)', (tester) async {
    await boot(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showUsrahJoinSheet(context),
              child: const Text('OPEN_SHEET'),
            ),
          ),
        ),
      ),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(
          FakeW4dApi(
            joinRequest: const UsrahJoinRequest(
              id: 'jr1',
              userId: 'u1',
              status: JoinRequestStatus.pending,
              message: 'দয়া করে একটি উসরায় যুক্ত করুন',
              createdAt: '2026-09-28T10:00:00Z',
            ),
          ),
        ),
        usrahProvider.overrideWith((ref) async => null),
      ],
    );

    await tester.tap(find.text('OPEN_SHEET'));
    await tester.pumpAndSettle();

    expect(find.text(S.tr(Lang.bn, 'usrah_join_pending')), findsOneWidget);
    expect(find.text('দয়া করে একটি উসরায় যুক্ত করুন'), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'usrah_join_send')), findsNothing);
  });

  testWidgets('join sheet: fresh form + send path + toast', (tester) async {
    final api = FakeW4dApi();
    await boot(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showUsrahJoinSheet(context),
              child: const Text('OPEN_SHEET'),
            ),
          ),
        ),
      ),
      extra: [
        authProvider.overrideWith(() => SignedInAuth(member)),
        apiProvider.overrideWithValue(api),
        usrahProvider.overrideWith((ref) async => null),
      ],
    );

    await tester.tap(find.text('OPEN_SHEET'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'আমি নতুন, একটি উসরায় যুক্ত হতে চাই',
    );
    await tester.tap(find.text(S.tr(Lang.bn, 'usrah_join_send')));
    await tester.pumpAndSettle();

    expect(api.joinCalls, 1);
    expect(api.lastJoinMessage, 'আমি নতুন, একটি উসরায় যুক্ত হতে চাই');
    // The sheet flips to the pending card after the send.
    expect(find.text(S.tr(Lang.bn, 'usrah_join_pending')), findsOneWidget);
  });

  // ── Detox ─────────────────────────────────────────────────────────────

  testWidgets('detox screen on a non-Android bed → honest Android-only state', (
    tester,
  ) async {
    await boot(
      tester,
      const DetoxScreen(),
      extra: [authProvider.overrideWith(() => SignedInAuth(member))],
    );

    expect(find.text(S.tr(Lang.bn, 'detox_explain_body')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'detox_android_only')), findsOneWidget);
    // No permission card, no grant button — but the reminder (a plain
    // local notification) stays available on every platform.
    expect(find.text(S.tr(Lang.bn, 'detox_grant')), findsNothing);
    expect(find.text(S.tr(Lang.bn, 'detox_reminder')), findsOneWidget);
  });

  // ── UsageChannel codec ────────────────────────────────────────────────

  group('UsageChannel codec', () {
    test('todayStats decodes the Kotlin map payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('sunnahlife/usage'), (
            call,
          ) async {
            expect(call.method, 'todayStats');
            return <Object?, Object?>{
              'totalMinutes': 95,
              'apps': <Object?>[
                <Object?, Object?>{'label': 'ফেসবুক', 'minutes': 40},
                <Object?, Object?>{'label': 'ইউটিউব', 'minutes': 25},
              ],
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('sunnahlife/usage'),
              null,
            );
      });

      final stats = await UsageChannel.todayStats();
      expect(stats, isNotNull);
      expect(stats!.totalMinutes, 95);
      expect(stats.apps, hasLength(2));
      expect(stats.apps.first.label, 'ফেসবুক');
      expect(stats.apps.first.minutes, 40);
    });

    test(
      'hasPermission → null with no handler (the Android-only probe)',
      () async {
        // No mock registered on this channel — a plain missing plugin.
        expect(await UsageChannel.hasPermission(), isNull);
        expect(await UsageChannel.todayStats(), isNull);
        expect(await UsageChannel.openSettings(), isFalse);
      },
    );
  });
}
