/// লাইভ প্রোগ্রাম — live → upcoming → past sections with a
/// gender-scoped visibility note and a remind-me action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
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
          if (programs.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                EmptyState(
                    message: context.t('empty_generic'),
                    icon: PhosphorIconsRegular.broadcast),
              ],
            );
          }
          Widget section(String title, Color color, List<LiveProgramItem> list,
              {bool showTime = true}) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title, icon: PhosphorIconsRegular.broadcast),
                for (final p in list)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: SLRadius.brPill,
                              ),
                              child: Text(
                                title,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: color),
                              ),
                            ),
                            const Spacer(),
                            if (p.gender == Gender.f)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary
                                      .withValues(alpha: 0.15),
                                  borderRadius: SLRadius.brPill,
                                ),
                                child: Text(
                                  context.t('live_sisters_only'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.tertiary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: SLSpacing.s4),
                        Text(p.titleBn,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (p.hostName?.isNotEmpty ?? false)
                          Text(
                              '${context.t('live_host')}: ${p.hostName}',
                              style: theme.textTheme.bodySmall),
                        if (showTime)
                          Text(
                            '${p.startsAt.substring(0, 16).replaceAll('T', ' ')}${p.endsAt != null ? ' → ${p.endsAt!.substring(11, 16)}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant),
                          ),
                        if (p.status == 'upcoming')
                          Padding(
                            padding: const EdgeInsets.only(top: SLSpacing.s8),
                            child: OutlinedButton.icon(
                              icon: const Icon(PhosphorIconsRegular.bell,
                                  size: 18),
                              label: Text(context.t('live_notify')),
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(apiProvider)
                                      .notifyLive(p.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          context.t('live_will_remind')),
                                    ));
                                  }
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(e.message),
                                    ));
                                  }
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: SLSpacing.s8),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              section(
                  context.t('live_now'), theme.colorScheme.error,
                  programs.where((p) => p.status == 'live').toList(),
                  showTime: false),
              section(
                  context.t('live_upcoming'), theme.colorScheme.primary,
                  programs.where((p) => p.status == 'upcoming').toList()),
              section(
                  context.t('live_past'), theme.colorScheme.outline,
                  programs.where((p) => p.status == 'past').toList()),
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
