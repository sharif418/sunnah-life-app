/// Shared UI kit: localized `t()` helper + designed states (empty/error/
/// offline), sync badge, section headers, skeletons, cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/sync_policy.dart' show formatAgoBn;
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';
import 'sync_sheet.dart';
import '../../design/phosphor_icons.dart';
import 'state_illustrations.dart';

extension L10nX on BuildContext {
  Lang get lang => LangX.fromCode(
    ProviderScope.containerOf(
      this,
      listen: false,
    ).read(profileProvider).language,
  );
  bool get isBn => lang == Lang.bn;
  String t(String key) => S.tOf(this, lang, key);
}

/// Direction-aware icon: glyphs that imply reading direction (chevrons,
/// arrows) mirror automatically under RTL. Prefer logical layout over this
/// where possible.
class DirectionalIcon extends StatelessWidget {
  const DirectionalIcon(this.icon, {super.key, this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: size, color: color);
    if (Directionality.maybeOf(context) == TextDirection.rtl) {
      return Transform.flip(flipX: true, child: child);
    }
    return child;
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Clip the content to the rounded shape — for cards whose children paint
  /// edge-to-edge backgrounds (a tinted footer strip would otherwise show
  /// square corners past the rounded rim).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brLg,
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: SLSpacing.s16,
                vertical: SLSpacing.s12,
              ),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.icon});
  final String title;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SLSpacing.s4,
        SLSpacing.s16,
        SLSpacing.s4,
        SLSpacing.s8,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: SLSpacing.s8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Illustrated empty state (W4f): a soft rounded vignette — an open-book
/// cradle under gold khatam sparks, the texture.dart lattice language —
/// with the caller's glyph in a calm chip, message below, optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.title,
  });
  final String message;
  final IconData? icon;

  /// Optional bold line above the (muted) message.
  final String? title;

  /// Optional CTA (e.g. "নতুন জিজ্ঞাসা করুন") — rendered as the filled primary button
  /// below the message only when BOTH label and callback are present.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyIllustration(icon: icon),
            const SizedBox(height: SLSpacing.s16),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s4),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SLSpacing.s12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Illustrated error state (W4f): the CALM variant of the alert idiom — an
/// alert-soft vignette (#FCE4E4 light / darkAlertSoft dark) with an
/// open-ring motif and an alert-tinted icon chip (#C0392B / darkAlert),
/// never a saturated red flood. Message + retry below.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.icon});
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorIllustration(icon: icon),
            const SizedBox(height: SLSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SLSpacing.s12),
              // the one way forward, so the filled primary (an outline
              // on cream barely read as a button)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                label: Text(context.t('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Subtle offline strip (W4-fix4) shown above cache-served content:
/// "অফলাইন · সর্বশেষ হালনাগাদ: ৫ মিনিট আগে". Calm gold-on-cream — the
/// information is "this is a snapshot", never a red alarm.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.fetchedAt, this.now});

  /// When the shown snapshot last came over the network.
  final DateTime fetchedAt;

  /// Injectable clock — goldens pin it so the ago-label never drifts.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? SLColors.darkGoldSoft : SLColors.goldSoftLight;
    final fg = dark ? SLColors.darkGoldText : SLColors.lightGoldText;
    final ago = formatAgoBn(
      (now ?? DateTime.now()).difference(fetchedAt),
      bengali: bn,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: SLSpacing.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s12,
        vertical: SLSpacing.s8,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: SLRadius.brMd),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.wifiSlash, size: 16, color: fg),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              '${context.t('offline_banner')} · '
              '${context.t('last_updated')}: $ago',
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 80, this.count = 3});
  final double height;
  final int count;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scroll-safe: at large text scales (1.3×) the fixed-height rows can
    // exceed a short viewport — the skeleton must never overflow while the
    // real content is on its way.
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: List.generate(widget.count, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SLSpacing.s12),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final opacity = 0.35 + 0.3 * _controller.value;
                return Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: opacity,
                    ),
                    borderRadius: SLRadius.brLg,
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  /// syncing / pending N / dead M (error accent); nothing while idle.
  /// Tapping opens the sync sheet (counts, last sync, dead entries, sync now).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    // A guest's diary lives on the phone by design and never uploads — a
    // pending count there is permanent noise (it appeared a moment after
    // launch, once the outbox count loaded). The badge is for members only.
    if (!ref.watch(authProvider.select((a) => a.signedIn))) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final hasDead = sync.dead > 0;
    // Quiet unless the member should know: entries that could not be saved
    // (red), or entries waiting because the last upload did not go through
    // (offline). An ordinary upload after a tick takes a moment and used to
    // flash a spinner and a bare number by the profile — read as a fault.
    final hasPending = sync.pending > 0 && sync.stalled;
    if (!hasDead && !hasPending) {
      return const SizedBox.shrink();
    }

    final Widget indicator;
    if (sync.syncing) {
      indicator = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (hasDead) {
      indicator = Icon(
        PhosphorIconsRegular.cloudSlash,
        size: 18,
        color: theme.colorScheme.error,
      );
    } else {
      indicator = Icon(
        PhosphorIconsRegular.cloudArrowUp,
        size: 18,
        color: theme.colorScheme.tertiary,
      );
    }

    final count = hasDead ? sync.dead : sync.pending;
    return Semantics(
      button: true,
      label: context
          .t(hasDead ? 'sync_badge_failed_a11y' : 'sync_badge_waiting_a11y')
          .replaceAll('%n', toBn(count)),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(SLRadius.sm),
        onTap: () => showSyncSheet(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator,
                if (!sync.syncing) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${toBn(count)} '
                    '${context.t(hasDead ? 'sync_failed_short' : 'sync_waiting_short')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasDead ? theme.colorScheme.error : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The item a search result opened: framed in green under a "খোঁজা ফল"
/// label, shown first in its list.
class SearchHitFrame extends StatelessWidget {
  const SearchHitFrame({super.key, required this.hit, required this.child});
  final bool hit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hit) return child;
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('search_hit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 14,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                context.t('search_hit_label'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: SLRadius.brLg,
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// A card of menu rows — the list style of the More tab, also used by the
/// Ilm hub (2026-10-09: one pattern for "where do I go": a heading, then
/// full-width rows; easier to read and to hit than a grid of small tiles,
/// especially at large text sizes).
class MenuGroupCard extends StatelessWidget {
  const MenuGroupCard({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16 + 40 + SLSpacing.s12,
                endIndent: SLSpacing.s16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One menu row: the icon in a soft square, the name, a one-line hint of
/// what is inside, an optional "নতুন" badge, and a chevron. The WHOLE row
/// is the tap target (60dp+); the name and hint wrap rather than cut.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s16,
            vertical: SLSpacing.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: SLRadius.brMd,
                ),
                child: Icon(icon, size: 22, color: cs.primary),
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle?.isNotEmpty ?? false)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: SLSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: SLRadius.brPill,
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: SLSpacing.s4),
              DirectionalIcon(
                PhosphorIconsRegular.caretRight,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
