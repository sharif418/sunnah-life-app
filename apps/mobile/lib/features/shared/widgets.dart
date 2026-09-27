/// Shared UI kit: localized `t()` helper + designed states (empty/error/
/// offline), sync badge, section headers, skeletons, cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';

extension L10nX on BuildContext {
  Lang get lang => LangX.fromCode(
    ProviderScope.containerOf(
      this,
      listen: false,
    ).read(profileProvider).language,
  );
  bool get isBn => lang == Lang.bn;
  String t(String key) => S.tr(lang, key);
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
    return Column(
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
    );
  }
}

class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    if (sync.pending == 0 && !sync.syncing) {
      return Icon(
        Icons.check_circle_outline,
        size: 18,
        color: Theme.of(context).colorScheme.outline,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: sync.syncing
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
        ),
        const SizedBox(width: 4),
        Text(
          sync.syncing
              ? '…'
              : '${toBn(sync.pending)} ${context.t('amal_sync_pending')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
