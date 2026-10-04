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
/// · নামাজ (NAV-03)     — the current waqt, the next one and its time, and a
///                        warning while a forbidden window is on (everyone,
///                        guests included — it needs no account)
/// · আপনার জন্য section — the member's own messages (weekly review, goal
///                        decision, assessment result, level-up, broadcast)
///                        via `inboxProvider` (GET /api/reminders, message
///                        kinds only); tapping one marks it read and opens
///                        the screen it is about
///
/// Guests see the sign-in hint (web shell parity). Both FutureProviders are
/// watched ONLY inside this sheet — opening the panel is what fetches; the
/// tab screens never pay for it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/phosphor_icons.dart';

import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../state/prayer_state.dart';
import 'when_bn.dart';
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

    final foundation = (ref.watch(foundationAnnouncementsProvider).valueOrNull ?? const [])
        .take(5)
        .toList();
    Widget foundationSection() => foundation.isEmpty
        ? const SizedBox.shrink()
        : Column(
            key: const ValueKey('notif_foundation'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                context.t('notifications_foundation'),
                icon: PhosphorIconsRegular.megaphone,
              ),
              for (final a in foundation) _AnnouncementCard(a: a),
            ],
          );

    Widget body;
    if (!signedIn) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PrayerAlertCard(),
          foundationSection(),
          EmptyState(
            message: context.t('notifications_guest_hint'),
            icon: PhosphorIconsRegular.bellSlash,
          ),
        ],
      );
    } else {
      final usrahAsync = ref.watch(usrahProvider);
      final liveAsync = ref.watch(liveProvider);
      final inbox = (ref.watch(inboxProvider).valueOrNull ?? const []).take(15).toList();
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
      if (announcements.isEmpty && programs.isEmpty && inbox.isEmpty && foundation.isEmpty) {
        // the prayer alert stays even when there is nothing else to say
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PrayerAlertCard(),
            usrahAsync.hasValue && liveAsync.hasValue
                ? EmptyState(
                    message: context.t('notifications_empty'),
                    icon: PhosphorIconsRegular.bell,
                  )
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ],
        );
      } else {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PrayerAlertCard(),
            if (inbox.isNotEmpty) ...[
              SectionHeader(
                context.t('notifications_for_you'),
                icon: PhosphorIconsRegular.userCircle,
              ),
              for (final r in inbox) _InboxCard(r: r),
            ],
            foundationSection(),
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

/// NAV-03: "এখন আসর · পরবর্তী মাগরিব — বিকাল ৫:৪২", and the forbidden-time
/// warning while one is on. Minute granularity (the provider ticks per
/// second; the select keeps this card still between minutes).
class _PrayerAlertCard extends ConsumerWidget {
  const _PrayerAlertCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(
      prayerProvider.select(
        (p) => p == null
            ? null
            : (
                current: p.currentWaqt,
                next: p.nextKey,
                nextAt: p.times.byKey(p.nextKey),
                forbidden: p.forbiddenLabel,
                mins: p.minutesToNext.floor(),
              ),
      ),
    );
    if (s == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final left = s.mins >= 60
        ? '${bn ? toBn(s.mins ~/ 60) : s.mins ~/ 60} ${context.t('notif_hours')} '
              '${bn ? toBn(s.mins % 60) : s.mins % 60} ${context.t('notif_minutes')}'
        : '${bn ? toBn(s.mins) : s.mins} ${context.t('notif_minutes')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        key: const ValueKey('notif_prayer_alert'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.mosque, size: 22, color: cs.primary),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    '${context.t('notif_now')}: ${context.t('waqt_${s.current.name}')}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${context.t('notif_next')}: ${context.t('waqt_${s.next.name}')} — '
              '${formatTimeBn(s.nextAt, bengali: bn)} ($left ${context.t('notif_left')})',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (s.forbidden != null) ...[
              const SizedBox(height: SLSpacing.s8),
              Row(
                children: [
                  Icon(PhosphorIconsRegular.prohibit, size: 18, color: cs.error),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Text(
                      '${context.t('prayer_forbidden_times')} · ${context.t('prayer_forbidden_${s.forbidden}')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One personal message. Unread = bold title + a dot; tap = mark read and go
/// to the screen it concerns.
class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.r});
  final ReminderItem r;

  (IconData, String?) get _look => switch (r.kind) {
    'review' => (PhosphorIconsRegular.chatCircle, '/dawah'),
    'goal' => (PhosphorIconsRegular.flagBanner, '/amal/goals'),
    'assessment' => (PhosphorIconsRegular.sealCheck, '/dawah'),
    'masala' => (PhosphorIconsRegular.question, '/more/masala'),
    _ => (PhosphorIconsRegular.megaphone, null),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, route) = _look;
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        key: ValueKey('inbox_${r.id}'),
        onTap: () async {
          if (!r.read) {
            try {
              await ref.read(apiProvider).readReminder(r.id);
              ref.invalidate(inboxProvider);
            } on ApiException {
              // offline — it stays unread, the navigation still happens
            }
          }
          if (route != null && context.mounted) {
            Navigator.of(context).pop();
            context.push(route);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: r.read ? cs.onSurfaceVariant : cs.primary),
            const SizedBox(width: SLSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: r.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if ((r.body ?? '').isNotEmpty)
                    Text(
                      r.body!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  Text(
                    whenBn(context, r.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!r.read)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: SLSpacing.s8),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
                ),
              ),
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
                whenBn(context, a.createdAt),
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
          if (!isLive)
            Text(
              // the API sends UTC — the old substring showed the UTC clock
              whenBn(context, p.startsAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
