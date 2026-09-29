/// Personal-goal lifecycle models (W4c) — port of the goals group in
/// apps/api/src/amal/goals.controller.ts (GoalItem + the queue shape).
library;

/// proposed → (approve | reject) → terminal; completed/withdrawn are
/// reserved statuses the API never sets today (no setter endpoint exists).
enum GoalStatus { proposed, approved, rejected, completed, withdrawn }

extension GoalStatusJson on GoalStatus {
  String get json => name;
  static GoalStatus fromJson(String v) => switch (v) {
    'approved' => GoalStatus.approved,
    'rejected' => GoalStatus.rejected,
    'completed' => GoalStatus.completed,
    'withdrawn' => GoalStatus.withdrawn,
    _ => GoalStatus.proposed,
  };

  /// ARB key for the localized status chip label.
  String get labelKey => switch (this) {
    GoalStatus.proposed => 'goal_status_proposed',
    GoalStatus.approved => 'goal_status_approved',
    GoalStatus.rejected => 'goal_status_rejected',
    GoalStatus.completed => 'goal_status_completed',
    GoalStatus.withdrawn => 'goal_status_withdrawn',
  };

  /// Terminal statuses are history: the member cannot delete them, and they
  /// don't count toward the server's max-14 open-goals cap.
  bool get isTerminal =>
      this == GoalStatus.rejected ||
      this == GoalStatus.completed ||
      this == GoalStatus.withdrawn;
}

/// One personal goal — the member proposes it, the usrah head decides.
class PersonalGoal {
  const PersonalGoal({
    required this.id,
    required this.userId,
    required this.amalKey,
    required this.title,
    this.note,
    this.target,
    required this.startDate,
    required this.active,
    required this.status,
    this.decidedById,
    this.decidedAt,
    this.reason,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String amalKey;
  final String title;
  final String? note;
  final String? target;
  final String startDate; // YYYY-MM-DD
  final bool active;
  final GoalStatus status;
  final String? decidedById;
  final String? decidedAt; // ISO
  final String? reason; // set on reject
  final String createdAt; // ISO

  PersonalGoal copyWith({GoalStatus? status, String? reason}) => PersonalGoal(
    id: id,
    userId: userId,
    amalKey: amalKey,
    title: title,
    note: note,
    target: target,
    startDate: startDate,
    active: active,
    status: status ?? this.status,
    decidedById: decidedById,
    decidedAt: decidedAt,
    reason: reason ?? this.reason,
    createdAt: createdAt,
  );

  factory PersonalGoal.fromJson(Map<String, dynamic> j) => PersonalGoal(
    id: j['id'] as String,
    userId: j['userId'] as String? ?? '',
    amalKey: j['amalKey'] as String? ?? '',
    title: j['title'] as String? ?? '',
    note: j['note'] as String?,
    target: j['target'] as String?,
    startDate: j['startDate'] as String? ?? '',
    active: j['active'] as bool? ?? true,
    status: GoalStatusJson.fromJson(j['status'] as String? ?? 'proposed'),
    decidedById: j['decidedById'] as String?,
    decidedAt: j['decidedAt'] as String?,
    reason: j['reason'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'userId': userId,
    'amalKey': amalKey,
    'title': title,
    'note': note,
    'target': target,
    'startDate': startDate,
    'active': active,
    'status': status.json,
    'decidedById': decidedById,
    'decidedAt': decidedAt,
    'reason': reason,
    'createdAt': createdAt,
  };
}

/// One row of GET /api/usrah/goals — a proposed goal in the supervisor's
/// scope, with the member's name for the queue card.
class GoalQueueItem {
  const GoalQueueItem({required this.goal, required this.userName});
  final PersonalGoal goal;
  final String userName;

  factory GoalQueueItem.fromJson(Map<String, dynamic> j) => GoalQueueItem(
    goal: PersonalGoal.fromJson(j),
    userName: j['userName'] as String? ?? '',
  );
}

