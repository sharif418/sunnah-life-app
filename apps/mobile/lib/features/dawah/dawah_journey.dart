/// দাওয়াত overview — the member's tarbiyah journey at a glance (joined →
/// মুহিব্বুস সুন্নাহ → ফরযে আইন) and the usrah head's latest weekly comment,
/// the two things a da'ee opens this tab to see.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show reviewsProvider;
import '../shared/widgets.dart';

/// Three steps with the current one marked, then this level's progress:
/// months at the level and how many requirements are met.
class LevelJourneyCard extends StatelessWidget {
  const LevelJourneyCard({
    super.key,
    required this.level,
    required this.nextLevel,
    required this.monthsInLevel,
    required this.requirementsMet,
    required this.requirementsTotal,
  });

  final Level level;
  final Level nextLevel;
  final int monthsInLevel;
  final int requirementsMet;
  final int requirementsTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';

    // 0 = joined, 1 = মুহিব্বুস সুন্নাহ, 2 = ফরযে আইন (either category)
    final step = switch (level) {
      Level.none => 0,
      Level.muhibbusSunnah => 1,
      _ => 2,
    };
    final farzeLabel = level == Level.farzeAin1 || level == Level.farzeAin2
        ? context.t(level.labelKey)
        : context.t('journey_farze_ain');
    final steps = [
      context.t('journey_joined'),
      context.t(Level.muhibbusSunnah.labelKey),
      farzeLabel,
    ];
    final pct = requirementsTotal == 0
        ? 0.0
        : requirementsMet / requirementsTotal;

    return AppCard(
      key: const ValueKey('dawah_journey_card'),
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 17),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          borderRadius: SLRadius.brPill,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 84,
                  child: _JourneyStep(
                    label: steps[i],
                    state: i < step
                        ? _StepState.done
                        : (i == step ? _StepState.current : _StepState.next),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: SLSpacing.s16),
          Row(
            children: [
              Expanded(
                child: Text(
                  context
                      .t('journey_months')
                      .replaceAll('%n%', n(monthsInLevel)),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                context
                    .t('journey_reqs_met')
                    .replaceAll('%done%', n(requirementsMet))
                    .replaceAll('%total%', n(requirementsTotal)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          ClipRRect(
            borderRadius: SLRadius.brPill,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              color: theme.colorScheme.tertiary,
            ),
          ),
          if (nextLevel != level) ...[
            const SizedBox(height: SLSpacing.s8),
            Text(
              '${context.t('dawah_next_level')}: ${context.t(nextLevel.labelKey)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, current, next }

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({required this.label, required this.state});
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = switch (state) {
      _StepState.done => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          PhosphorIconsRegular.check,
          size: 18,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      _StepState.current => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          PhosphorIconsFill.star,
          size: 18,
          color: theme.colorScheme.onTertiary,
        ),
      ),
      _StepState.next => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outline, width: 2),
        ),
        child: Icon(
          PhosphorIconsRegular.graduationCap,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    };
    return Column(
      children: [
        mark,
        const SizedBox(height: SLSpacing.s4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 3,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: state == _StepState.current
                ? FontWeight.w700
                : FontWeight.w500,
            color: state == _StepState.next
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// The usrah head's latest weekly comment to this member — members never saw
/// these outside the রিভিউ tab before.
class LatestReviewCard extends StatelessWidget {
  const LatestReviewCard({super.key, required this.review, this.onSeeAll});
  final WeeklyReview review;

  /// Opens the full review list (the দাওয়াত রিভিউ tab); null = not tappable.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      key: const ValueKey('dawah_latest_review'),
      onTap: onSeeAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.chatCircle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  context.t('review_latest_title'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          Text(review.comment ?? '', style: theme.textTheme.bodyLarge),
          if ((review.nextGoals ?? '').isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${context.t('review_next_goals')}: ${review.nextGoals}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s8),
          Text(
            [
              review.reviewerName,
              context.isBn ? toBn(review.weekStart) : review.weekStart,
            ].whereType<String>().join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The newest weekly review with a comment, written FOR the signed-in member
/// (GET /api/reviews returns a member's own reviews — any role).
WeeklyReview? latestReviewFor(WidgetRef ref) {
  final me = ref.watch(authProvider).userOrNull?.id;
  if (me == null) return null;
  final reviews = ref.watch(reviewsProvider).valueOrNull?.data ?? const [];
  final mine = [
    for (final r in reviews)
      if (r.userId == me && (r.comment ?? '').trim().isNotEmpty) r,
  ]..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  return mine.isEmpty ? null : mine.first;
}
