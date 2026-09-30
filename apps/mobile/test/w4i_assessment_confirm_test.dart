// W4i — the assessee's assessment-acknowledgment flow on the Dawah tab:
//   · own assessments render with STATUS chips (pending_confirmation |
//     confirmed | declined) and the নিশ্চিত করুন CTA on pending rows only;
//   · the OTP sheet: কোড পাঠান (confirm-request) → the code field (devCode
//     auto-fills in debug/mock only) → যাচাই করুন (confirm) → the overview
//     refetches and the CARD FLIPS to the confirmed chip + toast;
//   · a wrong code surfaces the server's Bengali error (ErrorState);
//   · ফলাফল বাতিল করুন with a reason → the card flips to declined + shows
//     the reason;
//   · the wire contract: myAssessments/assessmentConfirmRequest/
//     assessmentConfirm/assessmentDecline hit the exact routes with the
//     exact bodies (MockClient), and AssessmentSummary.fromJson parses the
//     new status fields.
// Patterns: test/w4e_dawah_craft_test.dart (boot + fakes) +
// test/referral_test.dart (MockClient wire proofs).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunnah_life/api/api_client.dart';
import 'package:sunnah_life/core/bn_digits.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/dawah/dawah_screen.dart';
import 'package:sunnah_life/features/shared/widgets.dart';
import 'package:sunnah_life/models/domain.dart';
import 'package:sunnah_life/state/providers.dart';

/// Pinned app clock (the offline stamps + relative labels never drift).
final DateTime _kNow = DateTime(2026, 9, 29, 12, 0);

const List<DownlineNode> _downline = [
  DownlineNode(
    id: 'm1',
    name: 'আব্দুল্লাহ আল মামুন',
    gender: Gender.m,
    level: Level.none,
    depth: 1,
    lastActiveAt: '2026-09-28T10:00:00Z',
  ),
];

DawahOverview _overview(List<AssessmentSummary> assessments) => DawahOverview(
      memberCode: 'DS-000004',
      referralLink: 'https://sunnahlife.app/join/DS-000004',
      invitedCount: 1,
      downline: _downline,
      level: Level.muhibbusSunnah,
      monthsInLevel: 2,
      requirements: const [],
      nextLevel: Level.farzeAin1,
      assessments: assessments,
    );

