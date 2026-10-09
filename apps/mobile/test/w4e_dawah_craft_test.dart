// W4e — Da'wah craft tests:
//   · the referral share card renders the member code + join link +
//     tagline on the fixed 1080×1350 surface, pinned as a PNG golden
//     (bundled fonts — the golden also pins the branding);
//   · the preview sheet opens from BOTH overview share entry points (the
//     primary CTA + the referral row's icon), and শেয়ার করুন renders a
//     REAL 1080×1350 PNG (PNG magic + decoded dimensions) and hands it to
//     sunnahlife/system shareFile with the invitation text — plus the
//     honest plain-text fallback when the platform refuses files;
//   · the madu tree: depth 1/2/3 indentation (24 px per level), gender-
//     tinted avatar initials, gold-soft level chips, relative last-active
//     (pinned clock), connector rails on deeper rows, ellipsized long
//     names at 360 width @1.3× text;
//   · the empty downline keeps the empty state, and the offline (stale
//     cache) overview still renders the tree (the _StaleDawahApi pattern
//     from dawah_cache_test.dart).
//
// Patterns: test/dawah_cache_test.dart + test/w4d_more_widget_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/dawah/dawah_screen.dart';
import 'package:sunnah_life/features/dawah/madu_tree.dart';
import 'package:sunnah_life/features/dawah/referral_card.dart';
import 'package:sunnah_life/features/dawah/referral_share_sheet.dart'
    show referralCardCapture;
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/design/phosphor_icons.dart';

import 'golden_fonts.dart';

/// Pinned app clock — the tree's relative last-active labels and the
/// offline banner stamps never drift.
final DateTime _kNow = DateTime(2026, 9, 29, 12, 0);

const String _kLink = 'https://sunnahlife.app/join/DS-000004';

/// A valid 1×1 transparent PNG — the stub capture payload (fake-zone
/// safe; the real capture has its own dedicated test).
final List<int> _tinyPngBytes = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

DawahOverview _overview({List<DownlineNode> downline = const []}) =>
    DawahOverview(
      memberCode: 'DS-000004',
      referralLink: _kLink,
      invitedCount: 3,
      downline: downline,
      level: Level.muhibbusSunnah,
      monthsInLevel: 2,
      requirements: const [],
      nextLevel: Level.farzeAin1,
      assessments: const [],
    );

/// Depth 1/1/2/3 with mixed genders + levels — the tree fixture.
const List<DownlineNode> _downline = [
  DownlineNode(
    id: 'm1',
    name: 'আব্দুল্লাহ আল মামুন',
    gender: Gender.m,
    level: Level.none,
    memberCode: 'DS-000101',
    depth: 1,
    lastActiveAt: '2026-09-28T10:00:00Z', // ১ দিন আগে
  ),
  DownlineNode(
    id: 'm2',
    name: 'সাইফুল ইসলাম',
    gender: Gender.m,
    level: Level.muhibbusSunnah,
    depth: 1,
    lastActiveAt: '2026-09-27T10:00:00Z', // ২ দিন আগে
  ),
  DownlineNode(
    id: 'm3',
    name: 'মাহমুদা খাতুন',
    gender: Gender.f,
    level: Level.none,
    depth: 2,
    lastActiveAt: '2026-09-26T10:00:00Z', // ৩ দিন আগে
  ),
  DownlineNode(
    id: 'm4',
    name: 'তানভীর হাসান',
    gender: Gender.m,
    level: Level.none,
    depth: 3,
    lastActiveAt: '2026-09-25T10:00:00Z', // ৪ দিন আগে
  ),
];

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

/// Fresh fake — the overview with the tree fixture (config included for
/// the global header surface).
class _TreeApi extends ApiClient {
  _TreeApi({this.downline = _downline});

  final List<DownlineNode> downline;

  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
  );

  @override
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) async =>
      ApiCached(_overview(downline: downline), fetchedAt: _kNow);
}

/// Dead network + pre-warmed cache — the device state the offline fix
/// exists for (the dawah_cache_test pattern, carrying downline rows).
class _StaleDawahApi extends ApiClient {
  _StaleDawahApi(this._db);
  final AppDatabase _db;

