/// দাওয়াত — the Tarbiyah engine hub: member code + referral link + share,
/// madu tree, level + requirements + assessments, my usrah + announcements,
/// weekly review history. Gated to roles daee/usrah_head/invigilator/full_admin.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart' show ApiException;
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/goals_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/global_header.dart';
import '../shared/widgets.dart';
import 'madu_tree.dart';
import 'referral_share_sheet.dart';
import '../../design/phosphor_icons.dart';

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
        icon: PhosphorIconsRegular.signIn,
        message: context.t('dawah_signin_needed'),
        actionLabel: context.t('onb_signin'),
        onAction: () => context.push('/auth'),
      );
    } else if (!(auth.user?.canSeeDawah ?? false)) {
      body = _Gate(
        icon: PhosphorIconsRegular.megaphone,
        message: context.t('dawah_role_needed'),
      );
    } else {
      body = const _DawahTabs();
    }

    return Scaffold(
      // C-W4a: the shared global header replaces the screen's own AppBar
      // (logo, location, triple calendar, notification/reminder/profile,
      // sync badge — the badge used to live in this AppBar's actions).
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GlobalHeader(),
            Expanded(child: body),
          ],
        ),
      ),
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
        children: [
          TabBar(
            tabs: [
              Tab(text: context.t('tab_dawah')),
              Tab(text: context.t('dawah_tab_usrah')),
              Tab(text: context.t('dawah_tab_reviews')),
            ],
          ),
          const Expanded(
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
      data: (remote) {
        if (remote == null) {
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
        final overview = remote.data;
        final memberName =
            ref.watch(authProvider).userOrNull?.name ?? '';

        String joinLink(String code) => 'https://sunnahlife.app/join/$code';

        // W4e — the branded referral card preview (renders the PNG on
        // share). The sheet resolves all its strings from the locale.
        void openCardSheet() => showReferralCardSheet(
              context,
              memberName: memberName,
              memberCode: overview.memberCode,
              joinLink: joinLink(overview.memberCode),
            );

        return ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            // W4-fix4: cache-served snapshot — subtle banner + the stamp.
            if (remote.stale)
              OfflineBanner(fetchedAt: remote.fetchedAt),
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
                        icon: const Icon(PhosphorIconsRegular.copy),
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
                        icon: const Icon(PhosphorIconsRegular.shareNetwork),
                        onPressed: openCardSheet,
                      ),
                    ],
                  ),
                  // W4e — the overview's primary share action: the branded
                  // card preview (hidden when there is no code to invite
                  // with — the empty-code edge stays honest).
                  if (overview.memberCode.isNotEmpty) ...[
                    const SizedBox(height: SLSpacing.s12),
                    FilledButton.icon(
                      key: const Key('dawahShareCardButton'),
                      onPressed: openCardSheet,
                      icon: const Icon(PhosphorIconsRegular.shareNetwork),
                      label: Text(context.t('dawah_share_card')),
                    ),
                  ],
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
                  value: context.t(overview.level.labelKey),
                ),
                _StatCell(
                  label: context.t('dawah_months_in_level'),
                  value:
                      '${bn ? toBn(overview.monthsInLevel) : overview.monthsInLevel}',
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s12),

            // Requirements checklist — “Live checklist” opens the live screen
            // (GET /api/dawah/requirements, B9 mobile parity with the web).
            SectionHeader(
              context.t('dawah_requirements'),
              icon: PhosphorIconsRegular.listChecks,
              action: TextButton.icon(
                onPressed: () => context.push('/dawah/requirements'),
                icon: const Icon(PhosphorIconsRegular.lightning, size: 16),
                label: Text(context.t('dawah_req_live_action')),
              ),
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
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
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
              '${context.t('dawah_next_level')}: ${context.t(overview.nextLevel.labelKey)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // Madu tree — W4e: the flat depth-sorted downline rendered as
            // an indented tree with connector rails (read-only — the API
            // carries depth but no parentage; madu_tree.dart notes why).
            SectionHeader(context.t('dawah_madu'), icon: PhosphorIconsRegular.gitFork),
            if (overview.downline.isEmpty)
              EmptyState(
                message: overview.level == Level.none
                    ? context.t('dawah_level_none_next')
                    : context.t('empty_generic'),
                icon: PhosphorIconsRegular.tree,
              )
            else
              MaduTree(nodes: overview.downline),

            // Assessments
            SectionHeader(
              context.t('dawah_assessments'),
              icon: PhosphorIconsRegular.clipboardText,
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
                              ? PhosphorIconsRegular.sealCheck
                              : PhosphorIconsRegular.hourglass,
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
    final user = ref.watch(authProvider).userOrNull;

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
            // W4-fix4: cache-served snapshot — subtle banner + the stamp.
            if (bundle.stale && bundle.fetchedAt != null)
              OfflineBanner(fetchedAt: bundle.fetchedAt!),
            if (usrah == null) ...[
              const SizedBox(height: SLSpacing.s24),
              EmptyState(
                message: context.t('dawah_no_usrah'),
                icon: PhosphorIconsRegular.usersThree,
              ),
            ] else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.usersThree, color: theme.colorScheme.primary),
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
              // B9: usrah question board — members ask, the head answers (RLS).
              AppCard(
                onTap: () => context.push('/dawah/questions'),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.chats,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Text(
                        context.t('usrah_q_title'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                      ),
                      ),
                    ),
                    const DirectionalIcon(PhosphorIconsRegular.caretRight),
                  ],
                ),
              ),
              const SizedBox(height: SLSpacing.s4),
              SectionHeader(
                context.t('dawah_announcements'),
                icon: PhosphorIconsRegular.megaphone,
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
                                PhosphorIconsRegular.pushPin,
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
            // W4c: লক্ষ্য অনুমোদন — the head's goal-approval queue
            // (GET /api/usrah/goals; supervisors only — a da'ee sees nothing).
            if (user?.role.isSupervisor ?? false) ...[
              const SizedBox(height: SLSpacing.s12),
              SectionHeader(
                context.t('goals_queue_title'),
                icon: PhosphorIconsRegular.clipboardText,
              ),
              const _GoalQueueSection(),
            ],
            const SizedBox(height: SLSpacing.s24),
          ],
        );
      },
    );
  }
}

