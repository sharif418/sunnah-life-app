/// আসন্ন কুইজ (AMOL-17) — live quizzes the Foundation scheduled as programs
/// (LiveProgram.quizId). Each card says WHEN in plain Bengali ("আজ · রাত
/// ৮:৩০", "৩ দিন পর"), and offers the one action that fits the moment:
/// live → join the usrah room; upcoming → a reminder, plus practising the
/// same quiz alone beforehand.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show liveProvider;
import '../shared/widgets.dart';

/// Scheduled quizzes that are live now or still ahead (live first, then
/// soonest). Empty offline — the sections hide.
final upcomingQuizzesProvider = Provider<List<LiveProgramItem>>((ref) {
  final programs = ref.watch(liveProvider).valueOrNull ?? const [];
  return [
    for (final p in programs)
      if ((p.quizId ?? '').isNotEmpty && p.status != 'past') p,
  ]..sort((a, b) {
    if (a.status != b.status) return a.status == 'live' ? -1 : 1;
    return a.startsAt.compareTo(b.startsAt);
  });
});

/// "আজ · রাত ৮:৩০" / "আগামীকাল · …" / "৩ দিন পর · …" from [iso] vs [now].
String quizWhen(BuildContext context, String iso, DateTime now) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return iso;
  final bn = context.isBn;
  final days = DateTime(t.year, t.month, t.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  final day = switch (days) {
    <= 0 => context.t('quiz_today'),
    1 => context.t('quiz_tomorrow'),
    _ => context.t('quiz_in_days').replaceAll('%n%', bn ? toBn(days) : '$days'),
  };
  return '$day · ${formatTimeBn(t.hour * 60.0 + t.minute, bengali: bn)}';
}

/// The section: a header and one card per scheduled quiz; nothing at all
/// when none is scheduled. [limit] keeps the diary's version to the next one.
class UpcomingQuizzesSection extends ConsumerWidget {
  const UpcomingQuizzesSection({super.key, this.limit, this.now});
  final int? limit;

  /// Clock override for tests/renders.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var list = ref.watch(upcomingQuizzesProvider);
    if (list.isEmpty) return const SizedBox.shrink();
    if (limit != null && list.length > limit!) list = list.sublist(0, limit);
    return Column(
      key: const ValueKey('upcoming_quizzes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(context.t('quiz_upcoming'), icon: PhosphorIconsRegular.calendarBlank),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: SLSpacing.s8),
            child: UpcomingQuizCard(program: p, now: now ?? DateTime.now()),
          ),
      ],
    );
  }
}

class UpcomingQuizCard extends ConsumerWidget {
  const UpcomingQuizCard({super.key, required this.program, required this.now});
  final LiveProgramItem program;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final live = program.status == 'live';
    final inUsrah = ref.watch(authProvider).userOrNull?.usrahId != null;

    return AppCard(
      key: ValueKey('upcoming_quiz_${program.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: live ? cs.error : cs.primaryContainer,
                  borderRadius: SLRadius.brMd,
                ),
                child: Icon(
                  live ? PhosphorIconsFill.broadcast : PhosphorIconsRegular.question,
                  size: 20,
                  color: live ? cs.onError : cs.primary,
                ),
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.titleBn,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      live ? context.t('quiz_live_now') : quizWhen(context, program.startsAt, now),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: live ? cs.error : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((program.hostName ?? '').isNotEmpty)
                      Text(
                        program.hostName!,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s12),
          Wrap(
            spacing: SLSpacing.s8,
            runSpacing: SLSpacing.s8,
            children: [
              if (live && inUsrah)
                FilledButton.icon(
                  key: ValueKey('upcoming_quiz_join_${program.id}'),
                  icon: const Icon(PhosphorIconsFill.broadcast, size: 18),
                  label: Text(context.t('quiz_join_live')),
                  onPressed: () => context.push('/ilm/live-quiz'),
                )
              else if (!live)
                OutlinedButton.icon(
                  icon: const Icon(PhosphorIconsRegular.bell, size: 18),
                  label: Text(context.t('live_notify')),
                  onPressed: () => _remind(context, ref),
                ),
              TextButton.icon(
                key: ValueKey('upcoming_quiz_practice_${program.id}'),
                icon: const Icon(PhosphorIconsRegular.play, size: 18),
                label: Text(context.t('quiz_practice')),
                onPressed: () => context.push('/ilm/quizzes/${program.quizId}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _remind(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiProvider).notifyLive(program.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('live_will_remind'))),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
