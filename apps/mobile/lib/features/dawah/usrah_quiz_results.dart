/// সদস্যদের কুইজ ফলাফল — the usrah head's (and invigilator's) view of how the
/// members did in the quizzes. Grouped by QUIZ, not by member: a head asks
/// "who still hasn't taken this one?", so every quiz shows its turnout and
/// average up front, and opens to the members — best score first, then the
/// ones to encourage ("এখনো দেননি").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/remote_state.dart' show usrahQuizResultsProvider;
import '../shared/widgets.dart';

/// The whole section (header + one card per quiz). Hidden for non-supervisors
/// and offline — the provider is null then.
class UsrahQuizResultsSection extends ConsumerWidget {
  const UsrahQuizResultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(usrahQuizResultsProvider).valueOrNull;
    if (data == null || data.quizzes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('usrah_quiz_results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SLSpacing.s12),
        SectionHeader(
          context.t('quizres_title'),
          icon: PhosphorIconsRegular.listChecks,
        ),
        if (data.members.isEmpty)
          EmptyState(
            message: context.t('quizres_no_members'),
            icon: PhosphorIconsRegular.usersThree,
          )
        else ...[
          for (final q in data.quizzes)
            _QuizResultCard(
              quizId: q.id,
              title: q.titleBn,
              members: data.members,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s4),
            child: Text(
              context.t('quizres_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    required this.quizId,
    required this.title,
    required this.members,
  });
  final String quizId;
  final String title;
  final List<MemberQuizResults> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';

    final took = <(MemberQuizResults, MemberQuizResult)>[
      for (final m in members)
        if (m.resultFor(quizId) case final r?) (m, r),
    ]..sort((a, b) => b.$2.percent.compareTo(a.$2.percent));
    final notYet = [
      for (final m in members)
        if (m.resultFor(quizId) == null) m,
    ];
    final avg = took.isEmpty
        ? null
        : (took.fold<int>(0, (s, e) => s + e.$2.percent) / took.length).round();

    final summary = [
      context
          .t('quizres_took')
          .replaceAll('%done%', n(took.length))
          .replaceAll('%total%', n(members.length)),
      if (avg != null) context.t('quizres_avg').replaceAll('%n%', n(avg)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          // no divider lines when the tile opens — the card is the frame
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('quizres_$quizId'),
            tilePadding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
            childrenPadding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              0,
              SLSpacing.s16,
              SLSpacing.s12,
            ),
            title: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: SLSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: members.isEmpty ? 0 : took.length / members.length,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            children: [
              for (final (m, r) in took)
                _MemberLine(
                  name: m.name,
                  trailing: _ScoreChip(result: r),
                  sub: r.attempts > 1
                      ? context
                            .t('quizres_tries')
                            .replaceAll('%n%', n(r.attempts))
                      : null,
                ),
              for (final m in notYet)
                _MemberLine(
                  name: m.name,
                  muted: true,
                  trailing: Text(
                    context.t('quizres_not_yet'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.name,
    required this.trailing,
    this.sub,
    this.muted = false,
  });
  final String name;
  final Widget trailing;
  final String? sub;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SLSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          trailing,
        ],
      ),
    );
  }
}

/// "৯/১০" by band: ≥ 80% a solid primary pill, ≥ 50% gold, below that only
/// an outline in the error ink — a nudge to revise, not a red verdict.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.result});
  final MemberQuizResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final (Color? bg, Color fg) = result.percent >= 80
        ? (cs.primary, cs.onPrimary)
        : result.percent >= 50
        ? (cs.tertiary, cs.onTertiary)
        : (null, cs.error);
    final text = bn
        ? '${toBn(result.best)}/${toBn(result.total)}'
        : '${result.best}/${result.total}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: SLRadius.brPill,
        border: bg == null ? Border.all(color: cs.error, width: 1.5) : null,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
