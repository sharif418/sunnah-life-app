// AMOL-11: the iman self-assessment — score maths, the finish gate, the
// result (focus list), and that it is saved on-device only.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/amal/iman_check_screen.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/providers.dart';

const _branches = [
  ImanBranch(id: 0, group: 'heart', titleBn: 'ঈমান (মূল)'),
  ImanBranch(id: 1, group: 'heart', titleBn: 'তাওহীদে বিশ্বাস'),
  ImanBranch(id: 2, group: 'tongue', titleBn: 'কালিমা পাঠ'),
  ImanBranch(id: 3, group: 'body', titleBn: 'পবিত্রতা'),
];

void main() {
  test('score: আছে = 2, চেষ্টা = 1, এখনো নয় = 0 of the full mark', () {
    expect(imanScorePct({1: 2, 2: 2, 3: 2}, [1, 2, 3]), 100);
    expect(imanScorePct({1: 2, 2: 1, 3: 0}, [1, 2, 3]), 50);
    expect(imanScorePct({}, [1, 2]), 0);
    expect(imanScorePct({}, []), 0);
  });

  testWidgets('answer all → result with the focus list; saved on-device', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: const ImanCheckScreen(branches: _branches),
      ),
    ));
    await tester.pumpAndSettle();

    // the root (id 0) is not rated
    expect(find.byKey(const ValueKey('iman_q_0')), findsNothing);
    expect(find.text('আরও ৩টি বাকি'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('iman_a_1_2')));
    await tester.tap(find.byKey(const ValueKey('iman_a_2_1')));
    await tester.tap(find.byKey(const ValueKey('iman_a_3_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('iman_check_finish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('iman_check_result')), findsOneWidget);
    expect(find.text('৫০%'), findsOneWidget);
    expect(find.text('এখন যেগুলোতে মনোযোগ দিন'), findsOneWidget);
    expect(find.text('পবিত্রতা'), findsOneWidget);

    final saved = await loadImanCheck();
    expect(saved!.answers, {1: 2, 2: 1, 3: 0});
  });
}
