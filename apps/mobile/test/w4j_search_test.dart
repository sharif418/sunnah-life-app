// W4j — the unified content search:
//   1. the bundled-pack matcher (pure, over the REAL assets via the
//      ContentPack File-loader seam): the short-q rule, the grouping order,
//      ZWNJ normalization, the adhkar set-level subtitle;
//   2. the screen (widget): the debounced query renders grouped rows with
//      kind chips + subtitles over a fake ApiClient (online path);
//   3. the OFFLINE fallback: a dead network (ApiException status 0) serves
//      the bundled-pack results + the gold offline strip;
//   4. navigation: the Ilm tab's search entry pushes the screen, and a
//      result row routes to the pack's own screen (the real router).
//
// Patterns: test/w4d_more_widget_test.dart (boot + fake ApiClient +
// runAsync prewarm over the FaqRepository-style ContentPack seam) +
// test/smoke_test.dart (full BootstrapGate boot).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/app.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/ilm_search_screen.dart';
import 'package:sunnah_life/features/ilm/search_offline.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart' show configProvider;

/// The fake API — search is scriptable; config answers the shell minimally
/// so the full-app boot never touches the network.
class _FakeSearchApi extends ApiClient {
  _FakeSearchApi({this.results = const [], this.error});

  List<SearchHit> results;
  ApiException? error;
  String? lastQuery;

  @override
  Future<SearchResults> search(String q, {int limit = 20}) async {
    lastQuery = q;
    if (error != null) throw error!;
    return SearchResults(query: q, results: results);
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

/// Prewarm the bundled-pack cache under the real-async zone (rootBundle
/// cannot answer inside fake-async; the File seam + the ContentPack data
/// cache make the fallback matcher hermetic).
Future<void> _prewarmPacks(WidgetTester tester) async {
  ContentPack.assetLoaderForTesting = (path) => File(path).readAsString();
  addTearDown(ContentPack.resetForTesting);
  await tester.runAsync(() async {
    await ContentPack.duas();
    await ContentPack.adhkar();
    await ContentPack.names99();
    await ContentPack.islamicNames();
    await ContentPack.articles();
  });
}

Future<AppDatabase> _seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.guestProfile();
  await db.saveGuestProfile(
    const GuestProfilesCompanion(onboardingDone: Value(true)),
  );
  return db;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── 1. The bundled-pack matcher (pure) ──────────────────────────────────

  group('searchBundledPacks — the offline matcher', () {
    setUp(() {
      ContentPack.assetLoaderForTesting = (path) => File(path).readAsString();
      addTearDown(ContentPack.resetForTesting);
    });

    test('the short-q rule mirrors the API: <2 code points → empty', () async {
      expect(await searchBundledPacks('খ'), isEmpty);
      expect(await searchBundledPacks(' '), isEmpty);
      expect(await searchBundledPacks(''), isEmpty);
    });

    test('"জ্ঞান" finds the duas + the 99-names meaning matches, grouped dua-first',
        () async {
      final rows = await searchBundledPacks('জ্ঞান');
      expect(rows, isNotEmpty);
      // the dua the API spec test also pins
      expect(
        rows.any((r) => r.id == 'rabbi-zidni-ilma' && r.kind == SearchKind.dua),
        isTrue,
      );
      // a 99-name whose meaningBn carries জ্ঞান
      expect(rows.any((r) => r.kind == SearchKind.name99 && r.id == '19'), isTrue);
      // grouping: no name99 row appears before the first dua row
      final firstDua = rows.indexWhere((r) => r.kind == SearchKind.dua);
      final firstName = rows.indexWhere((r) => r.kind == SearchKind.name99);
      expect(firstDua, greaterThanOrEqualTo(0));
      expect(firstDua, lessThan(firstName));

      // the row carries the server-shaped fields (bn labels by design)
      final dua = rows.firstWhere((r) => r.id == 'rabbi-zidni-ilma');
      expect(dua.title, 'জ্ঞান বৃদ্ধির দোয়া');
      expect(dua.kindLabelBn, 'দোয়া');
      expect(dua.subtitle, contains('জ্ঞান'));
    });

    test('normalization: a query without the ZWNJ still matches the translit',
        () async {
      // the pack's translitBn is "ফিদ্‌দুনইয়া" (with a ZWNJ) — typed input
      // never carries it
      final rows = await searchBundledPacks('ফিদ্দুনইয়া');
      expect(
        rows.any((r) => r.id == 'rabbana-atina' && r.kind == SearchKind.dua),
        isTrue,
      );
    });

    test('adhkar matches at the set level with the bn-digit item count',
        () async {
      final rows = await searchBundledPacks('সকাল');
      final morning = rows.firstWhere((r) => r.id == 'morning');
      expect(morning.kind, SearchKind.dhikr);
      expect(morning.title, 'সকালের মাসনূন আযকার');
      expect(morning.subtitle, '৯টি আযকার');
      expect(morning.kindLabelBn, 'আযকার');
    });

    test('the limit cap applies', () async {
      final rows = await searchBundledPacks('দোয়া', limit: 3);
      expect(rows.length, lessThanOrEqualTo(3));
    });
  });

  // ── 2 + 3. The screen — online rows + the offline fallback ───────────────

  group('IlmSearchScreen', () {
    Future<ProviderContainer> boot(
      WidgetTester tester, {
      required _FakeSearchApi api,
    }) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(api),
      ]);
      addTearDown(db.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildSunnahLightTheme(),
            home: const IlmSearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders the field + queries + grouped results (online)',
        (tester) async {
      final api = _FakeSearchApi(results: const [
        SearchHit(
          kind: SearchKind.dua,
          id: 'rabbi-zidni-ilma',
          title: 'জ্ঞান বৃদ্ধির দোয়া',
          subtitle: 'হে আমার রব! আমার জ্ঞান বাড়িয়ে দান করুন',
          kindLabelBn: 'দোয়া',
        ),
        SearchHit(
          kind: SearchKind.islamicName,
          id: '1',
          title: 'আবদুল্লাহ',
          subtitle: 'আল্লাহর বান্দা',
          kindLabelBn: 'ইসলামিক নাম',
        ),
      ]);
      final container = await boot(tester, api: api);

      // the field + the initial gentle hint (query too short) — the hint
      // string shows TWICE on purpose: TextField.hintText + the EmptyState
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(S.tr(Lang.bn, 'search_hint')), findsNWidgets(2));

      // type → debounce fires → the API is queried with the trimmed q
      await tester.enterText(find.byType(TextField), ' জ্ঞান ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.lastQuery, 'জ্ঞান');

      // grouped rows: chips + titles + subtitles
      expect(find.text('দোয়া'), findsOneWidget);
      expect(find.text('ইসলামিক নাম'), findsOneWidget);
      expect(find.text('জ্ঞান বৃদ্ধির দোয়া'), findsOneWidget);
      expect(find.text('আবদুল্লাহ'), findsOneWidget);
      // online — no offline strip
      expect(find.textContaining('অফলাইন'), findsNothing);

      container.dispose();
    });

    testWidgets('a dead network falls back to the bundled packs + the strip',
        (tester) async {
      await _prewarmPacks(tester);
      final api = _FakeSearchApi(
        error: ApiException(0, 'নেটওয়ার্ক সমস্যা — connection refused'),
      );
      final container = await boot(tester, api: api);

      await tester.enterText(find.byType(TextField), 'জ্ঞান');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // the bundled-pack result (not the API's error wall)
      expect(find.text('জ্ঞান বৃদ্ধির দোয়া'), findsOneWidget);
      // the honest offline strip
      expect(find.byIcon(Icons.wifi), findsNothing); // (placeholder sanity)
      expect(find.textContaining('অফলাইন'), findsOneWidget);
      expect(
        find.text(S.tr(Lang.bn, 'search_offline_note')),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('a 503 (search engine down) also falls back locally',
        (tester) async {
      await _prewarmPacks(tester);
      final api = _FakeSearchApi(
        error: ApiException(503, 'অনুসন্ধান সেবা এখন অনুপলব্ধ'),
      );
      final container = await boot(tester, api: api);

      await tester.enterText(find.byType(TextField), 'সকাল');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('সকালের মাসনূন আযকার'), findsOneWidget);
      expect(find.text(S.tr(Lang.bn, 'search_offline_note')), findsOneWidget);

      container.dispose();
    });

    testWidgets('no results → the honest empty state', (tester) async {
      final api = _FakeSearchApi(results: const []);
      final container = await boot(tester, api: api);

      await tester.enterText(find.byType(TextField), 'xyzabc');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(S.tr(Lang.bn, 'search_no_results')), findsOneWidget);

      container.dispose();
    });
  });

