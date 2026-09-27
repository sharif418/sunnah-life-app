/// Da'wah engine models — port of the dawah group in src/types/domain.ts.
library;

import 'assessment.dart';
import 'user.dart';

class DownlineNode {
  const DownlineNode({
    required this.id,
    required this.name,
    required this.gender,
    required this.level,
    this.memberCode,
    required this.depth,
    required this.lastActiveAt,
  });
  final String id;
  final String name;
  final Gender gender;
  final Level level;
  final String? memberCode;
  final int depth;
  final String lastActiveAt;

  factory DownlineNode.fromJson(Map<String, dynamic> j) => DownlineNode(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    gender: GenderJson.fromJson(j['gender'] as String? ?? 'M'),
    level: LevelJson.fromJson(j['level'] as String? ?? 'none'),
    memberCode: j['memberCode'] as String?,
    depth: (j['depth'] as num?)?.toInt() ?? 1,
    lastActiveAt: j['lastActiveAt'] as String? ?? '',
  );
}

class LevelRequirement {
  const LevelRequirement({
    required this.key,
    required this.label,
    required this.done,
    required this.detail,
  });
  final String key;
  final String label;
  final bool done;
  final String detail;

  factory LevelRequirement.fromJson(Map<String, dynamic> j) => LevelRequirement(
    key: j['key'] as String? ?? '',
    label: j['label'] as String? ?? '',
    done: j['done'] as bool? ?? false,
    detail: j['detail'] as String? ?? '',
  );
}

class DawahOverview {
  const DawahOverview({
    required this.memberCode,
    required this.referralLink,
    required this.invitedCount,
    required this.downline,
    required this.level,
    this.levelStartedAt,
    required this.monthsInLevel,
    required this.requirements,
    required this.nextLevel,
    required this.assessments,
  });
  final String memberCode;
  final String referralLink;
  final int invitedCount;
  final List<DownlineNode> downline;
  final Level level;
  final String? levelStartedAt;
  final int monthsInLevel;
  final List<LevelRequirement> requirements;
  final Level nextLevel;
  final List<AssessmentSummary> assessments;

  factory DawahOverview.fromJson(Map<String, dynamic> j) => DawahOverview(
    memberCode: j['memberCode'] as String? ?? '',
    referralLink: j['referralLink'] as String? ?? '',
    invitedCount: (j['invitedCount'] as num?)?.toInt() ?? 0,
    downline: ((j['downline'] as List?) ?? [])
        .map((e) => DownlineNode.fromJson(e as Map<String, dynamic>))
        .toList(),
    level: LevelJson.fromJson(j['level'] as String? ?? 'none'),
    levelStartedAt: j['levelStartedAt'] as String?,
    monthsInLevel: (j['monthsInLevel'] as num?)?.toInt() ?? 0,
    requirements: ((j['requirements'] as List?) ?? [])
        .map((e) => LevelRequirement.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextLevel: LevelJson.fromJson(j['nextLevel'] as String? ?? 'none'),
    assessments: ((j['assessments'] as List?) ?? [])
        .map((e) => AssessmentSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
