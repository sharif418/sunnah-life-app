/// "অ্যাকাউন্ট মুছে ফেলুন" (Google Play's account-deletion requirement):
/// says plainly what goes and what stays, asks for one deliberate tick,
/// then DELETE /api/me, wipes the account's data from this phone and signs
/// out. A usrah head is told to hand the usrah over first (the server's 409
/// message is shown as is).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart' show ApiException;
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

Future<void> showDeleteAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DeleteAccountSheet(),
    );

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  bool _understood = false;
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).deleteMe();
      await ref.read(dbProvider).wipeAccountData();
      await ref.read(authProvider.notifier).forceSignOut();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final done = context.t('delete_account_done');
      Navigator.of(context).pop();
      if (context.mounted) GoRouter.maybeOf(context)?.go('/');
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.t('delete_account_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    Widget point(String key) => Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              PhosphorIconsFill.circle,
              size: 6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(context.t(key), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          SLSpacing.s20,
          0,
          SLSpacing.s20,
          SLSpacing.s20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('delete_account_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('delete_account_goes'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            point('delete_account_goes_1'),
            point('delete_account_goes_2'),
            point('delete_account_goes_3'),
            const SizedBox(height: SLSpacing.s8),
            Text(
              context.t('delete_account_stays'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            point('delete_account_stays_1'),
            const SizedBox(height: SLSpacing.s8),
            Text(
              context.t('delete_account_final'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            CheckboxListTile(
              key: const ValueKey('delete_account_understood'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _understood = v ?? false),
              title: Text(context.t('delete_account_confirm_tick')),
            ),
            if (_error != null) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: danger),
              ),
            ],
            const SizedBox(height: SLSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('delete_account_confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _understood && !_busy ? _delete : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.trash),
                label: Text(context.t('delete_account_button')),
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(context.t('cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
