// The quiz player after 2026-10-09: options shuffled per run, the wrong
// answers reviewed at the end, and back mid-quiz asks first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/quizzes_screen.dart';
import 'package:sunnah_life/l10n/app_strings.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/remote_state.dart';

String t(String k) => S.tr(Lang.bn, k);

const quiz = Quiz(
  id: 'q-test',
  titleBn: 'পরীক্ষা',
  category: 'aqeedah',
  minutes: 2,
  questions: [
    QuizQuestion(
      id: '1',
      questionBn: 'প্রথম প্রশ্ন',
      options: ['ক-ঠিক', 'খ-ভুল', 'গ-ভুল'],
      answerIndex: 0,
      explanationBn: 'কারণ ক',
    ),
    QuizQuestion(
      id: '2',
      questionBn: 'দ্বিতীয় প্রশ্ন',
      options: ['ঘ-ভুল', 'ঙ-ঠিক'],
      answerIndex: 1,
    ),
  ],
);

Future<void> pumpPlayer(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(412 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [quizPackProvider.overrideWith((ref) async => const [quiz])],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuizPlayerScreen(quizId: 'q-test'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a wrong answer is reviewed at the end', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.text('খ-ভুল')); // wrong, wherever it was shuffled
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('quiz_next_question')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ঙ-ঠিক'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('quiz_finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz_review')), findsOneWidget);
    expect(find.text('প্রথম প্রশ্ন'), findsOneWidget);
    expect(find.text('দ্বিতীয় প্রশ্ন'), findsNothing, reason: 'answered right');
    expect(find.text('কারণ ক'), findsOneWidget);
  });

  testWidgets('back mid-quiz asks before throwing the run away', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await tester.tap(find.text('ক-ঠিক'));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(t('quiz_leave_title')), findsOneWidget);
    await tester.tap(find.text(t('quiz_keep_playing')));
    await tester.pumpAndSettle();
    expect(find.text('প্রথম প্রশ্ন'), findsOneWidget);
  });
}
