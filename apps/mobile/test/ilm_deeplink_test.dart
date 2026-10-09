// Search results open the ITEM (2026-10-09): a dua / name comes first and
// framed in its list, an article opens in its own reader page.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/articles_screen.dart';
import 'package:sunnah_life/features/ilm/duas_screen.dart';
import 'package:sunnah_life/features/ilm/ilm_search_screen.dart';
import 'package:sunnah_life/features/ilm/islamic_names_screen.dart';
import 'package:sunnah_life/models/search.dart';
import 'package:sunnah_life/models/content_models.dart';

Future<void> pumpIn(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: buildSunnahLightTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.assetLoaderForTesting = (path) => File(path).readAsString();
  });
  tearDown(ContentPack.resetForTesting);

  test('result routes carry the item', () {
    expect(searchRouteFor(SearchKind.dua, 'travel'), '/ilm/duas?id=travel');
    expect(searchRouteFor(SearchKind.name99, '87'), '/ilm/names99?id=87');
    expect(searchRouteFor(SearchKind.article, 'a1'), '/ilm/articles/a1');
    expect(searchRouteFor(SearchKind.dhikr, 'morning'), '/ilm/adhkar?set=morning');
    expect(searchRouteFor(SearchKind.dua), '/ilm/duas');
  });

  testWidgets('a dua from search comes first, framed', (tester) async {
    final raw = jsonDecode(File('assets/content/duas.json').readAsStringSync());
    final items = (raw['items'] as List).cast<Map>();
    final last = items.last;
    await tester.runAsync(() => ContentPack.duas());
    await pumpIn(tester, DuasScreen(highlightId: last['id'] as String));
    expect(find.byKey(const ValueKey('search_hit')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search_hit')),
        matching: find.text(last['titleBn'] as String),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a girl\'s name from search opens on the girls\' tab', (
    tester,
  ) async {
    final raw = jsonDecode(
      File('assets/content/islamic-names.json').readAsStringSync(),
    );
    final girl = (raw['names'] as List).cast<Map>().firstWhere(
      (n) => n['gender'] == 'girl',
    );
    await tester.runAsync(() => ContentPack.islamicNames());
    await pumpIn(tester, IslamicNamesScreen(highlightId: '${girl['id']}'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search_hit')),
        matching: find.text(girl['name'] as String),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the article reader: paragraphs, Bengali date', (tester) async {
    final raw = jsonDecode(
      File('assets/content/articles.json').readAsStringSync(),
    );
    final a = (raw['items'] as List).cast<Map>().first;
    await tester.runAsync(() => ContentPack.articles());
    await pumpIn(tester, ArticleReaderScreen(id: a['id'] as String));
    expect(find.text(a['titleBn'] as String), findsOneWidget);
    final firstPara = (a['bodyBn'] as String).split('\n\n').first.trim();
    expect(find.text(firstPara), findsOneWidget);
    // no raw ISO date
    expect(find.textContaining(a['publishedAt'] as String), findsNothing);
  });
}
