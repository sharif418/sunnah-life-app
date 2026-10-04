/// NAV-04 — a daily reminder for an approved personal goal at a time the
/// member picks ("প্রতিদিন রাত ৯:০০"). Local notifications (works offline,
/// no server round-trip); the chosen time is kept per goal on the phone.
/// Removing the goal cancels it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bell_schedule.dart' show Nid;
import '../../core/calendars.dart' show formatTimeBn;
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../services/notification_service.dart';
import '../shared/widgets.dart';

String _prefKey(String goalId) => 'goal_reminder_$goalId';

/// A stable notification id per goal inside Nid.goalReminderBase's block.
int goalReminderNid(String goalId) {
  var h = 0;
  for (final c in goalId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return Nid.goalReminderBase + h % 500;
}

/// Minutes after midnight, or null when no reminder is set.
Future<int?> loadGoalReminder(String goalId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKey(goalId));
  } catch (_) {
    return null;
  }
}

/// Set ([minutes] ≥ 0) or clear (null) a goal's daily reminder. Never throws.
Future<void> setGoalReminder(
  String goalId, {
  required int? minutes,
  required String title,
  required String body,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null) {
      await prefs.remove(_prefKey(goalId));
    } else {
      await prefs.setInt(_prefKey(goalId), minutes);
    }
  } catch (_) {}
  try {
    final n = NotificationService.instance;
    await n.init();
    await n.cancel(goalReminderNid(goalId));
    if (minutes == null) return;
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await n.zoned(
      id: goalReminderNid(goalId),
      title: title,
      body: body,
      when: when,
      channel: 'sunnah_life_general',
      matchComponents: DateTimeComponents.time,
      payload: '/amal/goals',
    );
  } catch (e) {
    debugPrint('goal reminder schedule failed: $e');
  }
}

/// The row under an approved goal: "রিমাইন্ডার দিন" → a time picker; once
/// set, "প্রতিদিন রাত ৯:০০" with change / turn off.
class GoalReminderRow extends StatefulWidget {
  const GoalReminderRow({super.key, required this.goal});
  final PersonalGoal goal;

  @override
  State<GoalReminderRow> createState() => _GoalReminderRowState();
}

class _GoalReminderRowState extends State<GoalReminderRow> {
  int? _minutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadGoalReminder(widget.goal.id).then((m) {
      if (!mounted) return;
      setState(() {
        _minutes = m;
        _loaded = true;
      });
    });
  }

  Future<void> _pick() async {
    final initial = _minutes == null
        ? const TimeOfDay(hour: 21, minute: 0)
        : TimeOfDay(hour: _minutes! ~/ 60, minute: _minutes! % 60);
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: context.t('goal_reminder_pick'),
    );
    if (t == null || !mounted) return;
    final m = t.hour * 60 + t.minute;
    final body = context.t('goal_reminder_body');
    await setGoalReminder(widget.goal.id, minutes: m, title: widget.goal.title, body: body);
    if (mounted) setState(() => _minutes = m);
  }

  Future<void> _off() async {
    await setGoalReminder(widget.goal.id, minutes: null, title: '', body: '');
    if (mounted) setState(() => _minutes = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 40);
    final theme = Theme.of(context);
    final bn = context.isBn;
    if (_minutes == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: ValueKey('goal_reminder_set_${widget.goal.id}'),
          onPressed: _pick,
          icon: const Icon(PhosphorIconsRegular.bell, size: 18),
          label: Text(context.t('goal_reminder_set')),
        ),
      );
    }
    return Row(
      key: ValueKey('goal_reminder_on_${widget.goal.id}'),
      children: [
        Icon(PhosphorIconsFill.bell, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: SLSpacing.s8),
        Expanded(
          child: Text(
            context
                .t('goal_reminder_daily')
                .replaceAll('%time%', formatTimeBn(_minutes!.toDouble(), bengali: bn)),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: _pick, child: Text(context.t('goal_reminder_change'))),
        IconButton(
          tooltip: context.t('goal_reminder_off'),
          onPressed: _off,
          icon: const Icon(PhosphorIconsRegular.bellSlash, size: 18),
        ),
      ],
    );
  }
}
