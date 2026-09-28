/// Reminder panel state mapping (C-W4a) — pure, unit-tested.
///
/// GET /api/reminders rows carry `read` + `scheduledAt` (ISO or null). The
/// server has no richer lifecycle (no snooze/ack fields — checked against
/// apps/api/src/engagement/engagement.controllers.ts), so the panel derives
/// its four UI states from those two fields:
///
/// · done     — read (PATCH /api/reminders is the "mark done" action)
/// · overdue  — unread + scheduled time already past
/// · due      — unread + scheduled within the next 24 h (approaching/now)
/// · upcoming — unread + farther out, or no schedule at all (broadcasts)
///
/// Malformed timestamps degrade to `upcoming` — a broken row must never
/// break the panel.
library;

import '../models/live.dart';

enum ReminderUiState { due, overdue, upcoming, done }

/// The panel's default look-ahead window for the "due" state.
const Duration kReminderDueWindow = Duration(hours: 24);

ReminderUiState reminderUiState(
  ReminderItem reminder,
  DateTime now, {
  Duration dueWindow = kReminderDueWindow,
}) {
  if (reminder.read) return ReminderUiState.done;
  final raw = reminder.scheduledAt;
  if (raw == null || raw.isEmpty) return ReminderUiState.upcoming;
  final at = DateTime.tryParse(raw);
  if (at == null) return ReminderUiState.upcoming;
  if (at.isBefore(now)) return ReminderUiState.overdue;
  if (at.isBefore(now.add(dueWindow))) return ReminderUiState.due;
  return ReminderUiState.upcoming;
}

/// Sort key for the panel: unread first, then by recency of creation
/// (newest first — the server order), read rows sink to the bottom.
int reminderSort(ReminderItem a, ReminderItem b, DateTime now) {
  final aDone = reminderUiState(a, now) == ReminderUiState.done;
  final bDone = reminderUiState(b, now) == ReminderUiState.done;
  if (aDone != bDone) return aDone ? 1 : -1;
  return b.createdAt.compareTo(a.createdAt);
}
