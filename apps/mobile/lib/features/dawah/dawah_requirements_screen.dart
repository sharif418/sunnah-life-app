/// স্তরের প্রয়োজনীয়তা — the LIVE next-level checklist (B9 mirror of the
/// web LevelRequirementsCard). GET /api/dawah/requirements evaluates the
/// same rules engine the nightly worker uses; while it is unreachable the
/// overview's own requirement rows stand in (same engine, last snapshot).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../api/api_client.dart' show ApiCached;
import '../../state/remote_state.dart';
import '../shared/widgets.dart';

class DawahRequirementsScreen extends ConsumerWidget {
  const DawahRequirementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(dawahRequirementsProvider);
    final overviewAsync = ref.watch(dawahProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('dawah_req_title')),
      ),
      body: liveAsync.when(
        loading: () => const Skeleton(height: 72, count: 5),
        error: (_, _) => _FallbackBody(overviewAsync: overviewAsync),
        // W4-fix4: a cache-served snapshot still renders the live body,
        // banner on top.
        data: (live) => live == null
            ? _FallbackBody(overviewAsync: overviewAsync)
            : _LiveBody(
                requirements: live.data,
                stale: live.stale,
                fetchedAt: live.fetchedAt,
              ),
      ),
    );
  }
}

// ── live checklist ────────────────────────────────────────────────────────────

class _LiveBody extends StatelessWidget {
  const _LiveBody({
    required this.requirements,
    this.stale = false,
    this.fetchedAt,
  });
  final DawahRequirements requirements;

  /// W4-fix4: cache-served snapshot (offline banner + stamp).
  final bool stale;
  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final live = requirements;

    return ListView(
      padding: const EdgeInsets.all(SLSpacing.s16),
      children: [
        if (stale && fetchedAt != null)
          OfflineBanner(fetchedAt: fetchedAt!),
        _LevelRow(level: live.level, nextLevel: live.nextLevel),
        const SizedBox(height: SLSpacing.s12),
        AppCard(
          padding: const EdgeInsets.all(SLSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (live.rulesApply) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SLSpacing.s8,
                    SLSpacing.s8,
                    SLSpacing.s8,
                    SLSpacing.s4,
                  ),
                  child: _MachineProgress(requirements: live),
                ),
                const SizedBox(height: SLSpacing.s4),
              ],
              for (final r in live.requirements) _CheckRow(row: r),
            ],
          ),
        ),
        const SizedBox(height: SLSpacing.s12),
        if (live.allMet)
          _OutcomeCard.success(context, context.t('dawah_req_all_met'))
        else if (live.autoEligible || live.rulesApply)
          _OutcomeCard.hint(context, context.t('dawah_req_auto_hint')),
        const SizedBox(height: SLSpacing.s24),
      ],
    );
  }
}

// ── fallback (overview rows + muted note) ─────────────────────────────────────

class _FallbackBody extends ConsumerWidget {
  const _FallbackBody({required this.overviewAsync});
  final AsyncValue<ApiCached<DawahOverview>?> overviewAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return overviewAsync.when(
      loading: () => const Skeleton(height: 72, count: 5),
      error: (_, _) => ListView(
        children: [
          const SizedBox(height: SLSpacing.s24),
          ErrorState(
            message: context.t('dawah_req_load_failed'),
            onRetry: () {
              ref.invalidate(dawahRequirementsProvider);
              ref.invalidate(dawahProvider);
            },
          ),
        ],
      ),
      data: (remote) {
        if (remote == null) {
          return ListView(
            children: [
              const SizedBox(height: SLSpacing.s24),
              ErrorState(
                message: context.t('dawah_req_load_failed'),
                onRetry: () {
                  ref.invalidate(dawahRequirementsProvider);
                  ref.invalidate(dawahProvider);
                },
              ),
            ],
          );
        }
        final overview = remote.data;
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            Text(
              context.t('dawah_req_load_failed'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            _LevelRow(level: overview.level, nextLevel: overview.nextLevel),
            const SizedBox(height: SLSpacing.s12),
            AppCard(
              padding: const EdgeInsets.all(SLSpacing.s8),
              child: Column(
                children: [
                  for (final r in overview.requirements)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        r.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: r.done
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      title: Text(
                        r.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: r.done
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        r.detail,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s24),
          ],
        );
      },
    );
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

/// "আমার স্তর: X / পরবর্তী স্তর: Y" stat cells.
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.nextLevel});
  final Level level;
  final Level nextLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(SLSpacing.s12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: SLRadius.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: SLSpacing.s8),
            child: cell(context.t('dawah_my_level'), context.t(level.labelKey)),
          ),
        ),
        Expanded(
          child: cell(
            context.t('dawah_next_level'),
            context.t(nextLevel.labelKey),
          ),
        ),
      ],
    );
  }
}

/// Auto-checked rules progress: one dot per machine row + "x/y পূরণ".
class _MachineProgress extends StatelessWidget {
  const _MachineProgress({required this.requirements});
  final DawahRequirements requirements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final machine = requirements.requirements
        .where((r) => r.autoChecked)
        .toList();
    final done = machine.where((r) => r.met).length;

    return Row(
      children: [
        for (final r in machine)
          Tooltip(
            message: r.labelBn,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsetsDirectional.only(end: SLSpacing.s4),
              decoration: BoxDecoration(
                color: r.met
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        const Spacer(),
        Text(
          '${bn ? toBn(done) : done}/${bn ? toBn(machine.length) : machine.length}'
          ' ${context.t('dawah_req_progress_unit')}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One checklist row: icon + label (+ gold chip for manual checks) +
/// detail + current/target chip.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.row});
  final LevelCheckRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final showChip =
        row.current != null && row.target != null && row.target! > 1;
    final currentText = showChip
        ? bn
              ? toBn(row.current!.clamp(0, row.target!))
              : '${row.current!.clamp(0, row.target!)}'
        : '';
    final targetText = showChip
        ? bn
              ? toBn(row.target!)
              : '${row.target!}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s8,
        vertical: SLSpacing.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(
              row.met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: row.met
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      row.labelBn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: row.met ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (!row.autoChecked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: SLRadius.brPill,
                        ),
                        child: Text(
                          context.t('dawah_req_invigilator_check'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s4),
                Wrap(
                  spacing: SLSpacing.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showChip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: row.met
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: SLRadius.brPill,
                        ),
                        child: Text(
                          '$currentText/$targetText',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: row.met
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Text(
                      row.detailBn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Success ("all met") / automation hint cards.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard._({
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.message,
  });

  factory _OutcomeCard.success(BuildContext context, String message) {
    final theme = Theme.of(context);
    return _OutcomeCard._(
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer,
      icon: Icons.emoji_events,
      message: message,
    );
  }

  factory _OutcomeCard.hint(BuildContext context, String message) {
    final theme = Theme.of(context);
    return _OutcomeCard._(
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      icon: Icons.auto_awesome,
      message: message,
    );
  }

  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SLSpacing.s12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: SLRadius.brLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
