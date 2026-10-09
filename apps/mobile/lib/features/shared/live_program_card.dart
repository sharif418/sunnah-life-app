/// One live program, the same card on Home and on the লাইভ screen
/// (2026-10-07): a calendar tile (the date, or a red লাইভ tile while it
/// streams), the status chip, the title, the host and the time with how far
/// off it is (আজ / আগামীকাল / ৩ দিন পর), then the one action that fits —
/// watch the stream, join the live quiz, watch the recording, or be
/// reminded.
library;

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import 'widgets.dart';

/// Asks the server to remind the member before [id] starts; says so in a
/// snackbar either way.
Future<void> requestLiveReminder(
  BuildContext context,
  ApiClient api,
  String id,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = context.t('live_will_remind');
  try {
    await api.notifyLive(id);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class LiveProgramCard extends StatelessWidget {
  const LiveProgramCard({
    super.key,
    required this.program,
    this.statusLabel,
    this.onTap,
    this.onRemind,
    this.onJoinQuiz,
    this.chipKey,
    this.watchKey,
    this.now,
  });

  final LiveProgramItem program;

  /// The chip's words; defaults to এখন লাইভ / আসছে / সমাপ্ত.
  final String? statusLabel;
  final VoidCallback? onTap;

  /// Upcoming programs only: the মনে করিয়ে দিন button.
  final VoidCallback? onRemind;

  /// A live program with a quiz: the usrah quiz room.
  final VoidCallback? onJoinQuiz;
  final Key? chipKey;
  final Key? watchKey;

  /// For tests; the relative day is counted from here.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final p = program;
    final isLive = p.status == 'live';
    final isPast = p.status == 'past';
    final t = DateTime.tryParse(p.startsAt)?.toLocal();
    final goldInk = theme.brightness == Brightness.dark
        ? SLColors.darkGoldText
        : SLColors.lightGoldText;

    String n(int v) => bn ? toBn(v) : '$v';

    // how far off: আজ / আগামীকাল / N দিন পর (a week at most)
    String? relative;
    if (t != null && !isPast && !isLive) {
      final today = now ?? DateTime.now();
      final days = DateTime(
        t.year,
        t.month,
        t.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
      relative = switch (days) {
        0 => context.t('live_today'),
        1 => context.t('live_tomorrow'),
        > 1 && < 7 => context.t('live_in_days_fmt').replaceAll('%n', n(days)),
        _ => null,
      };
    }

    final (Color chipBg, Color chipFg) = isLive
        ? (cs.error, cs.onError)
        : isPast
        ? (cs.surfaceContainerHighest, cs.onSurfaceVariant)
        : (SLColors.gold.withValues(alpha: 0.18), goldInk);

    Widget chip(String label, Color bg, Color fg, {Key? key, Widget? lead}) =>
        Container(
          key: key,
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s8,
            vertical: 2,
          ),
          decoration: BoxDecoration(color: bg, borderRadius: SLRadius.brPill),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 4)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );

    Widget meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: SLSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: SLSpacing.s4),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    final watchUrl = isPast || isLive
        ? livePlaybackUrl(
            youtubeId: p.youtubeId,
            recordingUrl: isPast ? p.recordingUrl : null,
          )
        : null;

    Future<void> watch(String url) async {
      final opened = await openExternalApp(url);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('donation_open_failed'))),
        );
      }
    }

    final actions = <Widget>[
      if (watchUrl != null && isLive)
        FilledButton.icon(
          key: watchKey ?? ValueKey('live_watch_${p.id}'),
          icon: const Icon(PhosphorIconsFill.broadcast, size: 18),
          label: Text(context.t('live_watch_now')),
          onPressed: () => watch(watchUrl),
        )
      else if (watchUrl != null)
        FilledButton.tonalIcon(
          key: watchKey ?? ValueKey('live_watch_${p.id}'),
          icon: const Icon(PhosphorIconsRegular.playCircle, size: 18),
          label: Text(context.t('live_watch_recording')),
          onPressed: () => watch(watchUrl),
        ),
      if (isLive && (p.quizId ?? '').isNotEmpty && onJoinQuiz != null)
        FilledButton.icon(
          key: ValueKey('live_quiz_join_${p.id}'),
          icon: const Icon(PhosphorIconsRegular.question, size: 18),
          label: Text(context.t('quiz_join_live')),
          onPressed: onJoinQuiz,
        ),
      if (p.status == 'upcoming' && onRemind != null)
        OutlinedButton.icon(
          key: ValueKey('live_remind_${p.id}'),
          icon: const Icon(PhosphorIconsRegular.bell, size: 18),
          label: Text(context.t('live_notify')),
          onPressed: onRemind,
        ),
    ];

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SLSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateTile(time: t, live: isLive, past: isPast),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: SLSpacing.s4,
                      runSpacing: SLSpacing.s4,
                      children: [
                        chip(
                          statusLabel ??
                              context.t(
                                isLive
                                    ? 'live_now'
                                    : isPast
                                    ? 'live_past'
                                    : 'live_upcoming',
                              ),
                          chipBg,
                          chipFg,
                          key: chipKey,
                          lead: isLive
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: cs.onError,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                        if ((p.quizId ?? '').isNotEmpty)
                          chip(
                            context.t('ilm_live_quiz'),
                            cs.primaryContainer,
                            cs.onPrimaryContainer,
                          ),
                        if (p.gender == Gender.f)
                          chip(
                            context.t('live_sisters_only'),
                            cs.tertiaryContainer,
                            cs.onTertiaryContainer,
                          ),
                      ],
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      p.titleBn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (p.hostName?.isNotEmpty ?? false)
                      meta(PhosphorIconsRegular.userSound, p.hostName!),
                    if (t != null && !isLive)
                      meta(
                        PhosphorIconsRegular.clock,
                        [
                          formatTimeBn(t.hour * 60.0 + t.minute, bengali: bn),
                          ?relative,
                        ].join(' · '),
                      ),
                  ],
                ),
              ),
            ],
          ),
          for (final a in actions) ...[
            const SizedBox(height: SLSpacing.s8),
            SizedBox(height: SLSpacing.minTapTarget, child: a),
          ],
        ],
      ),
    );
  }
}

/// The calendar tile: day + month, or a red লাইভ tile while it streams.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.time, required this.live, required this.past});

  final DateTime? time;
  final bool live;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final (Color bg, Color fg) = live
        ? (cs.error, cs.onError)
        : past
        ? (cs.surfaceContainerHighest, cs.onSurfaceVariant)
        : (cs.primaryContainer, cs.onPrimaryContainer);
    final t = time;
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s4,
        vertical: SLSpacing.s8,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: SLRadius.brMd),
      child: live || t == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsFill.broadcast, size: 24, color: fg),
                const SizedBox(height: 2),
                FittedBox(
                  child: Text(
                    context.t('live_badge'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    bn ? toBn(t.day) : '${t.day}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                FittedBox(
                  child: Text(
                    context.t('month_${t.month}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
