/// Usrah models — port of the usrah group in src/types/domain.ts.
library;

import 'user.dart';

class UsrahMember {
  const UsrahMember({
    required this.id,
    required this.name,
    required this.gender,
    this.level = Level.none,
    this.memberCode,
    this.lastActiveAt,
    this.completion7d,
    this.reviewsDone,
    this.reviewsTotal,
    this.category = UserCategory.general,
  });
  final String id;
  final String name;
  final Gender gender;
  final Level level;
  final String? memberCode;
  final String? lastActiveAt;
  final int? completion7d;
  final int? reviewsDone;
  final int? reviewsTotal;
  final UserCategory category;

  factory UsrahMember.fromJson(Map<String, dynamic> j) => UsrahMember(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    gender: GenderJson.fromJson(j['gender'] as String? ?? 'M'),
    level: LevelJson.fromJson(j['level'] as String? ?? 'none'),
    memberCode: j['memberCode'] as String?,
    lastActiveAt: j['lastActiveAt'] as String?,
    completion7d: (j['completion7d'] as num?)?.toInt(),
    reviewsDone: (j['reviewsDone'] as num?)?.toInt(),
    reviewsTotal: (j['reviewsTotal'] as num?)?.toInt(),
    category: UserCategoryJson.fromJson(
      j['category'] as String? ?? 'general',
    ),
  );
}

class Usrah {
  const Usrah({
    required this.id,
    required this.name,
    required this.gender,
    this.headUserId,
    this.invigilatorUserId,
    this.district,
    this.headName,
    this.memberCount,
    this.members = const [],
  });
  final String id;
  final String name;
  final Gender gender;
  final String? headUserId;
  final String? invigilatorUserId;
  final String? district;
  final String? headName;
  final int? memberCount;
  final List<UsrahMember> members;

  factory Usrah.fromJson(Map<String, dynamic> j) => Usrah(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    gender: GenderJson.fromJson(j['gender'] as String? ?? 'M'),
    headUserId: j['headUserId'] as String?,
    invigilatorUserId: j['invigilatorUserId'] as String?,
    district: j['district'] as String?,
    headName: j['headName'] as String?,
    memberCount: (j['memberCount'] as num?)?.toInt(),
    members: ((j['members'] as List?) ?? [])
        .map((e) => UsrahMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Announcement {
  const Announcement({
    required this.id,
    required this.authorId,
    required this.kind,
    required this.body,
    required this.pinned,
    required this.createdAt,
    this.usrahId,
    this.authorName,
  });
  final String id;
  final String? usrahId;
  final String authorId;
  final String? authorName;
  final String kind; // announcement | question | exam
  final String body;
  final bool pinned;
  final String createdAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id: j['id'] as String,
    usrahId: j['usrahId'] as String?,
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    kind: j['kind'] as String? ?? 'announcement',
    body: j['body'] as String? ?? '',
    pinned: j['pinned'] as bool? ?? false,
    createdAt: j['createdAt'] as String? ?? '',
  );
}

/// Usrah join-request lifecycle (W4d): a usrah-less member asks → full_admin
/// approves into an usrah (the assignment) or rejects with a reason.
enum JoinRequestStatus { pending, approved, rejected }

extension JoinRequestStatusJson on JoinRequestStatus {
  String get json => name;

  static JoinRequestStatus fromJson(String v) => switch (v) {
    'approved' => JoinRequestStatus.approved,
    'rejected' => JoinRequestStatus.rejected,
    _ => JoinRequestStatus.pending,
  };
}

/// Own current/last join request (GET /api/usrah/join-request → request|null).
class UsrahJoinRequest {
  const UsrahJoinRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.message,
    this.handledById,
    this.handledAt,
    this.usrahId,
    this.reason,
  });

  final String id;
  final String userId;
  final String? message; // the member's note to the tarbiyah office
  final JoinRequestStatus status;
  final String? handledById; // the admin who decided
  final String? handledAt; // ISO
  final String? usrahId; // the usrah assigned on approve
  final String? reason; // admin's note on rejection
  final String createdAt; // ISO

  factory UsrahJoinRequest.fromJson(Map<String, dynamic> j) => UsrahJoinRequest(
    id: j['id'] as String,
    userId: j['userId'] as String? ?? '',
    message: j['message'] as String?,
    status: JoinRequestStatusJson.fromJson(j['status'] as String? ?? 'pending'),
    handledById: j['handledById'] as String?,
    handledAt: j['handledAt'] as String?,
    usrahId: j['usrahId'] as String?,
    reason: j['reason'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );
}
