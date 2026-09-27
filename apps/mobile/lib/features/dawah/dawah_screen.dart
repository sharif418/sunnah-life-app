/// দাওয়াত — the Tarbiyah engine hub: member code + referral link + share,
/// madu tree, level + requirements + assessments, my usrah + announcements,
/// weekly review history. Gated to roles daee/usrah_head/invigilator/full_admin.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../services/platform_channels.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';

class DawahScreen extends ConsumerWidget {
  const DawahScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    Widget body;
    if (auth.status == AuthStatus.loading) {
      body = const Skeleton(height: 72, count: 5);
    } else if (!auth.signedIn) {
      body = _Gate(
        icon: Icons.login,
        message: context.t('dawah_signin_needed'),
        actionLabel: context.t('onb_signin'),
        onAction: () => context.push('/auth'),
      );
    } else if (!(auth.user?.canSeeDawah ?? false)) {
      body = _Gate(
        icon: Icons.campaign_outlined,
        message: context.t('dawah_role_needed'),
      );
    } else {
      body = const _DawahTabs();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('dawah_gate_title')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: SLSpacing.s8),
            child: SyncBadge(),
          ),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
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
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: SLSpacing.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SLSpacing.s16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DawahTabs extends ConsumerWidget {
  const _DawahTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'দাওয়াত'),
              Tab(text: 'উসরা'),
              Tab(text: 'রিভিউ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_DawahOverviewTab(), _UsrahTab(), _ReviewsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: overview ──────────────────────────────────────────────────────────

class _DawahOverviewTab extends ConsumerWidget {
  const _DawahOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dawahProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;

    return async.when(
      loading: () => const Skeleton(height: 72, count: 5),
      error: (e, _) => ListView(
        children: [
          const SizedBox(height: SLSpacing.s24),
          ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(dawahProvider),
          ),
        ],
      ),
      data: (overview) {
        if (overview == null) {
          return ListView(
            children: [
              const SizedBox(height: SLSpacing.s24),
              ErrorState(
                message: context.t('not_available_offline'),
                onRetry: () => ref.invalidate(dawahProvider),
              ),
            ],
          );
        }

        String joinLink(String code) => 'https://sunnahlife.app/join/$code';

        return ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            // Member code + referral
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('dawah_member_code'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          overview.memberCode,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('copy'),
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: overview.memberCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.t('copied'))),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  Text(
                    context.t('dawah_referral'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          joinLink(overview.memberCode),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('share'),
                        icon: const Icon(Icons.share),
                        onPressed: () async {
                          final text =
                              'আসসালামু আলাইকুম। সুন্নাহ লাইফ অ্যাপে আমার সাথে যুক্ত হোন: ${joinLink(overview.memberCode)}';
                          await Clipboard.setData(ClipboardData(text: text));
                          await SystemChannel.shareText(text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${context.t('copied')} — ${context.t('share')}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s12),

            // Stats row
            Row(
              children: [
                _StatCell(
                  label: context.t('dawah_invited'),
                  value:
                      '${bn ? toBn(overview.invitedCount) : overview.invitedCount}',
                ),
                _StatCell(
                  label: context.t('dawah_my_level'),
                  value: overview.level.labelBn,
                ),
                _StatCell(
                  label: context.t('dawah_months_in_level'),
                  value:
                      '${bn ? toBn(overview.monthsInLevel) : overview.monthsInLevel}',
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s12),

            // Requirements checklist
            SectionHeader(
              context.t('dawah_requirements'),
              icon: Icons.checklist,
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < overview.requirements.length; i++)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        overview.requirements[i].done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: overview.requirements[i].done
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      title: Text(overview.requirements[i].label),
                      subtitle: Text(overview.requirements[i].detail),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              '${context.t('dawah_next_level')}: ${overview.nextLevel.labelBn}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // Madu tree
            SectionHeader(context.t('dawah_madu'), icon: Icons.account_tree),
            if (overview.downline.isEmpty)
              EmptyState(
                message: overview.level == Level.none
                    ? context.t('dawah_level_none_next')
                    : context.t('empty_generic'),
                icon: Icons.park_outlined,
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final node in overview.downline)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsetsDirectional.only(
                          start: SLSpacing.s12 + (node.depth - 1) * 24,
                          end: SLSpacing.s12,
                        ),
                        leading: Icon(
                          node.depth == 1
                              ? Icons.person_outline
                              : Icons.subdirectory_arrow_right,
                          color: theme.colorScheme.primary,
                          size: node.depth == 1 ? 24 : 18,
                        ),
                        title: Text(node.name),
                        subtitle: Text(
                          '${node.memberCode ?? ''} · ${node.level.labelBn}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),

            // Assessments
            SectionHeader(
              context.t('dawah_assessments'),
              icon: Icons.fact_check_outlined,
            ),
            if (overview.assessments.isEmpty)
              EmptyState(message: context.t('empty_generic'))
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final a in overview.assessments)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          a.result == 'passed'
                              ? Icons.verified
                              : Icons.timelapse,
                          color: a.result == 'passed'
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                        title: Text(a.templateKey),
                        subtitle: Text(a.createdAt.substring(0, 10)),
                        trailing: a.scorePct == null
                            ? null
                            : Text(
                                '${bn ? toBn(a.scorePct!) : a.scorePct}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: a.result == 'passed'
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.tertiary,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: SLSpacing.s24),
          ],
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: SLSpacing.s8),
        child: Container(
          padding: const EdgeInsets.all(SLSpacing.s12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: SLRadius.brMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 2: usrah ─────────────────────────────────────────────────────────────

class _UsrahTab extends ConsumerWidget {
  const _UsrahTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usrahProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;

    return async.when(
      loading: () => const Skeleton(height: 72, count: 5),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(usrahProvider),
      ),
      data: (bundle) {
        if (bundle == null) {
          return ListView(
            children: [
              const SizedBox(height: SLSpacing.s24),
              ErrorState(
                message: context.t('not_available_offline'),
                onRetry: () => ref.invalidate(usrahProvider),
              ),
            ],
          );
        }
        final usrah = bundle.usrah;
        return ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            if (usrah == null) ...[
              const SizedBox(height: SLSpacing.s24),
              EmptyState(
                message: 'আপনি এখনো কোনো উসরায় যুক্ত নন — অ্যাডমিন যুক্ত করলে এখানে দেখা যাবে',
                icon: Icons.groups_outlined,
              ),
            ] else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups, color: theme.colorScheme.primary),
                        const SizedBox(width: SLSpacing.s8),
                        Expanded(
                          child: Text(
                            usrah.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${bn ? toBn(usrah.members.length) : usrah.members.length} ${context.t('dawah_members')}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (usrah.headName != null) ...[
                      const SizedBox(height: SLSpacing.s4),
                      Text(
                        '${context.t('dawah_usrah_head')}: ${usrah.headName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: SLSpacing.s12),
                    for (final m in usrah.members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  Text(
                                    m.memberCode ?? '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _MiniRing(pct: m.completion7d ?? 0, bengali: bn),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SectionHeader(
                context.t('dawah_announcements'),
                icon: Icons.campaign_outlined,
              ),
              if (bundle.announcements.isEmpty)
                EmptyState(message: context.t('empty_generic'))
              else
                for (final a in bundle.announcements)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (a.pinned)
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: theme.colorScheme.tertiary,
                              ),
                            Expanded(
                              child: Text(
                                a.authorName ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              a.createdAt.substring(0, 10),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: SLSpacing.s4),
                        Text(a.body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
            ],
            const SizedBox(height: SLSpacing.s24),
          ],
        );
      },
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.pct, required this.bengali});
  final int pct;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        '${bengali ? toBn(pct) : pct}%',
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Tab 3: reviews ──────────────────────────────────────────────────────────

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewsProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;

    return async.when(
      loading: () => const Skeleton(height: 72, count: 5),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(reviewsProvider),
      ),
      data: (reviews) {
        if (reviews == null) {
          return ListView(
            children: [
              const SizedBox(height: SLSpacing.s24),
              ErrorState(
                message: context.t('not_available_offline'),
                onRetry: () => ref.invalidate(reviewsProvider),
              ),
            ],
          );
        }
        if (reviews.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: SLSpacing.s24),
              EmptyState(
                message: 'এখনো কোনো সাপ্তাহিক রিভিউ হয়নি',
                icon: Icons.rate_review_outlined,
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(SLSpacing.s16),
          itemCount: reviews.length,
          itemBuilder: (context, i) {
            final r = reviews[i];
            final statusColor = switch (r.status) {
              'done' => theme.colorScheme.primary,
              'overdue' => theme.colorScheme.error,
              _ => theme.colorScheme.tertiary,
            };
            final statusLabel = switch (r.status) {
              'done' => 'সম্পন্ন',
              'overdue' => 'বিলম্বিত',
              _ => 'অপেক্ষমাণ',
            };
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'সপ্তাহ: ${bn ? toBn(r.weekStart) : r.weekStart}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: SLRadius.brPill,
                        ),
                        child: Text(
                          statusLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.reviewerName != null)
                    Text(
                      '${context.t('dawah_usrah_head')}: ${r.reviewerName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (r.summary?['overallPct'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: SLSpacing.s4),
                      child: Text(
                        '${context.t('amal_completion')}: ${bn ? toBn(r.summary!['overallPct']) : r.summary!['overallPct']}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (r.comment != null && r.comment!.isNotEmpty) ...[
                    const SizedBox(height: SLSpacing.s4),
                    Text('“${r.comment}”', style: theme.textTheme.bodyMedium),
                  ],
                  if (r.rating != null) ...[
                    const SizedBox(height: SLSpacing.s4),
                    Row(
                      children: [
                        for (var s = 1; s <= 5; s++)
                          Icon(
                            s <= (r.rating ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
