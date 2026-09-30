/// Assessment models — port of the assessment group in src/types/domain.ts:
/// summaries, templates (sections + criteria) and the detailed record with
/// per-criterion scores (0 | 1 | 2) and comments.
///
/// W4i: the farze-ain result only becomes FINAL (counts toward level
/// transitions) after the ASSESSEE's own OTP-confirmed acknowledgment —
/// [AssessmentStatus] carries that lifecycle.
library;

enum AssessmentStatus { pendingConfirmation, confirmed, declined }

extension AssessmentStatusJson on AssessmentStatus {
  /// Wire format is snake_case (matches the API's status column).
  String get json => switch (this) {
    AssessmentStatus.pendingConfirmation => 'pending_confirmation',
    AssessmentStatus.confirmed => 'confirmed',
    AssessmentStatus.declined => 'declined',
  };

  static AssessmentStatus fromJson(String v) => switch (v) {
    'confirmed' => AssessmentStatus.confirmed,
    'declined' => AssessmentStatus.declined,
    _ => AssessmentStatus.pendingConfirmation,
  };
}

class AssessmentSummary {
  const AssessmentSummary({
    required this.id,
    required this.templateKey,
    required this.result,
    required this.createdAt,
    this.assessorSignedAt,
    this.assesseeSignedAt,
    required this.participantCategory,
    this.scorePct,
    this.status = AssessmentStatus.pendingConfirmation,
    this.confirmedAt,
    this.declinedAt,
    this.decisionNote,
  });
  final String id;
  final String templateKey;
  final String result; // passed | not_yet
  final String createdAt;
  final String? assessorSignedAt;
  final String? assesseeSignedAt;
  final int participantCategory;
  final int? scorePct;

  /// W4i — final only when confirmed (see [AssessmentStatus]).
  final AssessmentStatus status;
  final String? confirmedAt;
  final String? declinedAt;

  /// The assessee's decline reason (declined only).
  final String? decisionNote;

  factory AssessmentSummary.fromJson(Map<String, dynamic> j) =>
      AssessmentSummary(
        id: j['id'] as String,
        templateKey: j['templateKey'] as String? ?? '',
        result: j['result'] as String? ?? 'not_yet',
        createdAt: j['createdAt'] as String? ?? '',
        assessorSignedAt: j['assessorSignedAt'] as String?,
        assesseeSignedAt: j['assesseeSignedAt'] as String?,
        participantCategory: (j['participantCategory'] as num?)?.toInt() ?? 1,
        scorePct: (j['scorePct'] as num?)?.toInt(),
        status: AssessmentStatusJson.fromJson(j['status'] as String? ?? ''),
        confirmedAt: j['confirmedAt'] as String?,
        declinedAt: j['declinedAt'] as String?,
        decisionNote: j['decisionNote'] as String?,
      );
}

class AssessmentCriterion {
  const AssessmentCriterion({
    required this.key,
    required this.titleBn,
    this.hintBn,
  });
  final String key;
  final String titleBn;
  final String? hintBn;

  factory AssessmentCriterion.fromJson(Map<String, dynamic> j) =>
      AssessmentCriterion(
        key: j['key'] as String? ?? '',
        titleBn: j['titleBn'] as String? ?? '',
        hintBn: j['hintBn'] as String?,
      );
}

class AssessmentSection {
  const AssessmentSection({
    required this.key,
    required this.titleBn,
    required this.criteria,
  });
  final String key;
  final String titleBn;
  final List<AssessmentCriterion> criteria;

  factory AssessmentSection.fromJson(Map<String, dynamic> j) =>
      AssessmentSection(
        key: j['key'] as String? ?? '',
        titleBn: j['titleBn'] as String? ?? '',
        criteria: ((j['criteria'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => AssessmentCriterion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class AssessmentTemplate {
  const AssessmentTemplate({
    required this.key,
    required this.version,
    required this.titleBn,
    required this.titleEn,
    required this.sections,
  });
  final String key;
  final int version;
  final String titleBn;
  final String titleEn;
  final List<AssessmentSection> sections;

  factory AssessmentTemplate.fromJson(Map<String, dynamic> j) =>
      AssessmentTemplate(
        key: j['key'] as String? ?? '',
        version: (j['version'] as num?)?.toInt() ?? 1,
        titleBn: j['titleBn'] as String? ?? '',
        titleEn: j['titleEn'] as String? ?? '',
        sections: ((j['sections'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => AssessmentSection.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// Per-criterion score: 0 | 1 | 2 + optional comment.
class AssessmentScore {
  const AssessmentScore({required this.score, this.comment});
  final int score;
  final String? comment;

  factory AssessmentScore.fromJson(Map<String, dynamic> j) => AssessmentScore(
    score: (j['score'] as num?)?.toInt() ?? 0,
    comment: j['comment'] as String?,
  );
}

class AssessmentDetail {
  const AssessmentDetail({
    required this.id,
    required this.templateKey,
    required this.result,
    required this.createdAt,
    this.assessorSignedAt,
    this.assesseeSignedAt,
    required this.participantCategory,
    this.scorePct,
    this.status = AssessmentStatus.pendingConfirmation,
    this.confirmedAt,
    this.declinedAt,
    this.decisionNote,
    required this.template,
    this.assessorName,
    this.assesseeName,
    required this.scores,
    this.overallComment,
  });
  final String id;
  final String templateKey;
  final String result;
  final String createdAt;
  final String? assessorSignedAt;
  final String? assesseeSignedAt;
  final int participantCategory;
  final int? scorePct;
  final AssessmentStatus status;
  final String? confirmedAt;
  final String? declinedAt;
  final String? decisionNote;
  final AssessmentTemplate template;
  final String? assessorName;
  final String? assesseeName;
  final Map<String, AssessmentScore> scores;
  final String? overallComment;

  factory AssessmentDetail.fromJson(Map<String, dynamic> j) =>
      AssessmentDetail(
        id: j['id'] as String,
        templateKey: j['templateKey'] as String? ?? '',
        result: j['result'] as String? ?? 'not_yet',
        createdAt: j['createdAt'] as String? ?? '',
        assessorSignedAt: j['assessorSignedAt'] as String?,
        assesseeSignedAt: j['assesseeSignedAt'] as String?,
        participantCategory: (j['participantCategory'] as num?)?.toInt() ?? 1,
        scorePct: (j['scorePct'] as num?)?.toInt(),
        status: AssessmentStatusJson.fromJson(j['status'] as String? ?? ''),
        confirmedAt: j['confirmedAt'] as String?,
        declinedAt: j['declinedAt'] as String?,
        decisionNote: j['decisionNote'] as String?,
        template: AssessmentTemplate.fromJson(
          j['template'] as Map<String, dynamic>? ?? const {},
        ),
        assessorName: j['assessorName'] as String?,
        assesseeName: j['assesseeName'] as String?,
        scores: (j['scores'] as Map<String, dynamic>? ?? const {})
            .map(
              (k, v) => MapEntry(
                k,
                AssessmentScore.fromJson(
                  (v as Map).cast<String, dynamic>(),
                ),
              ),
            ),
        overallComment: j['overallComment'] as String?,
      );
}
