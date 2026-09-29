/// W4i — the ASSESSEE's OTP confirmation sheet for one assessment result.
///
/// The farze-ain result only becomes FINAL (effective for level
/// transitions) after the member's own OTP-confirmed acknowledgment:
///   · কোড পাঠান  → POST /api/assessments/:id/confirm-request (the AUTH OTP
///     service — same throttle + hashing as sign-in, sent to the member's
///     OWN phone, never a caller-supplied number)
///   · যাচাই করুন → POST /api/assessments/:id/confirm {code} — on success
///     the card flips to confirmed (the dawah overview refetches)
///   · ফলাফল বাতিল করুন → decline with an optional reason; the invigilator
///     is notified server-side.
/// The OTP entry mirrors the auth screen's pattern (digits-only field,
/// debug-only devCode chip — never auto-filled in release builds).
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';

/// Color-coded status pill (the GoalStatusChip idiom).
class AssessmentStatusChip extends StatelessWidget {
  const AssessmentStatusChip({super.key, required this.status});
  final AssessmentStatus status;

  static const _labelKeys = {
    AssessmentStatus.pendingConfirmation: 'assessment_status_pending',
    AssessmentStatus.confirmed: 'assessment_status_confirmed',
    AssessmentStatus.declined: 'assessment_status_declined',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      AssessmentStatus.confirmed => theme.colorScheme.primary,
      AssessmentStatus.pendingConfirmation => theme.colorScheme.tertiary,
      AssessmentStatus.declined => theme.colorScheme.error,
    };
    return Container(
      key: ValueKey('assessment_status_chip_${status.json}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        context.t(_labelKeys[status]!),
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

/// Opens the sheet over [assessment]; refreshes the dawah overview when a
/// decision lands so the card flips to its new status.
Future<void> showAssessmentConfirmSheet(
  BuildContext context,
  AssessmentSummary assessment,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AssessmentConfirmSheet(assessment: assessment),
  );
}

class AssessmentConfirmSheet extends ConsumerStatefulWidget {
  const AssessmentConfirmSheet({super.key, required this.assessment});
  final AssessmentSummary assessment;

  @override
  ConsumerState<AssessmentConfirmSheet> createState() =>
      _AssessmentConfirmSheetState();
}

class _AssessmentConfirmSheetState extends ConsumerState<AssessmentConfirmSheet> {
  final _code = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _devCode;
  String? _error;
  bool _codeSent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiProvider)
          .assessmentConfirmRequest(widget.assessment.id);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devCode = res.devCode;
        // Auto-fill ONLY in debug builds (mock SMS): a release build must
        // never auto-fill the code (the auth-screen rule, Phase C/W2b).
        if (res.devCode != null && kDebugMode) _code.text = res.devCode!;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).assessmentConfirm(
            id: widget.assessment.id,
            code: _code.text.trim(),
          );
      // the card flips: the overview (the section's source) refetches
      ref.invalidate(dawahProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('assessment_confirmed_toast'))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _decline() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(context.t('assessment_decline_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('assessment_decline_body')),
              const SizedBox(height: SLSpacing.s12),
              TextField(
                controller: controller,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: context.t('assessment_decline_reason_hint'),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(context.t('cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim(),
              ),
              child: Text(context.t('assessment_decline_label')),
            ),
          ],
        );
      },
    );
    if (reason == null) return; // the dialog's cancel returns "" — a real decline
    try {
      await ref.read(apiProvider).assessmentDecline(
            id: widget.assessment.id,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(dawahProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('assessment_declined_toast'))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final a = widget.assessment;
    final resultLabel = a.result == 'passed'
        ? context.t('assessment_result_passed')
        : context.t('assessment_result_not_yet');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SLSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.sealCheck,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: Text(
                    context.t('assessment_confirm_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              context.t('assessment_confirm_body'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s12),
            Text(
              '${context.t('assessment_result_label')}: $resultLabel'
              '${a.scorePct != null ? ' · ${context.t('assessment_score_label')}: ${bn ? toBn(a.scorePct!) : a.scorePct}%' : ''}',
              key: const Key('assessment_confirm_result_line'),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),
            if (!_codeSent) ...[
              FilledButton.icon(
                key: const Key('assessmentConfirmSendButton'),
                onPressed: _sending ? null : _requestCode,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                label: Text(context.t('auth_request_otp')),
              ),
            ] else ...[
              if (_devCode != null && kDebugMode)
                // debug-only: the code chip never renders in release builds
                Container(
                  margin: const EdgeInsets.only(bottom: SLSpacing.s12),
                  padding: const EdgeInsets.all(SLSpacing.s12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: SLRadius.brMd,
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIconsRegular.code, color: theme.colorScheme.tertiary),
                      const SizedBox(width: SLSpacing.s8),
                      Expanded(
                        child: Text(
                          '${context.t('auth_dev_code')}: ${bn ? toBn(_devCode!) : _devCode!}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                key: const Key('assessmentConfirmCodeField'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: context.t('auth_otp'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              FilledButton.icon(
                key: const Key('assessmentConfirmVerifyButton'),
                onPressed: _code.text.length >= 4 && !_verifying ? _verify : null,
                icon: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.checkCircle)
                ,
                label: Text(context.t('auth_verify')),
              ),
              TextButton(
                onPressed: _verifying
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _devCode = null;
                        _code.clear();
                      }),
                child: Text(context.t('cancel')),
              ),
            ],
            const SizedBox(height: SLSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('assessmentDeclineButton'),
                onPressed: _verifying || _sending ? null : _decline,
                icon: const Icon(PhosphorIconsRegular.xCircle, size: 18),
                label: Text(context.t('assessment_decline_cta')),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: SLSpacing.s8),
              ErrorState(message: _error!, onRetry: _codeSent ? _verify : _requestCode),
            ],
          ],
        ),
      ),
    );
  }
}