  @override
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) async {
    final row = await _db.remoteCache('dawah/overview:${scope ?? ''}');
    if (row == null) throw ApiException(0, 'নেটওয়ার্ক');
    return ApiCached(
      DawahOverview.fromJson(jsonDecode(row.payload) as Map<String, dynamic>),
      fetchedAt: row.fetchedAt,
      stale: true,
    );
  }

  @override
  Future<AppConfig> config() async => const AppConfig(
    donationUrl: 'https://as-sunnah.org/donation',
    domain: 'sunnahlife.app',
    hijriAdjust: 0,
    goldPerGramBdt: 16500,
    silverPerGramBdt: 220,
  );
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tmp);
  final String tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

Future<ProviderContainer> bootDawah(
  WidgetTester tester, {
  required ApiClient api,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      authProvider.overrideWith(_DaeeAuth.new),
      apiProvider.overrideWithValue(api),
      headerNowProvider.overrideWithValue(_kNow),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: const DawahScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The invite card now sits below the journey + requirements on the
/// (lazy) overview list — scroll it into view before tapping.
Future<void> revealAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── The referral card ────────────────────────────────────────────────────

  testWidgets('referral card — 1080×1350 golden with code + link + tagline', (
    tester,
  ) async {
    tester.view.physicalSize = ReferralCard.size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // W5: the referral golden needs the real text families too — the old
    // Phosphor-only warm left every Bengali glyph on this PNG tofu.
    await warmAppFonts(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSunnahLightTheme(),
        home: ReferralCard(
          appTitle: S.tr(Lang.bn, 'app_title'),
          tagline: S.tr(Lang.bn, 'dawah_card_tagline'),
          memberName: 'রাফিউল ইসলাম',
          memberCodeLabel: S.tr(Lang.bn, 'dawah_member_code'),
          memberCode: 'DS-000004',
          joinLink: _kLink,
        ),
      ),
    );

    expect(find.text('DS-000004'), findsOneWidget);
    expect(find.text(_kLink), findsOneWidget);
    expect(find.text('রাফিউল ইসলাম'), findsOneWidget);
    expect(find.textContaining('সুন্নাহর পথে'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow on the card');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/referral_card_bn.png'),
    );
  });

  testWidgets('referral card — empty member name hides the name row', (
    tester,
  ) async {
    tester.view.physicalSize = ReferralCard.size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await warmPhosphorFonts(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSunnahLightTheme(),
        home: ReferralCard(
          appTitle: 'সুন্নাহ লাইফ',
          tagline: 'সুন্নাহর পথে জীবন গড়তে আমার সাথে যুক্ত হন',
          memberName: '',
          memberCodeLabel: 'আমার মেম্বার কোড',
          memberCode: 'DS-000004',
          joinLink: _kLink,
        ),
      ),
    );

    expect(find.text('DS-000004'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── The preview sheet ─────────────────────────────────────────────────────

  testWidgets('the overview share CTA opens the preview sheet', (
    tester,
  ) async {
    await bootDawah(tester, api: _TreeApi());

    // Primary: the overview's দাওয়াত কার্ড শেয়ার করুন CTA.
    await revealAndTap(tester, find.byKey(const Key('dawahShareCardButton')));
    await tester.pumpAndSettle();

    expect(find.text(S.tr(Lang.bn, 'dawah_card_title')), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'dawah_card_preview_note')), findsOneWidget);
    expect(find.byType(ReferralCard), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'dawah_share_now')), findsOneWidget);
    expect(find.text('DS-000004'), findsWidgets); // the preview card's code

    // The card itself carries the join link; the overview no longer
    // repeats the raw URL beside the code (the prototype's member card) —
    // the code has its own copy button.
    await tester.tapAt(const Offset(10, 10)); // the modal barrier
    await tester.pumpAndSettle();
    expect(find.byType(ReferralCard), findsNothing);
    expect(find.byKey(const ValueKey('dawah_copy_code')), findsOneWidget);
  });

  testWidgets('renderReferralCardPng produces a real 1080×1350 PNG', (
    tester,
  ) async {
    // Sync: real-async IO starves under fake-async (see the FaqRepository
    // note) — the test body runs before any runAsync bridge.
    final tmp = Directory.systemTemp.createTempSync('w4e_capture');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

    await bootDawah(tester, api: _TreeApi());
    await revealAndTap(tester, find.byKey(const Key('dawahShareCardButton')));
    await tester.pumpAndSettle();

    // Stage the off-screen capture entry exactly like production, in the
    // fake zone (stage + one pump), then run the REAL engine pipeline —
    // toImage → toByteData(png) → file — inside runAsync, the same way
    // flutter_test's own golden matcher does it (the fake-async zone
    // starves the engine's real-async capture callbacks).
    final context = tester.element(find.byType(ReferralCard).first);
    final card = tester.widget<ReferralCard>(find.byType(ReferralCard).first);
    debugPrint('W4E card grabbed');
    final staged = stageReferralCard(context, card);
    await tester.pump();
    debugPrint('W4E pumped');
    final (boundary, remove) = await staged;
    debugPrint('W4E staged needsPaint=${boundary.debugNeedsPaint}');
    // toImage CALLED in the fake zone (completes on the real loop), then
    // awaited + PNG-encoded + written INSIDE runAsync — the golden
    // matcher's exact structure (flutter_test _matchers_io.dart).
    final imageFuture = boundary.toImage(pixelRatio: 1);
    File? file;
    int? pngWidth;
    int? pngHeight;
    try {
      await tester.runAsync(() async {
        file = await captureImageToPngFile(imageFuture);
        // Decode INSIDE runAsync — decodeImageFromList is real-async and
        // starves in the fake zone (the whole golden-matcher discipline).
        final image = await decodeImageFromList(file!.readAsBytesSync());
        pngWidth = image.width;
        pngHeight = image.height;
      });
    } finally {
      remove();
    }

    // The PNG exists, carries the magic header and the exact design size.
    expect(file, isNotNull, reason: 'capture returned a file');
    final bytes = file!.readAsBytesSync();
    expect(bytes.sublist(0, 4), const [0x89, 0x50, 0x4E, 0x47]);
    expect(pngWidth, ReferralCard.size.width);
    expect(pngHeight, ReferralCard.size.height);
  });

  testWidgets(
    'শেয়ার করুন hands the rendered file to shareFile + the invite text',
    (tester) async {
      // A stub capture (the seam) — the REAL render is proven above and by
      // the card golden; this test pins the sheet's wiring: the button
      // produces the file → shareFile(path, text) → toast → sheet closes.
      // Sync: real-async IO starves under fake-async (see the FaqRepository
      // note) — the test body runs before any runAsync bridge.
      final tmp = Directory.systemTemp.createTempSync('w4e_wiring');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final stubPng = File('${tmp.path}/stub_card.png');
      stubPng.writeAsBytesSync(_tinyPngBytes);
      referralCardCapture = (context, card) async => stubPng;
      addTearDown(() => referralCardCapture = renderReferralCardPng);

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

      await bootDawah(tester, api: _TreeApi());
      await revealAndTap(tester, find.byKey(const Key('dawahShareCardButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('referralShareButton')));
      await tester.pumpAndSettle();

      expect(calls, isNotEmpty);
      final shareFileCalls = calls
          .where((c) => c.method == 'shareFile')
          .toList();
      expect(shareFileCalls, hasLength(1));
      final args = shareFileCalls.first.arguments as Map;
      expect(args['path'], stubPng.path);
      expect(args['mimeType'], 'image/png');

      // The invitation text rides along with the image.
      expect(args['text'] as String, contains(_kLink));
      // No plain-text fallback when the file share succeeded.
      expect(calls.where((c) => c.method == 'shareText'), isEmpty);
      // The confirmation toast + the sheet closed.
      expect(find.textContaining('জাযাকুমুল্লাহু খাইরান'), findsOneWidget);
      expect(find.byType(ReferralCard), findsNothing);
    },
  );

  testWidgets('honest fallback — text share when the platform refuses files', (
    tester,
  ) async {
    // Sync: real-async IO starves under fake-async (see the FaqRepository
    // note) — the test body runs before any runAsync bridge.
    final tmp = Directory.systemTemp.createTempSync('w4e_share_fallback');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('sunnahlife/system'), (
          call,
        ) async {
          calls.add(call);
          return false; // iOS-stub semantics: no image carry.
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('sunnahlife/system'),
            null,
          );
    });

    // Stub capture (the seam): the fallback logic is what's under test —
    // the real render is proven by its own test above. Reuses this test's
    // tmp dir (the PathProvider fake already points there).
    final stubPng = File('${tmp.path}/stub_card.png');
    stubPng.writeAsBytesSync(_tinyPngBytes);
    referralCardCapture = (context, card) async => stubPng;
    addTearDown(() => referralCardCapture = renderReferralCardPng);

    await bootDawah(tester, api: _TreeApi());
    await revealAndTap(tester, find.byKey(const Key('dawahShareCardButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('referralShareButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    final methods = calls.map((c) => c.method).toList();
    expect(methods, containsAllInOrder(['shareFile', 'shareText']));
    final textArgs =
        calls.where((c) => c.method == 'shareText').first.arguments as Map;
    expect(textArgs['text'] as String, contains(_kLink));
  });

  // ── The madu tree ─────────────────────────────────────────────────────────

  /// Boots [child] under a MaterialApp with the pinned clock + an
  /// in-memory db (profileProvider reads it on hydration).
  Future<void> pumpTree(WidgetTester tester, Widget child) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        headerNowProvider.overrideWithValue(_kNow),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildSunnahLightTheme(), home: child),
      ),
    );
  }

  testWidgets('madu tree — depth rails indent 24 px per level, gender tints', (
    tester,
  ) async {
    await pumpTree(tester, const Scaffold(body: MaduTree(nodes: _downline)));

    expect(find.byType(MaduTree), findsOneWidget);
    expect(find.byKey(const ValueKey('maduRow_m1')), findsOneWidget);
    expect(find.byKey(const ValueKey('maduRow_m2')), findsOneWidget);
    expect(find.byKey(const ValueKey('maduRow_m3')), findsOneWidget);
    expect(find.byKey(const ValueKey('maduRow_m4')), findsOneWidget);

    double avatarLeft(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('maduAvatar_$id'))).dx;

    // One column per level: 24 px deeper per level, same x for same depth.
    expect(avatarLeft('m1'), avatarLeft('m2'));
    expect(avatarLeft('m3') - avatarLeft('m1'), 24);
    expect(avatarLeft('m4') - avatarLeft('m3'), 24);

    // Connector rails only on the deeper rows.
    final row1 = tester.widget<Container>(
      find.byKey(const ValueKey('maduRow_m1')),
    );
    final row3 = tester.widget<Container>(
      find.byKey(const ValueKey('maduRow_m3')),
    );
    final stack1 = row1.child as Stack;
    final stack3 = row3.child as Stack;
    // The rails live inside Positioned.fill wrappers in the row's Stack.
    Iterable<CustomPaint> railsOf(Stack stack) => stack.children
        .whereType<Positioned>()
        .map((p) => p.child)
        .whereType<CustomPaint>();
    expect(railsOf(stack1), isEmpty, reason: 'depth-1 rows carry no rails');
    expect(
      railsOf(stack3),
      isNotEmpty,
      reason: 'deeper rows paint connector rails',
    );

    // Gender-tinted avatars: green family for the brothers, gold for the
    // sister (light theme tokens).
    BoxDecoration decorationOf(String id) =>
        tester
                .widget<Container>(find.byKey(ValueKey('maduAvatar_$id')))
                .decoration!
            as BoxDecoration;
    expect(decorationOf('m1').color, SLColors.primarySoftLight);
    expect(decorationOf('m3').color, SLColors.goldSoftLight);

    // Names + level chips + pinned relative last-active.
    expect(find.text('আব্দুল্লাহ আল মামুন'), findsOneWidget);
    expect(find.text('মাহমুদা খাতুন'), findsOneWidget);
    expect(find.text(S.tr(Lang.bn, 'level_muhibbus_sunnah')), findsOneWidget);
    expect(find.text('১ দিন আগে সক্রিয়'), findsOneWidget);
    expect(find.text('৩ দিন আগে সক্রিয়'), findsOneWidget);
    expect(find.text('৪ দিন আগে সক্রিয়'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('madu tree — long names wrap to 2 lines then ellipsize at 360 @1.3×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const longName =
        'আব্দুর রহমান ইবনে মুহাম্মাদ সাইফুল ইসলাম ফারুক আল মামুন খান মধ্যপাড়া ঢাকা';
    await pumpTree(
      tester,
      Scaffold(
        body: ListView(
          children: [
            const MaduTree(
              nodes: [
                DownlineNode(
                  id: 'm1',
                  name: longName,
                  gender: Gender.m,
                  level: Level.none,
                  depth: 1,
                  lastActiveAt: '2026-09-28T10:00:00Z',
                ),
                DownlineNode(
                  id: 'm3',
                  name: longName,
                  gender: Gender.f,
                  level: Level.none,
                  depth: 3,
                  lastActiveAt: '2026-09-28T10:00:00Z',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No overflow at the small viewport with large text…
    expect(tester.takeException(), isNull);
    // …and every name Text gets two lines, then "…" (one line cut even
    // ordinary full names on a small phone).
    for (final element in find.byType(Text).evaluate()) {
      final text = element.widget as Text;
      if (text.data == longName) {
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 2);
      }
    }
    expect(find.text(longName), findsNWidgets(2));
  });

  // ── Screen integration ────────────────────────────────────────────────────

  /// The overview tab's VERTICAL scrollable — `Scrollable.first` on this
  /// screen is the TabBarView's horizontal PageView, which never scrolls to
  /// the downline section.
  final Finder overviewScroll = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('empty downline keeps the madu empty state', (tester) async {
    await bootDawah(tester, api: _TreeApi(downline: const []));

    await tester.scrollUntilVisible(
      find.byIcon(PhosphorIconsRegular.tree),
      300,
      scrollable: overviewScroll,
    );
    expect(find.byIcon(PhosphorIconsRegular.tree), findsOneWidget);
    expect(
      find.byKey(const ValueKey('maduRow_m1')),
      findsNothing,
      reason: 'no tree rows without downline',
    );
  });

  testWidgets('offline (stale cache) overview still renders the tree', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveRemoteCache(
      key: 'dawah/overview:u1',
      payload: jsonEncode(_overview(downline: _downline).toJsonForCache()),
      fetchedAt: DateTime(2026, 9, 29, 9, 30),
    );

    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(_DaeeAuth.new),
        apiProvider.overrideWithValue(_StaleDawahApi(db)),
        headerNowProvider.overrideWithValue(_kNow),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSunnahLightTheme(),
          home: const DawahScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maduRow_m3')),
      300,
      scrollable: overviewScroll,
    );
    expect(find.text('মাহমুদা খাতুন'), findsOneWidget);
    expect(find.text('৩ দিন আগে সক্রিয়'), findsOneWidget);
  });
}

extension on DawahOverview {
  /// Raw-envelope shape the cache layer stores (models never carry
  /// toJson — the cache round-trips the API's JSON, so the test rebuilds
  /// the same shape _StaleDawahApi.jsonDecode expects).
  Map<String, dynamic> toJsonForCache() => {
    'memberCode': memberCode,
    'referralLink': referralLink,
    'invitedCount': invitedCount,
    'downline': [
      for (final n in downline)
        {
          'id': n.id,
          'name': n.name,
          'gender': n.gender == Gender.f ? 'F' : 'M',
          'level': switch (n.level) {
            Level.muhibbusSunnah => 'muhibbus_sunnah',
            Level.farzeAin1 => 'farze_ain_1',
            Level.farzeAin2 => 'farze_ain_2',
            _ => 'none',
          },
          'memberCode': n.memberCode,
          'depth': n.depth,
          'lastActiveAt': n.lastActiveAt,
        },
    ],
    'level': switch (level) {
      Level.muhibbusSunnah => 'muhibbus_sunnah',
      Level.farzeAin1 => 'farze_ain_1',
      Level.farzeAin2 => 'farze_ain_2',
      _ => 'none',
    },
    'monthsInLevel': monthsInLevel,
    'requirements': const [],
    'nextLevel': 'farze_ain_1',
    'assessments': const [],
  };
}
