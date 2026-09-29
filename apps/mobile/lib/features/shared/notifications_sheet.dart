/// Notification panel (C-W4a) — the header bell's bottom sheet.
///
/// API SURFACE HONESTY: there is NO dedicated GET /api/announcements
/// endpoint on the server (checked — announcements exist only inside
/// GET /api/usrah, RLS-scoped to the signed-in member's own usrah, already
/// consumed by `usrahProvider`). So this panel is built strictly from what
/// EXISTS:
///
/// · ঘোষণা section      — usrah announcements via `usrahProvider`
///                        (null while a guest / offline ⇒ section hidden)
/// · লাইভ অনুষ্ঠান section — live + upcoming programs via `liveProvider`
///                        (the same feed /more/live renders)
///
/// Guests see the sign-in hint (web shell parity). Both FutureProviders are
/// watched ONLY inside this sheet — opening the panel is what fetches; the
/// tab screens never pay for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/phosphor_icons.dart';

import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import 'widgets.dart';

Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(
      authProvider.select((s) => s.signedIn),
    );
    final bn = context.isBn;

    Widget body;
    if (!signedIn) {
      body = EmptyState(
        message: context.t('notifications_guest_hint'),
        icon: PhosphorIconsRegular.bellSlash,
      );
    } else {
      final usrahAsync = ref.watch(usrahProvider);
      final liveAsync = ref.watch(liveProvider);
      final announcements = usrahAsync.maybeWhen(
        data: (b) => b?.announcements ?? const [],
        orElse: () => const [],
      );
      final programs = liveAsync.maybeWhen(
        data: (list) => list
            .where((p) => p.status == 'live' || p.status == 'upcoming')
            .take(3)
            .toList(),
        orElse: () => const [],
      );
      if (announcements.isEmpty && programs.isEmpty) {
        body = usrahAsync.hasValue && liveAsync.hasValue
            ? EmptyState(
                message: context.t('notifications_empty'),
                icon: PhosphorIconsRegular.bell,
              )
            : const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
      } else {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (announcements.isNotEmpty) ...[
              SectionHeader(
                context.t('notifications_announcements'),
                icon: PhosphorIconsFill.megaphone,
              ),
              for (final a in announcements.take(10)) _AnnouncementCard(a: a),
            ],
            if (programs.isNotEmpty) ...[
              SectionHeader(
                context.t('notifications_live'),
                icon: PhosphorIconsRegular.broadcast,
              ),
              for (final p in programs) _LiveNoticeCard(p: p, bn: bn),
            ],
            const SizedBox(height: SLSpacing.s8),
          ],
        );
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          0,
          SLSpacing.s16,
          SLSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('header_notifications'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SLSpacing.s4),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.a});
  final Announcement a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (a.pinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: SLRadius.brPill,
                  ),
                  child: Text(
                    context.t('dawah_announcements'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                a.createdAt.substring(0, 10),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            a.body,
            style: theme.textTheme.bodyMedium,
          ),
          if ((a.authorName ?? '').isNotEmpty)
            Text(
              '— ${a.authorName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveNoticeCard extends StatelessWidget {
  const _LiveNoticeCard({required this.p, required this.bn});
  final LiveProgramItem p;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = p.status == 'live';
    final color = isLive ? theme.colorScheme.error : theme.colorScheme.primary;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: SLRadius.brPill,
            ),
            child: Text(
              isLive ? context.t('live_now') : context.t('live_upcoming'),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              p.titleBn,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (!isLive && p.startsAt.length >= 16)
            Text(
              p.startsAt.substring(11, 16),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
