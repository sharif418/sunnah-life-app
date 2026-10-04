/// আমার লক্ষ্য — personal-goal lifecycle screen (W4c): propose a goal for
/// usrah-head approval, track it with status chips
/// (proposed/approved/rejected+reason/completed), and remove one of my
/// open goals (terminal rows are history on the server and undeletable).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/goals_state.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'goal_reminder.dart';
import '../../design/phosphor_icons.dart';

/// Max open goals the server allows (proposed + approved).
const int kMaxOpenGoals = 14;

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalsProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('goals_title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProposeSheet(context, ref),
        icon: const Icon(PhosphorIconsRegular.flagBanner),
        label: Text(context.t('goals_new')),
      ),
      body: async.when(
        loading: () => const Skeleton(height: 72, count: 5),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(goalsProvider),
        ),
        data: (goals) {
          if (goals == null) {
            // Guest / offline — goals are server-backed by design.
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                ErrorState(
                  message: context.t('goals_signin_needed'),
                  onRetry: () => ref.invalidate(goalsProvider),
                ),
              ],
            );
          }
          if (goals.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                EmptyState(
                  message: context.t('goals_empty'),
                  icon: PhosphorIconsRegular.flagBanner,
                ),
              ],
            );
          }
          final openCount = goals.where((g) => !g.status.isTerminal).length;
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              Text(
                '${context.t('goals_open_label')}: ${bn ? toBn(openCount) : openCount}/${bn ? toBn(kMaxOpenGoals) : kMaxOpenGoals}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              for (final g in goals) _GoalCard(goal: g),
              const SizedBox(height: SLSpacing.s64),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openProposeSheet(BuildContext context, WidgetRef ref) async {
    final defs = await ref.read(amalDefinitionsProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProposeSheet(defs: defs),
    );
  }
}

/// Status chip — color-coded pill with the localized status label.
class GoalStatusChip extends StatelessWidget {
  const GoalStatusChip({super.key, required this.status});
  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      GoalStatus.approved => theme.colorScheme.primary,
      GoalStatus.completed => theme.colorScheme.primary,
      GoalStatus.proposed => theme.colorScheme.tertiary,
      _ => theme.colorScheme.error,
    };
    return Container(
      key: ValueKey('goal_status_chip_${status.json}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        context.t(status.labelKey),
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});
  final PersonalGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GoalStatusChip(status: goal.status),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${goal.startDate}${goal.target != null && goal.target!.isNotEmpty ? ' · ${goal.target}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (goal.note != null && goal.note!.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(goal.note!, style: theme.textTheme.bodyMedium),
            ],
            if (goal.status == GoalStatus.rejected &&
                goal.reason != null &&
                goal.reason!.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(
                '${context.t('goals_reject_reason_label')}: ${goal.reason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            // NAV-04: an approved goal can remind me daily at my time
            if (goal.status == GoalStatus.approved) ...[
              const SizedBox(height: SLSpacing.s4),
              GoalReminderRow(goal: goal),
            ],
            if (!goal.status.isTerminal)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => _confirmRemove(context, ref),
                  icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                  label: Text(context.t('goals_remove')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(context.t('goals_remove_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('goals_remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).deleteGoal(goal.id);
      await setGoalReminder(goal.id, minutes: null, title: '', body: '');
      ref.invalidate(goalsProvider);
    } on ApiException catch (e) {
      // The server's refusal (e.g. terminal rows are history) surfaces
      // verbatim — its messages are already Bengali.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _ProposeSheet extends ConsumerStatefulWidget {
  const _ProposeSheet({required this.defs});
  final List<AmalDefinition> defs;

  @override
  ConsumerState<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends ConsumerState<_ProposeSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _amalKey;
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(apiProvider)
          .proposeGoal(
            amalKey: _amalKey!,
            title: _titleController.text.trim(),
            startDate: dateKey(DateTime.now()),
            note: _noteController.text.trim(),
            target: _targetController.text.trim(),
          );
      ref.invalidate(goalsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('goals_proposed_toast'))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defs = widget.defs;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('goals_new'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              DropdownButtonFormField<String>(
                // isExpanded wraps the closed button's IndexedStack of
                // item texts in an Expanded — without it the stack sizes to
                // the WIDEST catalog title's intrinsic width and overflows
                // on small widths (195px at 800 logical px in tests).
                isExpanded: true,
                initialValue: _amalKey,
                decoration: InputDecoration(
                  labelText: context.t('goals_amal_picker'),
                ),
                items: [
                  for (final d in defs)
                    DropdownMenuItem(
                      value: d.key,
                      child: Text(
                        d.titleBn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (v) => v == null ? context.t('goals_amal_picker') : null,
                onChanged: (v) => setState(() => _amalKey = v),
              ),
              const SizedBox(height: SLSpacing.s8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.t('goals_title_label'),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                    ? context.t('goals_title_label')
                    : null,
              ),
              const SizedBox(height: SLSpacing.s8),
              TextFormField(
                controller: _targetController,
                decoration: InputDecoration(
                  labelText: context.t('goals_target_label'),
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: context.t('goals_note_label'),
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: SLSpacing.s12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(context.t('goals_submit')),
                ),
              ),
              const SizedBox(height: SLSpacing.s16),
            ],
          ),
        ),
      ),
    );
  }
}
