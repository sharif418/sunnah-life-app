/// Engagement models — port of the misc/live groups in src/types/domain.ts.
library;

import 'user.dart';

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.link,
    this.scheduledAt,
    required this.read,
    required this.createdAt,
  });
  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? link;
  final String? scheduledAt;
  final bool read;
  final String createdAt;

  factory ReminderItem.fromJson(Map<String, dynamic> j) => ReminderItem(
    id: j['id'] as String,
    kind: j['kind'] as String? ?? 'general',
    title: j['title'] as String? ?? '',
    body: j['body'] as String?,
    link: j['link'] as String?,
    scheduledAt: j['scheduledAt'] as String?,
    read: j['read'] as bool? ?? false,
    createdAt: j['createdAt'] as String? ?? '',
  );
}

class LiveProgramItem {
  const LiveProgramItem({
    required this.id,
    required this.titleBn,
    this.descBn,
    this.hostName,
    required this.startsAt,
    this.endsAt,
    this.youtubeId,
    required this.gender,
    required this.status,
    this.recordingUrl,
    this.quizId,
  });
  final String id;
  final String titleBn;
  final String? descBn;
  final String? hostName;
  final String startsAt;
  final String? endsAt;
  final String? youtubeId;
  final Gender gender;
  final String status; // upcoming | live | past
  final String? recordingUrl;

  /// AMOL-17: set when the program is a scheduled live quiz.
  final String? quizId;

  factory LiveProgramItem.fromJson(Map<String, dynamic> j) => LiveProgramItem(
    id: j['id'] as String,
    titleBn: j['titleBn'] as String? ?? '',
    descBn: j['descBn'] as String?,
    hostName: j['hostName'] as String?,
    startsAt: j['startsAt'] as String? ?? '',
    endsAt: j['endsAt'] as String?,
    youtubeId: j['youtubeId'] as String?,
    gender: GenderJson.fromJson(j['gender'] as String? ?? 'M'),
    status: j['status'] as String? ?? 'upcoming',
    recordingUrl: j['recordingUrl'] as String?,
    quizId: j['quizId'] as String?,
  );
}