// ── W4c: goal approval queue (supervisors) ──────────────────────────────────

/// The queue body — watches goalQueueProvider (null hides: non-supervisor,
/// guest, offline). Approve fires the member's reminder server-side.
class _GoalQueueSection extends ConsumerWidget {
  const _GoalQueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalQueueProvider);
    return async.when(
      loading: () => const Skeleton(height: 72, count: 2),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(goalQueueProvider),
      ),
      data: (queue) {
        if (queue == null) return const SizedBox.shrink();
        if (queue.isEmpty) {
          return EmptyState(
            message: context.t('goals_queue_empty'),
            icon: PhosphorIconsRegular.clipboardText,
          );
        }
        return Column(
          children: [for (final item in queue) _GoalQueueCard(item: item)],
        );
      },
    );
  }
}

class _GoalQueueCard extends ConsumerWidget {
  const _GoalQueueCard({required this.item});
  final GoalQueueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defsAsync = ref.watch(amalDefinitionsProvider);
    final amalTitle = defsAsync.maybeWhen(
      data: (defs) {
        for (final d in defs) {
          if (d.key == item.goal.amalKey) return d.titleBn;
        }
        return null;
      },
      orElse: () => null,
    );
    final goal = item.goal;

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.flagBanner, color: theme.colorScheme.primary),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${context.t('goals_member_label')}: ${item.userName} · ${context.t('goals_amal_short')}: ${amalTitle ?? goal.amalKey}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (goal.note != null && goal.note!.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(goal.note!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: SLSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _decide(context, ref),
                    icon: const Icon(PhosphorIconsRegular.check, size: 18),
                    label: Text(context.t('goals_approve')),
                  ),
                ),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRejectSheet(context, ref),
                    icon: const Icon(PhosphorIconsRegular.x, size: 18),
                    label: Text(context.t('goals_reject')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiProvider).approveGoal(item.goal.id);
      ref.invalidate(goalQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('goals_approved_toast')),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openRejectSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RejectReasonSheet(itemId: item.goal.id),
    );
  }
}

/// Reject with an optional reason — the reason surfaces on the member's
/// goal card ("কারণ: …") and rides the API's GoalRejectDto.
class _RejectReasonSheet extends ConsumerStatefulWidget {
  const _RejectReasonSheet({required this.itemId});
  final String itemId;

  @override
  ConsumerState<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends ConsumerState<_RejectReasonSheet> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(apiProvider)
          .rejectGoal(widget.itemId, reason: _reasonController.text.trim());
      ref.invalidate(goalQueueProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('goals_rejected_toast'))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: SLSpacing.s16,
        right: SLSpacing.s16,
        top: SLSpacing.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + SLSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('goals_reject_hint')),
          const SizedBox(height: SLSpacing.s8),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.t('goals_reject_reason_label'),
            ),
          ),
          const SizedBox(height: SLSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(context.t('goals_reject')),
            ),
          ),
        ],
      ),
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
      data: (remote) {
        if (remote == null) {
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
        final reviews = remote.data;
        if (reviews.isEmpty) {
          return ListView(
            children: [
              // W4-fix4: even the empty state deserves the staleness stamp.
              if (remote.stale) OfflineBanner(fetchedAt: remote.fetchedAt),
              const SizedBox(height: SLSpacing.s24),
              EmptyState(
                message: context.t('dawah_no_reviews'),
                icon: PhosphorIconsRegular.star,
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(SLSpacing.s16),
          itemCount: reviews.length + (remote.stale ? 1 : 0),
          itemBuilder: (context, i) {
            if (remote.stale && i == 0) {
              return OfflineBanner(fetchedAt: remote.fetchedAt);
            }
            final r = reviews[remote.stale ? i - 1 : i];
            final statusColor = switch (r.status) {
              'done' => theme.colorScheme.primary,
              'overdue' => theme.colorScheme.error,
              _ => theme.colorScheme.tertiary,
            };
            final statusLabel = switch (r.status) {
              'done' => context.t('done'),
              'overdue' => context.t('review_status_overdue'),
              _ => context.t('review_status_pending'),
            };
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${context.t('dawah_week')}: ${bn ? toBn(r.weekStart) : r.weekStart}',
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
                                ? PhosphorIconsFill.star
                                : PhosphorIconsRegular.star,
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
