// BNAV-01: the root tabs' header slides away while scrolling down and comes
// back on the first scroll up.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/shared/global_header.dart';
import 'package:sunnah_life/state/providers.dart';

import 'golden_fixtures.dart';

double _factor(WidgetTester t) =>
    t.widget<AnimatedAlign>(find.byKey(const ValueKey('scroll_aware_header'))).heightFactor!;

void main() {
  testWidgets('hides on scroll down, returns on scroll up', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(GoldenSignedInDaee.new),
        headerNowProvider.overrideWithValue(kGoldenNow),
      ],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(
          body: ScrollAwareHeader(
            body: ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('row $i'))]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_factor(tester), 1);

    await tester.drag(find.text('row 3'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_factor(tester), 0);

    await tester.drag(find.text('row 10'), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(_factor(tester), 1);
  });
}
