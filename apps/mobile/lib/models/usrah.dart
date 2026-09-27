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
