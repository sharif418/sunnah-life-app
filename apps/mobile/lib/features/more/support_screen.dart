/// লাইভ সাপোর্ট (W4d) — the member's own support threads: the list
/// (status chips, last preview, unread dot) + the conversation screen with
/// a reply box. Guests get the sign-in gate. The wire contract is the W4d
/// backend (POST/GET /api/support, GET /api/support/:id,
/// POST /api/support/:id/messages — closed threads refuse appends with 400).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../core/sync_policy.dart' show formatAgoBn;
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/support_state.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

/// Thread list.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    Widget body;
    if (auth.status == AuthStatus.loading) {
      body = const Skeleton(height: 88, count: 4);
    } else if (!auth.signedIn) {
      body = _Gate(
        message: context.t('support_signin_needed'),
        actionLabel: context.t('onb_signin'),
        onAction: () => context.push('/auth'),
      );
    } else {
      body = const _ThreadList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_support')),
      ),
      body: body,
      // New-thread affordance — hidden for guests (the gate explains why).
      floatingActionButton: auth.signedIn
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSheet(context, ref),
              icon: const Icon(PhosphorIconsRegular.chatCircle),
              label: Text(context.t('support_new_thread')),
            )
          : null,
    );
  }
}

Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _CreateThreadSheet(),
  );
}

/// Subject + first message → POST /api/support (max 5 non-closed threads
/// server-side; the error message is Bengali from the API).
class _CreateThreadSheet extends ConsumerStatefulWidget {
  const _CreateThreadSheet();

  @override
  ConsumerState<_CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends ConsumerState<_CreateThreadSheet> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .supportCreate(
            subject: _subject.text.trim(),
            message: _message.text.trim(),
          );
      ref.invalidate(supportThreadsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('support_created_toast'))),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SLSpacing.s16,
        0,
        SLSpacing.s16,
        MediaQuery.of(context).viewInsets.bottom + SLSpacing.s16,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('support_new_thread'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SLSpacing.s12),
            TextFormField(
              controller: _subject,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: context.t('support_subject'),
                hintText: context.t('support_subject_hint'),
                isDense: true,
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? context.t('support_subject')
                  : null,
            ),
            const SizedBox(height: SLSpacing.s12),
            TextFormField(
              controller: _message,
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: context.t('support_message'),
                hintText: context.t('support_message_hint'),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? context.t('support_message_hint')
                  : null,
            ),
            const SizedBox(height: SLSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                label: Text(context.t('send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(supportThreadsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(supportThreadsProvider);
        await ref.read(supportThreadsProvider.future);
      },
      child: threads.when(
        loading: () => const Skeleton(height: 88, count: 4),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s32),
            ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(supportThreadsProvider),
            ),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s32),
                EmptyState(
                  message: context.t('support_empty'),
                  icon: PhosphorIconsRegular.headset,
                  // W4f — the illustrated state's CTA: the same sheet the
                  // FAB opens (the empty list hides nothing).
                  actionLabel: context.t('support_new_thread'),
                  onAction: () => _showCreateSheet(context, ref),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: SLSpacing.s16,
                          endIndent: SLSpacing.s16,
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: 0.6),
                        ),
                      _ThreadRow(thread: list[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One thread row — the whole row opens the conversation.
class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});
  final SupportThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final lastAt = DateTime.tryParse(thread.lastMessageAt ?? '');
    return InkWell(
      onTap: () => context.push('/more/support/${thread.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s16,
            vertical: SLSpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Unread dot — the last message is a support reply.
                        if (thread.unreadForUser) ...[
                          Container(
                            key: const ValueKey('support_unread_dot'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: SLSpacing.s8),
                        ],
                        Expanded(
                          child: Text(
                            thread.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (thread.lastPreview?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        thread.lastPreview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (lastAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatAgoBn(
                          DateTime.now().difference(lastAt),
                          bengali: bn,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SLSpacing.s8),
              SupportStatusChip(status: thread.status),
              const SizedBox(width: SLSpacing.s4),
              const DirectionalIcon(PhosphorIconsRegular.caretRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// open (primary) / answered (success) / closed (muted).
class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip({super.key, required this.status});
  final SupportStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (labelKey, fg) = switch (status) {
      SupportStatus.open => ('support_status_open', theme.colorScheme.primary),
      SupportStatus.answered => (
        'support_status_answered',
        theme.colorScheme.tertiary,
      ),
      SupportStatus.closed => (
        'support_status_closed',
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s8,
        vertical: SLSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: SLRadius.brSm,
      ),
      child: Text(
        context.t(labelKey),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The conversation: member bubbles (end, primary container) vs support
/// team bubbles (start, muted surface + সাপোর্ট টিম label) + the reply box.
class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).supportAppend(id: widget.id, message: text);
      _reply.clear();
      ref.invalidate(supportThreadProvider(widget.id));
      ref.invalidate(supportThreadsProvider);
    } on ApiException catch (e) {
      // Closed threads refuse appends with 400 (no auto-reopen server-side).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.status == 400 ? context.t('support_closed_toast') : e.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threadAsync = ref.watch(supportThreadProvider(widget.id));

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: threadAsync.when(
        loading: () => const Skeleton(height: 88, count: 5),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(supportThreadProvider(widget.id)),
        ),
        data: (data) {
          final (thread, messages) = data;
          return Column(
            children: [
              // Slim header — subject + status chip.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SLSpacing.s16,
                  SLSpacing.s8,
                  SLSpacing.s16,
                  SLSpacing.s8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    SupportStatusChip(status: thread.status),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? EmptyState(
                        message: context.t('support_empty'),
                        icon: PhosphorIconsRegular.chats,
                      )
                    : ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.fromLTRB(
                          SLSpacing.s16,
                          SLSpacing.s8,
                          SLSpacing.s16,
                          SLSpacing.s8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, i) =>
                            _MessageBubble(message: messages[i]),
                      ),
              ),
              // Reply box — hidden for closed threads (terminal; a new
              // thread is the path forward).
              if (thread.status != SupportStatus.closed)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SLSpacing.s16,
                      SLSpacing.s8,
                      SLSpacing.s8,
                      SLSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: context.t('support_message_hint'),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: SLSpacing.s8),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const DirectionalIcon(PhosphorIconsRegular.paperPlaneTilt),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One chat bubble — mine vs the support team, visually distinct.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = !message.isAdmin;
    final time = DateTime.tryParse(message.createdAt);
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: SLSpacing.s8),
        padding: const EdgeInsets.symmetric(
          horizontal: SLSpacing.s12,
          vertical: SLSpacing.s8,
        ),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: SLRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                context.t('support_team'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(message.body, style: theme.textTheme.bodyMedium),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  context.isBn
                      ? toBn(
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}',
                        )
                      : '${time.hour.toString().padLeft(2, '0')}:'
                            '${time.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The dawah_screen gate idiom — message + optional sign-in action.
class _Gate extends StatelessWidget {
  const _Gate({required this.message, this.actionLabel, this.onAction});
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
            Icon(
              PhosphorIconsRegular.headset,
              size: 56,
              color: theme.colorScheme.primary,
            ),
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
