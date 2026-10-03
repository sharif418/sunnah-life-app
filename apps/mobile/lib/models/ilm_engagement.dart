/// Ilm engagement models — Task B4/B9: courses + enrollments, quiz attempt
/// history, the usrah question board, the live level requirements checklist
/// and the live-quiz room token. Port of the ilm/dawah groups in
/// src/types/domain.ts (the NestJS API is the wire source of truth).
/// NOTE: the Quiz/QuizQuestion content models live in content_models.dart
/// (shared with the offline pack loader) — imported, not duplicated.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'user.dart';

export 'content_models.dart' show Quiz, QuizQuestion;

// ── Courses (pack bodies + platform stats) ───────────────────────────────────

class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.titleBn,
    required this.descBn,
    required this.level,
    required this.lessonCount,
    required this.totalMinutes,
    required this.enrolledCount,
  });
  final String id;
  final String titleBn;
  final String descBn;
  final String level;
  final int lessonCount;
  final int totalMinutes;
  final int enrolledCount;

  factory CourseSummary.fromJson(Map<String, dynamic> j) => CourseSummary(
    id: j['id'] as String? ?? '',
    titleBn: j['titleBn'] as String? ?? '',
    descBn: j['descBn'] as String? ?? '',
    level: j['level'] as String? ?? '',
    lessonCount: (j['lessonCount'] as num?)?.toInt() ?? 0,
    totalMinutes: (j['totalMinutes'] as num?)?.toInt() ?? 0,
    enrolledCount: (j['enrolledCount'] as num?)?.toInt() ?? 0,
  );
}

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.titleBn,
    required this.bodyBn,
    required this.minutes,
    required this.order,
  });
  final String id;
  final String titleBn;
  final String bodyBn;
  final int minutes;
  final int order;

  factory CourseLesson.fromJson(Map<String, dynamic> j) => CourseLesson(
    id: j['id'] as String? ?? '',
    titleBn: j['titleBn'] as String? ?? '',
    bodyBn: j['bodyBn'] as String? ?? '',
    minutes: (j['minutes'] as num?)?.toInt() ?? 5,
    order: (j['order'] as num?)?.toInt() ?? 0,
  );
}

class CourseDetail {
  const CourseDetail({
    required this.id,
    required this.titleBn,
    required this.descBn,
    required this.level,
    required this.totalMinutes,
    required this.lessons,
  });
  final String id;
  final String titleBn;
  final String descBn;
  final String level;
  final int totalMinutes;
  final List<CourseLesson> lessons;