const List<AssessmentSummary> _mixed = [
  AssessmentSummary(
    id: 'a-pending',
    templateKey: 'farze_ain_v1.1',
    result: 'passed',
    createdAt: '2026-09-29T08:00:00.000Z',
    participantCategory: 1,
    scorePct: 88,
  ),
  AssessmentSummary(
    id: 'a-confirmed',
    templateKey: 'farze_ain_v1.0',
    result: 'passed',
    createdAt: '2026-08-01T08:00:00.000Z',
    participantCategory: 1,
    scorePct: 92,
    status: AssessmentStatus.confirmed,
    confirmedAt: '2026-08-02T08:00:00.000Z',
  ),
  AssessmentSummary(
    id: 'a-declined',
    templateKey: 'farze_ain_v1.0',
    result: 'not_yet',
    createdAt: '2026-07-01T08:00:00.000Z',
    participantCategory: 2,
    status: AssessmentStatus.declined,
    declinedAt: '2026-07-02T08:00:00.000Z',
    decisionNote: 'স্কোরে ভুল আছে',
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

/// Stateful fake — the server's observable behavior: confirm-request returns
/// the devCode (mock SMS), confirm accepts only the issued code and flips
/// the row to confirmed, decline flips it to declined with the reason.
class _AssessApi extends ApiClient {
  _AssessApi(this.assessments);

  List<AssessmentSummary> assessments;

  void _flip(String id, AssessmentStatus status, {String? reason}) {
    assessments = [
      for (final a in assessments)
        if (a.id == id)
          AssessmentSummary(
            id: a.id,
            templateKey: a.templateKey,
            result: a.result,
            createdAt: a.createdAt,
            participantCategory: a.participantCategory,
            scorePct: a.scorePct,
            status: status,
            confirmedAt: status == AssessmentStatus.confirmed
                ? '2026-09-29T09:00:00.000Z'
                : null,
            declinedAt: status == AssessmentStatus.declined
                ? '2026-09-29T09:00:00.000Z'
                : null,
            decisionNote: reason,
          )
        else
          a,
    ];
  }

  AssessmentDetail get _detail => AssessmentDetail(
        id: 'a-pending',
        templateKey: 'farze_ain_v1.1',
        result: 'passed',
        createdAt: '2026-09-29T08:00:00.000Z',
        participantCategory: 1,
        scorePct: 88,
        status: assessments
            .firstWhere((a) => a.id == 'a-pending')
            .status,
        template: const AssessmentTemplate(
          key: 'farze_ain_v1.1',
          version: 1,
          titleBn: 'ফরযে আইন মূল্যায়ন',
          titleEn: 'Farze Ain v1.1',
          sections: [],
        ),
        scores: const {},
      );

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
      ApiCached(_overview(assessments), fetchedAt: _kNow);

  @override
  Future<OtpResponse> assessmentConfirmRequest(String id) async =>
      const OtpResponse(ok: true, devCode: '123456');

  @override
  Future<AssessmentDetail> assessmentConfirm({
    required String id,
    required String code,
  }) async {
    if (code != '123456') throw ApiException(400, 'ভুল কোড');
    _flip(id, AssessmentStatus.confirmed);
    return _detail;
  }

  @override
  Future<AssessmentDetail> assessmentDecline({
    required String id,
    String? reason,
  }) async {
    _flip(id, AssessmentStatus.declined, reason: reason);
    return _detail;
  }
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


/// The overview tab's VERTICAL scrollable (Scrollable.first is the
/// TabBarView's horizontal PageView — the w4e lesson) + a scroll-to step
/// for the below-the-fold assessments section.
final Finder overviewScroll = find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> scrollToAssessments(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('assessment_row_a-pending')),
    300,
    scrollable: overviewScroll,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('status chips: pending + CTA, confirmed chip, declined + reason',
      (tester) async {
    final api = _AssessApi([..._mixed]);
    await bootDawah(tester, api: api);
    await scrollToAssessments(tester);

    // the three chips render with their Bengali labels
    expect(find.byKey(const ValueKey('assessment_status_chip_pending_confirmation')), findsOneWidget);
    expect(find.text('নিশ্চয়ন বাকি'), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment_status_chip_confirmed')), findsOneWidget);
    expect(find.text('নিশ্চিত হয়েছে'), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment_status_chip_declined')), findsOneWidget);
    expect(find.text('বাতিল করেছেন'), findsOneWidget);

    // the CTA exists ONLY on the pending row
    expect(find.byKey(const ValueKey('assessmentConfirmCta_a-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('assessmentConfirmCta_a-confirmed')), findsNothing);
    expect(find.byKey(const ValueKey('assessmentConfirmCta_a-declined')), findsNothing);

    // the declined row surfaces the member's reason
    expect(find.textContaining('স্কোরে ভুল আছে'), findsOneWidget);

    // the score still renders (bn digits)
    expect(find.text('${toBn(88)}%'), findsOneWidget);
  });

  testWidgets(
      'the OTP sheet: CTA → কোড পাঠান → (devCode auto-fills in debug) → যাচাই করুন → the card flips to confirmed',
      (tester) async {
    final api = _AssessApi([..._mixed]);
    await bootDawah(tester, api: api);
    await scrollToAssessments(tester);

    await tester.tap(find.byKey(const ValueKey('assessmentConfirmCta_a-pending')));
    await tester.pumpAndSettle();

    // the sheet is up with its title + the send-code step
    expect(find.text('মূল্যায়ন নিশ্চিত করুন'), findsOneWidget);
    expect(find.byKey(const Key('assessmentConfirmSendButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assessmentConfirmSendButton')));
    await tester.pumpAndSettle();

    // the code field auto-filled with the mock devCode (debug-only affordance)
    final field = tester.widget<TextField>(
      find.byKey(const Key('assessmentConfirmCodeField')),
    );
    expect((field.controller!.text), '123456');

    await tester.tap(find.byKey(const Key('assessmentConfirmVerifyButton')));
    await tester.pump(); // the confirm lands
    await tester.pump(); // dawahProvider refetches
    await tester.pumpAndSettle();

    // the sheet closed + the confirmation toast
    expect(find.byKey(const Key('assessmentConfirmCodeField')), findsNothing);
    expect(find.textContaining('আলহামদুলিল্লাহ'), findsOneWidget);

    // THE CARD FLIPPED: no more pending chip/CTA — the confirmed chip took over
    expect(find.byKey(const ValueKey('assessment_status_chip_pending_confirmation')), findsNothing);
    expect(find.byKey(const ValueKey('assessmentConfirmCta_a-pending')), findsNothing);
    expect(find.byKey(const ValueKey('assessment_status_chip_confirmed')), findsNWidgets(2));
  });

  testWidgets('a wrong code surfaces the Bengali error; the correct one still confirms',
      (tester) async {
    final api = _AssessApi([..._mixed]);
    await bootDawah(tester, api: api);
    await scrollToAssessments(tester);

    await tester.tap(find.byKey(const ValueKey('assessmentConfirmCta_a-pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessmentConfirmSendButton')));
    await tester.pumpAndSettle();

    // overwrite the auto-filled code with a wrong one
    await tester.enterText(
      find.byKey(const Key('assessmentConfirmCodeField')),
      '000000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assessmentConfirmVerifyButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.textContaining('ভুল কোড'), findsOneWidget);
    // the sheet stayed open — the decision is not made
    expect(find.byKey(const Key('assessmentConfirmCodeField')), findsOneWidget);

    // the correct code now confirms
    await tester.enterText(
      find.byKey(const Key('assessmentConfirmCodeField')),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assessmentConfirmVerifyButton')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('assessment_status_chip_pending_confirmation')), findsNothing);
    expect(find.byKey(const ValueKey('assessment_status_chip_confirmed')), findsNWidgets(2));
  });

  testWidgets('decline with a reason → the card flips to declined + shows the reason',
      (tester) async {
    final api = _AssessApi([..._mixed]);
    await bootDawah(tester, api: api);
    await scrollToAssessments(tester);

    await tester.tap(find.byKey(const ValueKey('assessmentConfirmCta_a-pending')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assessmentDeclineButton')));
    await tester.pumpAndSettle();

    // the decline dialog with its reason field
    expect(find.text('ফলাফল বাতিল করবেন?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'আবার মূল্যায়ন হোক');
    await tester.pump();
    await tester.tap(find.text('বাতিল করুন').last);
    await tester.pump(); // decline lands
    await tester.pump(); // dawahProvider refetches
    await tester.pumpAndSettle();
    // retire the toast's timer (the W4d repair note)
    await tester.pump(const Duration(seconds: 5));

    // the card flipped to declined + the reason is visible on the row
    expect(find.byKey(const ValueKey('assessment_status_chip_pending_confirmation')), findsNothing);
    expect(find.byKey(const ValueKey('assessment_status_chip_declined')), findsNWidgets(2));
    expect(find.textContaining('আবার মূল্যায়ন হোক'), findsOneWidget);
  });

  group('wire contract (MockClient) + model parse', () {
    test('AssessmentSummary.fromJson parses the W4i status fields', () {
      const row = {
        'id': 'a1',
        'templateKey': 'farze_ain_v1.1',
        'result': 'passed',
        'createdAt': '2026-09-29T08:00:00.000Z',
        'assessorSignedAt': '2026-09-29T07:00:00.000Z',
        'assesseeSignedAt': null,
        'participantCategory': 1,
        'scorePct': 88,
        'status': 'confirmed',
        'confirmedAt': '2026-09-29T09:00:00.000Z',
        'declinedAt': null,
        'decisionNote': null,
      };
      final a = AssessmentSummary.fromJson(row);
      expect(a.status, AssessmentStatus.confirmed);
      expect(a.confirmedAt, '2026-09-29T09:00:00.000Z');
      expect(a.decisionNote, isNull);

      // unknown/absent status degrades to the safe non-final default
      expect(
        AssessmentSummary.fromJson({...row, 'status': 'weird'}).status,
        AssessmentStatus.pendingConfirmation,
      );
      expect(
        AssessmentDetail.fromJson({
          ...row,
          'template': <String, dynamic>{},
          'scores': <String, dynamic>{},
        }).status,
        AssessmentStatus.confirmed,
      );
    });

    test('myAssessments + confirm-request/confirm/decline hit the exact routes',
        () async {
      final calls = <String>[];
      late String issuedCode;
      final client = ApiClient(
        innerClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          Object body = {};
          if (request.url.path.endsWith('/api/assessments/me')) {
            body = {
              'assessments': [
                {
                  'id': 'a1',
                  'templateKey': 'farze_ain_v1.1',
                  'result': 'passed',
                  'createdAt': '2026-09-29T08:00:00.000Z',
                  'participantCategory': 1,
                  'scorePct': 88,
                  'status': 'pending_confirmation',
                  'scores': {'i1': {'score': 2}},
                },
              ],
            };
          } else if (request.url.path.endsWith('/confirm-request')) {
            issuedCode = '654321';
            body = {'ok': true, 'devCode': issuedCode};
          } else if (request.url.path.endsWith('/confirm')) {
            final sent = jsonDecode(request.body) as Map<String, dynamic>;
            expect(sent['code'], issuedCode);
            body = {
              'assessment': {
                'id': 'a1',
                'templateKey': 'farze_ain_v1.1',
                'result': 'passed',
                'createdAt': '2026-09-29T08:00:00.000Z',
                'participantCategory': 1,
                'status': 'confirmed',
                'template': <String, dynamic>{},
                'scores': <String, dynamic>{},
              },
            };
          } else if (request.url.path.endsWith('/decline')) {
            final sent = jsonDecode(request.body) as Map<String, dynamic>;
            expect(sent['reason'], 'আবার মূল্যায়ন হোক');
            body = {
              'assessment': {
                'id': 'a1',
                'templateKey': 'farze_ain_v1.1',
                'result': 'passed',
                'createdAt': '2026-09-29T08:00:00.000Z',
                'participantCategory': 1,
                'status': 'declined',
                'template': <String, dynamic>{},
                'scores': <String, dynamic>{},
              },
            };
          }
          return http.Response(
            jsonEncode(body),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final mine = await client.myAssessments();
      expect(mine, hasLength(1));
      expect(mine.first.status, AssessmentStatus.pendingConfirmation);
      expect(mine.first.scores['i1']!.score, 2);

      final otp = await client.assessmentConfirmRequest('a1');
      expect(otp.devCode, '654321');

      final confirmed = await client.assessmentConfirm(id: 'a1', code: '654321');
      expect(confirmed.status, AssessmentStatus.confirmed);

      final declined = await client.assessmentDecline(
        id: 'a1',
        reason: 'আবার মূল্যায়ন হোক',
      );
      expect(declined.status, AssessmentStatus.declined);

      expect(calls, [
        'GET /api/assessments/me',
        'POST /api/assessments/a1/confirm-request',
        'POST /api/assessments/a1/confirm',
        'POST /api/assessments/a1/decline',
      ]);
    });
  });
}
