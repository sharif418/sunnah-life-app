/// লাইভ প্রোগ্রাম — চলমান → আসন্ন → পূর্ববর্তী, always all three (LIVE-01..03):
/// a live program gets 'লাইভ দেখুন', a past one 'রেকর্ডিং দেখুন' (YouTube app,
/// falling back to the browser); an empty section says so in words ("এখন
/// কোনো লাইভ কার্যক্রম নেই"); upcoming ones keep the remind-me action and a
/// gender-scoped visibility note. Times are Bengali (৩ অক্টোবর · রাত ৮:৩০).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../core/external_urls.dart';
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
          String when(String iso) {
            final t = DateTime.tryParse(iso)?.toLocal();
            if (t == null) return iso;
            final day = bn ? toBn(t.day) : '${t.day}';
            return '$day ${context.t('month_${t.month}')} · '
                '${formatTimeBn(t.hour * 60.0 + t.minute, bengali: bn)}';
          }

          Widget section(String title, Color color, List<LiveProgramItem> list,
              {bool showTime = true, required String emptyKey}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title, icon: PhosphorIconsRegular.broadcast),
                if (list.isEmpty)
                  AppCard(
                    child: Text(
                      context.t(emptyKey),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                            when(p.startsAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant),
                          ),
                        // LIVE-01 / LIVE-03: watch the stream or recording
                        if (p.status != 'upcoming')
                          for (final url in [
                            livePlaybackUrl(
                              youtubeId: p.youtubeId,
                              recordingUrl: p.status == 'past' ? p.recordingUrl : null,
                            ),
                          ])
                            if (url != null)
                              Padding(
                                padding: const EdgeInsets.only(top: SLSpacing.s8),
                                child: FilledButton.icon(
                                  key: ValueKey('live_watch_${p.id}'),
                                  icon: const Icon(PhosphorIconsFill.broadcast, size: 18),
                                  label: Text(context.t(
                                    p.status == 'live' ? 'live_watch_now' : 'live_watch_recording',
                                  )),
                                  onPressed: () async {
                                    final opened = await openExternalApp(url);
                                    if (!opened && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(context.t('donation_open_failed'))),
                                      );
                                    }
                                  },
                                ),
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
                  showTime: false, emptyKey: 'live_none_now'),
              section(
                  context.t('live_upcoming'), theme.colorScheme.primary,
                  programs.where((p) => p.status == 'upcoming').toList(),
                  emptyKey: 'live_none_upcoming'),
              section(
                  context.t('live_past'), theme.colorScheme.onSurfaceVariant,
                  programs.where((p) => p.status == 'past').toList(),
                  emptyKey: 'live_none_past'),
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
