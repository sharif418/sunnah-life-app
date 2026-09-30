/// উসরায় যোগ দিন (W4d) — the More-tab tile's sheet: members WITHOUT an
/// usrah send a join request (POST /api/usrah/join-request; idempotent
/// while pending), members WITH one see their current usrah instead.
/// The full_admin approve/reject flow lives in the admin panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show usrahProvider;
import '../../state/support_state.dart' show joinRequestProvider;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

Future<void> showUsrahJoinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _UsrahJoinSheet(),
  );
}

class _UsrahJoinSheet extends ConsumerStatefulWidget {
  const _UsrahJoinSheet();

  @override
  ConsumerState<_UsrahJoinSheet> createState() => _UsrahJoinSheetState();
}

class _UsrahJoinSheetState extends ConsumerState<_UsrahJoinSheet> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .joinRequestCreate(
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          );
      ref.invalidate(joinRequestProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('usrah_join_sent_toast'))),
      );
    } on ApiException catch (e) {
      // 409 = already in an usrah (the server's own Bengali message).
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        ref.invalidate(usrahProvider);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    // Guests: gate — signing in is the prerequisite for any assignment.
    if (!auth.signedIn) {
      return _GatePane(message: context.t('usrah_join_signin_needed'));
    }

    final bundle = ref.watch(usrahProvider);
    final usrah = bundle.valueOrNull?.usrah;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SLSpacing.s16,
        0,
        SLSpacing.s16,
        MediaQuery.of(context).viewInsets.bottom + SLSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('more_usrah_join'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('usrah_join_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          if (usrah != null)
            _InUsrahCard(usrah: usrah)
          else
            ref
                .watch(joinRequestProvider)
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: SLSpacing.s24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  // A network failure surfaces as null — the form stays
                  // usable (the send path reports errors itself).
                  error: (e, _) => _RequestForm(
                    controller: _message,
                    sending: _sending,
                    onSend: _send,
                  ),
                  data: (request) =>
                      request == null ||
                          request.status == JoinRequestStatus.rejected
                      ? _RequestForm(
                          controller: _message,
                          sending: _sending,
                          onSend: _send,
                          rejected: request,
                        )
                      : _PendingCard(request: request),
                ),
          const SizedBox(height: SLSpacing.s8),
        ],
      ),
    );
  }
}

/// Already assigned — the current usrah card (name, head, size).
class _InUsrahCard extends StatelessWidget {
  const _InUsrahCard({required this.usrah});
  final Usrah usrah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.usersThree, color: theme.colorScheme.primary),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Text(
                  usrah.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          if (usrah.headName?.isNotEmpty ?? false)
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.user,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SLSpacing.s4),
                Text(
                  '${context.t('dawah_usrah_head')}: ${usrah.headName}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          if (usrah.memberCount != null)
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.users,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SLSpacing.s4),
                Text(
                  '${context.t('dawah_members')}: ${context.isBn ? toBn(usrah.memberCount!) : usrah.memberCount}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('usrah_join_in_usrah'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending (or approved-but-not-yet-visible) request state.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.request});
  final UsrahJoinRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.hourglass,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  context.t('usrah_join_pending'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (request.message?.isNotEmpty ?? false) ...[
            const SizedBox(height: SLSpacing.s4),
            Text(
              request.message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The request form — optional message + send. After a rejection it shows
/// the admin's reason and allows a fresh request (a new row server-side).
class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.controller,
    required this.sending,
    required this.onSend,
    this.rejected,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final UsrahJoinRequest? rejected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rejected != null) ...[
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.info,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: SLSpacing.s8),
              Text(
                context.t('usrah_join_rejected'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (rejected!.reason?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(
                left: SLSpacing.s24 + 2,
                top: SLSpacing.s4,
              ),
              child: Text(
                '${context.t('usrah_join_reason_label')}: ${rejected!.reason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: SLSpacing.s8),
        ],
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.t('usrah_join_message_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: SLSpacing.s12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.paperPlaneTilt),
            label: Text(context.t('usrah_join_send')),
          ),
        ),
      ],
    );
  }
}

/// The dawah_screen gate idiom, sheet-sized.
class _GatePane extends StatelessWidget {
  const _GatePane({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SLSpacing.s24),
      child: EmptyState(message: message, icon: PhosphorIconsRegular.signIn),
    );
  }
}
