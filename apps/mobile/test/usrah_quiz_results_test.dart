// The head's quiz-results section: per quiz the turnout + average, opening to
// the members (best first) and the ones who haven't taken it yet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/dawah/usrah_quiz_results.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/remote_state.dart' show usrahQuizResultsProvider;

final _data = UsrahQuizResults.fromJson({
  'quizzes': [
    {'id': 'quiz-salah', 'titleBn': 'সালাত'},
    {'id': 'quiz-aqeedah', 'titleBn': 'আকিদা'},
  ],
  'members': [
    {
      'id': 'a',
      'name': 'আব্দুল্লাহ',
      'results': [
        {'quizId': 'quiz-salah', 'best': 9, 'total': 10, 'attempts': 2, 'lastAt': '2026-10-01T10:00:00Z'},
      ],
    },
    {
      'id': 'b',
      'name': 'বেলাল',
      'results': [
        {'quizId': 'quiz-salah', 'best': 4, 'total': 10, 'attempts': 1, 'lastAt': '2026-10-02T10:00:00Z'},
      ],
    },
    {'id': 'c', 'name': 'জাকারিয়া', 'results': []},
  ],
});

Future<void> _pump(WidgetTester tester, UsrahQuizResults? data) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [usrahQuizResultsProvider.overrideWith((ref) async => data)],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(body: ListView(children: const [UsrahQuizResultsSection()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('turnout + average per quiz; opens to scores and who is left', (tester) async {
    await _pump(tester, _data);
    expect(find.text('সদস্যদের কুইজ ফলাফল'), findsOneWidget);
    // salah: 2 of 3 took it, average (90 + 40) / 2 = 65
    expect(find.text('অংশ নিয়েছেন ২/৩ জন · গড় ৬৫%'), findsOneWidget);
    // aqeedah: nobody yet — no average
    expect(find.text('অংশ নিয়েছেন ০/৩ জন'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quizres_quiz-salah')));
    await tester.pumpAndSettle();
    expect(find.text('৯/১০'), findsOneWidget);
    expect(find.text('৪/১০'), findsOneWidget);
    expect(find.text('২ বার'), findsOneWidget);
    expect(find.text('এখনো দেননি'), findsOneWidget); // জাকারিয়া
    // best first
    expect(
      tester.getTopLeft(find.text('আব্দুল্লাহ')).dy,
      lessThan(tester.getTopLeft(find.text('বেলাল')).dy),
    );
  });

  testWidgets('hidden for non-supervisors (null)', (tester) async {
    await _pump(tester, null);
    expect(find.byKey(const ValueKey('usrah_quiz_results')), findsNothing);
  });
}
