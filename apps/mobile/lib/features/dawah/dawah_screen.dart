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
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/goals_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/global_header.dart';
import '../shared/widgets.dart';
import 'assessment_confirm_sheet.dart';
import 'dawah_journey.dart';
import 'usrah_quiz_results.dart';
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
        // the shared header, hiding while scrolling down (BNAV-01)
        child: ScrollAwareHeader(body: body),
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
              Tab(text: context.t('dawah_tab_mine')),
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
        final memberName = ref.watch(authProvider).userOrNull?.name ?? '';

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
          // W5: scroll clear of the floating contact button (see
          // kContactFabClearance) — it used to cover the last rows.
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s16,
            SLSpacing.s16,
            kContactFabClearance,
          ),
          children: [
            // W4-fix4: cache-served snapshot — subtle banner + the stamp.
            if (remote.stale) OfflineBanner(fetchedAt: remote.fetchedAt),

            // The journey first: where I am, what's left (the prototype's
            // order — the invite card follows the progress, not the reverse).
            LevelJourneyCard(
              level: overview.level,
              nextLevel: overview.nextLevel,
              monthsInLevel: overview.monthsInLevel,
              requirementsMet: overview.requirements
                  .where((r) => r.done)
                  .length,
              requirementsTotal: overview.requirements.length,
            ),
            const SizedBox(height: SLSpacing.s16),

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
                  for (var i = 0; i < overview.requirements.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _RequirementLine(req: overview.requirements[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s16),

            // The usrah head's latest weekly comment to ME.
            ...switch (latestReviewFor(ref)) {
              final review? => [
                LatestReviewCard(
                  review: review,
                  onSeeAll: () =>
                      DefaultTabController.maybeOf(context)?.animateTo(2),
                ),
                const SizedBox(height: SLSpacing.s16),
              ],
              _ => const <Widget>[],
            },

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
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    context
                        .t('dawah_joined_count')
                        .replaceAll(
                          '%n%',
                          bn
                              ? toBn(overview.invitedCount)
                              : '${overview.invitedCount}',
                        ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (overview.memberCode.isNotEmpty) ...[
                    const SizedBox(height: SLSpacing.s12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('dawahShareCardButton'),
                        onPressed: openCardSheet,
                        icon: const Icon(PhosphorIconsRegular.shareNetwork),
                        label: Text(context.t('dawah_share_card')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s8),

            // Madu tree — W4e: the flat depth-sorted downline rendered as
            // an indented tree with connector rails (read-only — the API
            // carries depth but no parentage; madu_tree.dart notes why).
            SectionHeader(
              context.t('dawah_madu'),
              icon: PhosphorIconsRegular.gitFork,
            ),
            if (overview.downline.isEmpty)
              EmptyState(
                message: overview.level == Level.none
                    ? context.t('dawah_level_none_next')
                    : context.t('empty_generic'),
                icon: PhosphorIconsRegular.tree,
              )
            else
              MaduTree(nodes: overview.downline),

            // Assessments — W4i: every row carries the acknowledgment STATUS
            // (pending_confirmation | confirmed | declined); a pending result
            // only becomes final after the member's own OTP confirmation, so
            // those rows get the নিশ্চিত করুন CTA that opens the OTP sheet.
            SectionHeader(
              context.t('dawah_assessments'),
              icon: PhosphorIconsRegular.clipboardText,
            ),
            // none yet: one quiet line, not a full-page illustration at
            // the bottom of the member's own path
            if (overview.assessments.isEmpty)
              AppCard(
                child: Text(
                  context.t('empty_generic'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final a in overview.assessments) ...[
                      ListTile(
                        dense: true,
                        key: ValueKey('assessment_row_${a.id}'),
                        leading: Icon(
                          a.status == AssessmentStatus.declined
                              ? PhosphorIconsRegular.warningCircle
                              : a.result == 'passed'
                              ? PhosphorIconsRegular.sealCheck
                              : PhosphorIconsRegular.hourglass,
                          color: a.status == AssessmentStatus.declined
                              ? theme.colorScheme.error
                              : a.result == 'passed'
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                        title: Text(a.templateKey),
                        subtitle:
                            a.status == AssessmentStatus.declined &&
                                (a.decisionNote ?? '').isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.createdAt.substring(0, 10)),
                                  Text(
                                    '${context.t('assessment_decision_note_label')}: ${a.decisionNote}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              )
                            : Text(a.createdAt.substring(0, 10)),
                        trailing: FittedBox(
                          // Score + chip never overflow the row when the
                          // subtitle wraps to two lines (declined reason).
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (a.scorePct != null)
                                Text(
                                  '${bn ? toBn(a.scorePct!) : a.scorePct}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: a.result == 'passed'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.tertiary,
                                  ),
                                ),
                              AssessmentStatusChip(status: a.status),
                            ],
                          ),
                        ),
                        onTap: a.status == AssessmentStatus.pendingConfirmation
                            ? () => showAssessmentConfirmSheet(context, a)
                            : null,
                      ),
                      if (a.status == AssessmentStatus.pendingConfirmation)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SLSpacing.s16,
                            0,
                            SLSpacing.s16,
                            SLSpacing.s8,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.tonalIcon(
                              key: ValueKey('assessmentConfirmCta_${a.id}'),
                              onPressed: () =>
                                  showAssessmentConfirmSheet(context, a),
                              icon: const Icon(
                                PhosphorIconsRegular.sealCheck,
                                size: 18,
                              ),
                              label: Text(context.t('assessment_confirm_cta')),
                            ),
                          ),
                        ),
                    ],
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
                        Icon(
                          PhosphorIconsRegular.usersThree,
                          color: theme.colorScheme.primary,
                        ),
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
              // the members' quiz results (audit gap: supervisors never saw them)
              const UsrahQuizResultsSection(),
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
                Icon(
                  PhosphorIconsRegular.flagBanner,
                  color: theme.colorScheme.primary,
                ),
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
          SnackBar(content: Text(context.t('goals_approved_toast'))),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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

/// One goal of this level, the prototype's way: a ring that fills when met,
/// the goal, a progress bar + "২/৪" when the detail carries a count, and
/// the detail line.
class _RequirementLine extends StatelessWidget {
  const _RequirementLine({required this.req});
  final LevelRequirement req;

  /// The first "n/m" in the detail (Bengali or Latin digits), if any.
  static (int, int)? countOf(String detail) {
    const bnDigits = '০১২৩৪৫৬৭৮৯';
    final ascii = detail.replaceAllMapped(
      RegExp('[০-৯]'),
      (m) => '${bnDigits.indexOf(m.group(0)!)}',
    );
    final m = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(ascii);
    if (m == null) return null;
    final done = int.parse(m.group(1)!), total = int.parse(m.group(2)!);
    return total <= 0 ? null : (done, total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = countOf(req.detail);
    final share = req.done ? 1.0 : (count == null ? null : (count.$1 / count.$2).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(SLSpacing.s16, SLSpacing.s12, SLSpacing.s16, SLSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            req.done ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
            size: 24,
            color: req.done ? cs.primary : cs.outline,
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        req.label,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (count != null)
                      Text(
                        '${toBn(count.$1)}/${toBn(count.$2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                if (share != null) ...[
                  const SizedBox(height: SLSpacing.s4),
                  ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 6,
                      backgroundColor: cs.outline,
                      color: req.done ? cs.primary : cs.tertiary,
                    ),
                  ),
                ],
                if (req.detail.isNotEmpty) ...[
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    req.detail,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
