/// Live support models (W4d) — port of the support group in
/// apps/api/src/support/support.controller.ts (thread + message wire shapes).
library;

/// Thread lifecycle: open → (admin reply) answered → (member reply) open → …
/// → closed (admin-only, terminal — appending is refused with 400).
enum SupportStatus { open, answered, closed }

extension SupportStatusJson on SupportStatus {
  String get json => name;

  static SupportStatus fromJson(String v) => switch (v) {
    'answered' => SupportStatus.answered,
    'closed' => SupportStatus.closed,
    _ => SupportStatus.open,
  };
}

/// One own support thread (list row from GET /api/support).
class SupportThread {
  const SupportThread({
    required this.id,
    required this.userId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessageAt,
    this.lastPreview,
    this.unreadForUser = false,
    this.closedAt,
  });

  final String id;
  final String userId;
  final String subject;
  final SupportStatus status;
  final String createdAt; // ISO
  final String updatedAt; // ISO — last activity
  final int messageCount;
  final String? lastMessageAt; // ISO
  final String? lastPreview; // first ~120 chars of the last message
  /// True when the LAST message is a support-team reply — the "new answer"
  /// badge. No read-receipts server-side; opening the thread doesn't clear it.
  final bool unreadForUser;
  final String? closedAt; // ISO

  SupportThread copyWith({SupportStatus? status, bool? unreadForUser}) => SupportThread(
    id: id,
    userId: userId,
    subject: subject,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messageCount: messageCount,
    lastMessageAt: lastMessageAt,
    lastPreview: lastPreview,
    unreadForUser: unreadForUser ?? this.unreadForUser,
    closedAt: closedAt,
  );

  factory SupportThread.fromJson(Map<String, dynamic> j) => SupportThread(
    id: j['id'] as String,
    userId: j['userId'] as String? ?? '',
    subject: j['subject'] as String? ?? '',
    status: SupportStatusJson.fromJson(j['status'] as String? ?? 'open'),
    createdAt: j['createdAt'] as String? ?? '',
    updatedAt: j['updatedAt'] as String? ?? '',
    messageCount: (j['messageCount'] as num?)?.toInt() ?? 0,
    lastMessageAt: j['lastMessageAt'] as String?,
    lastPreview: j['lastPreview'] as String?,
    unreadForUser: j['unreadForUser'] as bool? ?? false,
    closedAt: j['closedAt'] as String?,
  );
}

/// One message inside a support thread (member view — the admin inbox adds
/// authorName; unknown keys are ignored).
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.isAdmin,
    required this.body,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String threadId;
  final String authorId;
  final String? authorName;
  final bool isAdmin; // true = written by the support team
  final String body;
  final String createdAt; // ISO

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
    id: j['id'] as String,
    threadId: j['threadId'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    isAdmin: j['isAdmin'] as bool? ?? false,
    body: j['body'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
  );
}
