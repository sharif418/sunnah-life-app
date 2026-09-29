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
  const AppCard({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
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
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: SLSpacing.s8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
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

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});
  final String message;
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
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: SLSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: SLSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SLSpacing.s12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
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
    final fg = dark ? SLColors.darkGoldText : SLColors.goldDeep;
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
          Icon(Icons.wifi_off, size: 16, color: fg),
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

  /// idle / syncing / pending N / dead M (error accent, only when M > 0).
  /// Tapping opens the sync sheet (counts, last sync, dead entries, sync now).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final theme = Theme.of(context);
    final hasDead = sync.dead > 0;
    final hasPending = sync.pending > 0;

    final Widget indicator;
    if (sync.syncing) {
      indicator = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (hasDead) {
      indicator = Icon(
        Icons.cloud_off_outlined,
        size: 18,
        color: theme.colorScheme.error,
      );
    } else if (hasPending) {
      indicator = Icon(
        Icons.cloud_upload_outlined,
        size: 18,
        color: theme.colorScheme.tertiary,
      );
    } else {
      indicator = Icon(
        Icons.check_circle_outline,
        size: 18,
        color: theme.colorScheme.outline,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(SLRadius.sm),
      onTap: () => showSyncSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SLSpacing.s4,
          vertical: SLSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            if (!sync.syncing && (hasDead || hasPending)) ...[
              const SizedBox(width: 4),
              Text(
                '${toBn(hasDead ? sync.dead : sync.pending)}'
                '${hasDead ? ' ${context.t('sync_failed_short')}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasDead ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
