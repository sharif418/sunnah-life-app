/// Weekly review models — port of the review group in src/types/domain.ts.
library;

class WeeklyReview {
  const WeeklyReview({
    required this.id,
    required this.userId,
    required this.reviewerId,
    required this.weekStart,
    this.summary,
    this.comment,
    this.rating,
    this.nextGoals,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.userName,
    this.reviewerName,
  });
  final String id;
  final String userId;
  final String? userName;
  final String reviewerId;
  final String? reviewerName;
  final String weekStart;
  final Map<String, dynamic>? summary;
  final String? comment;
  final int? rating;
  final String? nextGoals;
  final String status; // pending | done | overdue
  final String createdAt;
  final String? completedAt;

  factory WeeklyReview.fromJson(Map<String, dynamic> j) => WeeklyReview(
    id: j['id'] as String,
    userId: j['userId'] as String,
    userName: j['userName'] as String?,
    reviewerId: j['reviewerId'] as String? ?? '',
    reviewerName: j['reviewerName'] as String?,
    weekStart: j['weekStart'] as String? ?? '',
    summary: j['summary'] as Map<String, dynamic>?,
    comment: j['comment'] as String?,
    rating: (j['rating'] as num?)?.toInt(),
    nextGoals: j['nextGoals'] as String?,
    status: j['status'] as String? ?? 'pending',
    createdAt: j['createdAt'] as String? ?? '',
    completedAt: j['completedAt'] as String?,
  );
}

/// Server-computed week rollup (mapReview's summary shape).
class WeekSummary {
  const WeekSummary({
    this.overallPct,
    this.byCategory,
    this.streak,
    this.missedDays,
    this.counts,
  });
  final int? overallPct;
  final Map<String, num>? byCategory;
  final int? streak;
  final int? missedDays;
  final Map<String, num>? counts;

  factory WeekSummary.fromJson(Map<String, dynamic> j) => WeekSummary(
    overallPct: (j['overallPct'] as num?)?.toInt(),
    byCategory: (j['byCategory'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as num),
    ),
    streak: (j['streak'] as num?)?.toInt(),
    missedDays: (j['missedDays'] as num?)?.toInt(),
    counts: (j['counts'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as num),
    ),
  );
}