  // ── 4. Navigation — the real router ──────────────────────────────────────

  group('navigation', () {
    testWidgets('the Ilm search entry pushes the screen; a row routes to its pack',
        (tester) async {
      await _prewarmPacks(tester);
      final api = _FakeSearchApi(results: const [
        SearchHit(
          kind: SearchKind.dua,
          id: 'rabbi-zidni-ilma',
          title: 'জ্ঞান বৃদ্ধির দোয়া',
          subtitle: 'হে আমার রব!',
          kindLabelBn: 'দোয়া',
        ),
      ]);
      final db = await _seededDb();
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(api),
        configProvider.overrideWith((ref) async => await api.config()),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BootstrapGate(),
        ),
      );
      await tester.pumpAndSettle();

      // to the Ilm tab — the search entry card is there (W4j affordance)
      container.read(routerProvider).go('/ilm');
      await tester.pumpAndSettle();
      expect(find.text(S.tr(Lang.bn, 'search_hint')), findsOneWidget);

      // tap → the search screen
      await tester.tap(find.text(S.tr(Lang.bn, 'search_hint')));
      await tester.pumpAndSettle();
      expect(find.text(S.tr(Lang.bn, 'search_title')), findsOneWidget);

      // query → the dua row → tap routes to the duas screen
      await tester.enterText(find.byType(TextField), 'জ্ঞান');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('জ্ঞান বৃদ্ধির দোয়া'));
      await tester.pumpAndSettle();
      expect(find.text(S.tr(Lang.bn, 'ilm_duas')), findsOneWidget);

      // Dispose inside the test body so provider timers (prayer ticker,
      // 60s sync flush) are cancelled before the binding checks.
      container.dispose();
    });
  });

  // Sanity: the wire shape the API returns parses through the model.
  test('SearchResults.fromJson parses the API contract', () {
    final j = jsonDecode('''
    {"query":"জ্ঞান","results":[
      {"kind":"dua","id":"rabbi-zidni-ilma","title":"জ্ঞান বৃদ্ধির দোয়া",
       "subtitle":"হে আমার রব!","kindLabelBn":"দোয়া"},
      {"kind":"islamic_name","id":1,"title":"আবদুল্লাহ","kindLabelBn":"ইসলামিক নাম"}
    ]}
    ''') as Map<String, dynamic>;
    final res = SearchResults.fromJson(j);
    expect(res.query, 'জ্ঞান');
    expect(res.results, hasLength(2));
    expect(res.results[0].kind, SearchKind.dua);
    expect(res.results[0].subtitle, isNotNull);
    expect(res.results[1].kind, SearchKind.islamicName);
    expect(res.results[1].id, '1'); // numeric ids stringify
  });
}
