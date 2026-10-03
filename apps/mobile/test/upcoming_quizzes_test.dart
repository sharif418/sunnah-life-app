// AMOL-17: scheduled live quizzes (LiveProgram.quizId) — live first, then
// soonest; plain-Bengali "when"; join only for usrah members, practice for all.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/ilm/upcoming_quizzes.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';
import 'package:sunnah_life/state/remote_state.dart' show liveProvider;

final _now = DateTime(2026, 10, 3, 10);

LiveProgramItem _p(String id, String status, DateTime at, {String? quizId}) =>
    LiveProgramItem.fromJson({
      'id': id,
      'titleBn': 'প্রোগ্রাম $id',
      'startsAt': at.toUtc().toIso8601String(),
      'status': status,
      'gender': 'M',
      'quizId': ?quizId,
    });

class _Member extends AuthNotifier {
  _Member(this.usrahId);
  final String? usrahId;
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: User(
      id: 'u1',
      name: 'সদস্য',
      gender: Gender.m,
      role: Role.user,
      category: UserCategory.general,
      usrahId: usrahId,
      createdAt: '2025-01-01T00:00:00Z',
      lastActiveAt: '2025-01-01T00:00:00Z',
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<LiveProgramItem> programs, {String? usrahId}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        authProvider.overrideWith(() => _Member(usrahId)),
        liveProvider.overrideWith((ref) async => programs),
      ],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(body: ListView(children: [UpcomingQuizzesSection(now: _now)])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only quiz programs, live first, then soonest; past/plain hidden', (tester) async {
    await _pump(tester, [
      _p('later', 'upcoming', _now.add(const Duration(days: 3)), quizId: 'quiz-salah'),
      _p('tomorrow', 'upcoming', DateTime(2026, 10, 4, 20, 30), quizId: 'quiz-aqeedah'),
      _p('live', 'live', _now, quizId: 'quiz-quran-sunnah'),
      _p('talk', 'upcoming', _now.add(const Duration(days: 1))), // not a quiz
      _p('old', 'past', _now.subtract(const Duration(days: 2)), quizId: 'quiz-salah'),
    ], usrahId: 'us1');

    double y(String id) => tester.getTopLeft(find.byKey(ValueKey('upcoming_quiz_$id'))).dy;
    expect(find.byKey(const ValueKey('upcoming_quiz_talk')), findsNothing);
    expect(find.byKey(const ValueKey('upcoming_quiz_old')), findsNothing);
    expect(y('live'), lessThan(y('tomorrow')));
    expect(y('tomorrow'), lessThan(y('later')));

    expect(find.text('এখন চলছে'), findsOneWidget);
    expect(find.text('আগামীকাল · রাত ৮:৩০'), findsOneWidget);
    expect(find.textContaining('৩ দিন পর'), findsOneWidget);
    // the live one: join (usrah member) + practice
    expect(find.byKey(const ValueKey('upcoming_quiz_join_live')), findsOneWidget);
    expect(find.byKey(const ValueKey('upcoming_quiz_practice_live')), findsOneWidget);
  });

  testWidgets('no usrah → no join button, practice still offered', (tester) async {
    await _pump(tester, [_p('live', 'live', _now, quizId: 'quiz-salah')]);
    expect(find.byKey(const ValueKey('upcoming_quiz_join_live')), findsNothing);
    expect(find.byKey(const ValueKey('upcoming_quiz_practice_live')), findsOneWidget);
  });

  testWidgets('nothing scheduled → nothing shown', (tester) async {
    await _pump(tester, const []);
    expect(find.byKey(const ValueKey('upcoming_quizzes')), findsNothing);
  });
}
