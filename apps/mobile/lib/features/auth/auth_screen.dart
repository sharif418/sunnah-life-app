/// OTP auth screen — request → verify, devCode display (sandbox/mock SMS),
/// guest-mode note. On success the guest's local amal diary rides along
/// (server merges by latest clientUpdatedAt).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _devCode;
  String? _error;
  bool _codeSent = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _phoneValid =>
      RegExp(r'^01[3-9]\d{8}$').hasMatch(_phone.text.trim());

  Future<void> _requestOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).requestOtp(_phone.text.trim());
      setState(() {
        _codeSent = true;
        _devCode = res.devCode;
        if (res.devCode != null) _code.text = res.devCode!;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
      final profile = ref.read(profileProvider);
      await ref
          .read(authProvider.notifier)
          .signIn(
            phone: _phone.text.trim(),
            code: _code.text.trim(),
            name: profile.name,
            gender: profile.gender,
          );
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('auth_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s20),
        children: [
          Icon(
            Icons.smartphone_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: SLSpacing.s12),
          Text(
            context.t('auth_guest_note'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s24),
          TextField(
            controller: _phone,
            enabled: !_codeSent,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 11,
            decoration: InputDecoration(
              labelText: context.t('auth_phone'),
              hintText: context.t('auth_phone_hint'),
              counterText: '',
              errorText: _phone.text.isNotEmpty && !_phoneValid && !_codeSent
                  ? context.t('auth_invalid_phone')
                  : null,
            ),
          ),
          if (!_codeSent) ...[
            const SizedBox(height: SLSpacing.s12),
            FilledButton(
              onPressed: _phoneValid && !_sending ? _requestOtp : null,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('auth_request_otp')),
            ),
          ] else ...[
            const SizedBox(height: SLSpacing.s16),
            if (_devCode != null)
              Container(
                margin: const EdgeInsets.only(bottom: SLSpacing.s12),
                padding: const EdgeInsets.all(SLSpacing.s12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: SLRadius.brMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.developer_mode,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Expanded(
                      child: Text(
                        '${context.t('auth_dev_code')}: ${context.isBn ? _bn(_devCode!) : _devCode!}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: context.t('auth_otp')),
            ),
            const SizedBox(height: SLSpacing.s12),
            FilledButton(
              onPressed: _code.text.length >= 4 && !_verifying ? _verify : null,
              child: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('auth_verify')),
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
          if (_error != null) ...[
            const SizedBox(height: SLSpacing.s12),
            ErrorState(
              message: _error!,
              onRetry: _codeSent ? _verify : _requestOtp,
            ),
          ],
        ],
      ),
    );
  }

  static String _bn(String digits) => digits.replaceAllMapped(
    RegExp('[0-9]'),
    (m) => const [
      '০',
      '১',
      '২',
      '৩',
      '৪',
      '৫',
      '৬',
      '৭',
      '৮',
      '৯',
    ][int.parse(m.group(0)!)],
  );
}