  factory CourseDetail.fromJson(Map<String, dynamic> j) => CourseDetail(
    id: j['id'] as String? ?? '',
    titleBn: j['titleBn'] as String? ?? '',
    descBn: j['descBn'] as String? ?? '',
    level: j['level'] as String? ?? '',
    totalMinutes: (j['totalMinutes'] as num?)?.toInt() ?? 0,
    lessons: ((j['lessons'] as List?) ?? [])
        .map((e) => CourseLesson.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// GET /api/courses/:id — course + platform stats + MY progress.
class CourseDetailResponse {
  const CourseDetailResponse({
    required this.course,
    required this.enrolledCount,
    this.myEnrollment,
  });
  final CourseDetail course;
  final int enrolledCount;
  final EnrollmentItem? myEnrollment;

  factory CourseDetailResponse.fromJson(Map<String, dynamic> j) =>
      CourseDetailResponse(
        course: CourseDetail.fromJson(
          (j['course'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
        enrolledCount: (j['enrolledCount'] as num?)?.toInt() ?? 0,
        myEnrollment: j['myEnrollment'] is Map
            ? EnrollmentItem.fromJson(
                (j['myEnrollment'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}

/// One row of my enrollment progress (progressJson shape: {done: [lessonId]}).
class EnrollmentItem {
  const EnrollmentItem({
    required this.courseId,
    required this.done,
    required this.updatedAt,
  });
  final String courseId;
  final List<String> done;
  final String updatedAt;

  factory EnrollmentItem.fromJson(Map<String, dynamic> j) {
    final progress = j['progress'];
    final done = <String>[];
    if (progress is Map && progress['done'] is List) {
      done.addAll((progress['done'] as List).map((e) => e.toString()));
    }
    return EnrollmentItem(
      courseId: j['courseId'] as String? ?? '',
      done: done,
      updatedAt: j['updatedAt'] as String? ?? '',
    );
  }
}

// ── Self-paced quizzes: content pack lives in content_models.dart
//    (Quiz/QuizQuestion); below is only the attempt history row. ───────────────

class QuizAttemptItem {
  const QuizAttemptItem({
    required this.id,
    required this.quizId,
    required this.score,
    required this.total,
    required this.createdAt,
  });
  final String id;
  final String quizId;
  final int score;
  final int total;
  final String createdAt;

  factory QuizAttemptItem.fromJson(Map<String, dynamic> j) => QuizAttemptItem(
    id: j['id'] as String? ?? '',
    quizId: j['quizId'] as String? ?? '',
    score: (j['score'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    createdAt: j['createdAt'] as String? ?? '',
  );
}

// ── Usrah quiz results (usrah_head+: GET /api/usrah/quiz-results) ─────────────

/// One member's best try at one quiz.
class MemberQuizResult {
  const MemberQuizResult({
    required this.quizId,
    required this.best,
    required this.total,
    required this.attempts,
    required this.lastAt,
  });
  final String quizId;
  final int best;
  final int total;
  final int attempts;
  final String lastAt;

  int get percent => total <= 0 ? 0 : (best * 100 / total).round();

  factory MemberQuizResult.fromJson(Map<String, dynamic> j) => MemberQuizResult(
    quizId: j['quizId'] as String? ?? '',
    best: (j['best'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    lastAt: j['lastAt'] as String? ?? '',
  );
}

class MemberQuizResults {
  const MemberQuizResults({
    required this.id,
    required this.name,
    this.memberCode,
    required this.results,
  });
  final String id;
  final String name;
  final String? memberCode;
  final List<MemberQuizResult> results;

  MemberQuizResult? resultFor(String quizId) {
    for (final r in results) {
      if (r.quizId == quizId) return r;
    }
    return null;
  }

  factory MemberQuizResults.fromJson(Map<String, dynamic> j) => MemberQuizResults(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    memberCode: j['memberCode'] as String?,
    results: ((j['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MemberQuizResult.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

/// The head's view: the quiz list + every member's results.
class UsrahQuizResults {
  const UsrahQuizResults({required this.quizzes, required this.members});
  final List<({String id, String titleBn})> quizzes;
  final List<MemberQuizResults> members;

  factory UsrahQuizResults.fromJson(Map<String, dynamic> j) => UsrahQuizResults(
    quizzes: [
      for (final q in ((j['quizzes'] as List?) ?? const []).whereType<Map>())
        (id: q['id'] as String? ?? '', titleBn: q['titleBn'] as String? ?? ''),
    ],
    members: ((j['members'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MemberQuizResults.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

// ── Usrah question board (RLS: own usrah only) ───────────────────────────────

class UsrahQuestion {
  const UsrahQuestion({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.question,
    this.answer,
    this.answeredByName,
    this.answeredAt,
    required this.createdAt,
  });
  final String id;
  final String authorId;
  final String? authorName;
  final String category;
  final String question;
  final String? answer;
  final String? answeredByName;
  final String? answeredAt;
  final String createdAt;

  factory UsrahQuestion.fromJson(Map<String, dynamic> j) => UsrahQuestion(
    id: j['id'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    category: j['category'] as String? ?? 'general',
    question: j['question'] as String? ?? '',
    answer: j['answer'] as String?,
    answeredByName: j['answeredByName'] as String?,
    answeredAt: j['answeredAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  /// The six board categories (API enum) with their ARB label keys.
  static const Map<String, String> categoryLabelKeys = {
    'general': 'usrah_q_cat_general',
    'aqeedah': 'usrah_q_cat_aqeedah',
    'salah': 'usrah_q_cat_salah',
    'quran': 'usrah_q_cat_quran',
    'muamalah': 'usrah_q_cat_muamalah',
    'tarbiyah': 'usrah_q_cat_tarbiyah',
  };

  String get categoryLabelKey => categoryLabelKeys[category] ?? 'usrah_q_cat_general';
}

// ── Live level-requirements checklist (B6) ───────────────────────────────────

class LevelCheckRow {
  const LevelCheckRow({
    required this.key,
    required this.labelBn,
    this.current,
    this.target,
    required this.met,
    required this.autoChecked,
    required this.detailBn,
  });
  final String key;
  final String labelBn;
  final int? current;
  final int? target;
  final bool met;
  final bool autoChecked;
  final String detailBn;

  factory LevelCheckRow.fromJson(Map<String, dynamic> j) => LevelCheckRow(
    key: j['key'] as String? ?? '',
    labelBn: j['labelBn'] as String? ?? '',
    current: (j['current'] as num?)?.toInt(),
    target: (j['target'] as num?)?.toInt(),
    met: j['met'] as bool? ?? false,
    autoChecked: j['autoChecked'] as bool? ?? true,
    detailBn: j['detailBn'] as String? ?? '',
  );
}

class DawahRequirements {
  const DawahRequirements({
    required this.level,
    required this.nextLevel,
    required this.rulesApply,
    required this.allMet,
    required this.autoEligible,
    required this.requirements,
  });
  final Level level;
  final Level nextLevel;
  final bool rulesApply;
  final bool allMet;
  final bool autoEligible;
  final List<LevelCheckRow> requirements;

  factory DawahRequirements.fromJson(Map<String, dynamic> j) =>
      DawahRequirements(
        level: LevelJson.fromJson(j['level'] as String? ?? 'none'),
        nextLevel: LevelJson.fromJson(j['nextLevel'] as String? ?? 'none'),
        rulesApply: j['rulesApply'] as bool? ?? false,
        allMet: j['allMet'] as bool? ?? false,
        autoEligible: j['autoEligible'] as bool? ?? false,
        requirements: ((j['requirements'] as List?) ?? [])
            .map((e) => LevelCheckRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

// ── Live quiz room token (GET /api/quiz/live-token) ──────────────────────────

class QuizLiveTokenResponse {
  const QuizLiveTokenResponse({
    required this.token,
    required this.room,
    required this.role,
    this.quizId,
    required this.expiresAtMs,
  });
  final String token;
  final String room;
  final String role; // "host" | "player"
  final String? quizId;
  final int expiresAtMs;

  factory QuizLiveTokenResponse.fromJson(Map<String, dynamic> j) =>
      QuizLiveTokenResponse(
        token: j['token'] as String? ?? '',
        room: j['room'] as String? ?? '',
        role: j['role'] as String? ?? 'player',
        quizId: j['quizId'] as String?,
        expiresAtMs: (j['exp'] as num?)?.toInt() ?? 0,
      );

  bool get isHost => role == 'host';
}

// ── Offline fallback for the course pack ────────────────────────────────────

/// Loads the BUNDLED course pack (assets/content/courses.json — the same file
/// the API serves from packages/content). The API stays the primary source;
/// this keeps the reading experience alive offline (progress syncs on
/// reconnect — enrollment/attempt tracking is server-side anyway).
Future<List<CourseDetail>> loadBundledCourses() async {
  try {
    final raw = await rootBundle.loadString('assets/content/courses.json');
    final decoded = jsonDecode(raw);
    final courses = decoded is Map ? decoded['courses'] : null;
    if (courses is! List) return const [];
    return courses
        .whereType<Map>()
        .map((e) => CourseDetail.fromJson(e.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    return const [];
  }
}
