/// লাইভ প্রোগ্রাম — চলমান → আসন্ন → পূর্ববর্তী, always all three (LIVE-01..03):
/// a live program gets 'লাইভ দেখুন', a past one 'রেকর্ডিং দেখুন' (YouTube app,
/// falling back to the browser); an empty section says so in words ("এখন
/// কোনো লাইভ কার্যক্রম নেই"); upcoming ones keep the remind-me action and a
/// gender-scoped visibility note. Times are Bengali (৩ অক্টোবর · রাত ৮:৩০).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/live_program_card.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_live')),
      ),
      body: async.when(
        loading: () => const Skeleton(height: 84, count: 4),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s24),
            ErrorState(
              message: e is ApiException
                  ? e.message
                  : context.t('not_available_offline'),
              onRetry: () => ref.invalidate(liveProvider),
            ),
          ],
        ),
        data: (programs) {
          Widget section(
            String title,
            IconData icon,
            List<LiveProgramItem> list, {
            required String emptyKey,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title, icon: icon),
                // full width, like the program cards around it
                if (list.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: AppCard(
                      child: Text(
                        context.t(emptyKey),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                    child: LiveProgramCard(
                      program: p,
                      onRemind: () => requestLiveReminder(
                        context,
                        ref.read(apiProvider),
                        p.id,
                      ),
                      onJoinQuiz: () => context.push('/ilm/live-quiz'),
                    ),
                  ),
                const SizedBox(height: SLSpacing.s4),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              section(
                context.t('live_now'),
                PhosphorIconsRegular.broadcast,
                programs.where((p) => p.status == 'live').toList(),
                emptyKey: 'live_none_now',
              ),
              section(
                context.t('live_upcoming'),
                PhosphorIconsRegular.calendarBlank,
                programs.where((p) => p.status == 'upcoming').toList()
                  ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
                emptyKey: 'live_none_upcoming',
              ),
              section(
                context.t('live_past'),
                PhosphorIconsRegular.playCircle,
                programs.where((p) => p.status == 'past').toList()
                  ..sort((a, b) => b.startsAt.compareTo(a.startsAt)),
                emptyKey: 'live_none_past',
              ),
              if (programs.isNotEmpty)
                Center(
                  child: Text(
                    '${bn ? toBn(programs.length) : programs.length} ${context.t('live_programs_count')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
