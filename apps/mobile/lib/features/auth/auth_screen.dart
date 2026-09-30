/// OTP auth screen — request → verify, devCode display (sandbox/mock SMS),
/// guest-mode note. On success the guest's local amal diary rides along
/// (server merges by latest clientUpdatedAt).
///
/// Social sign-in (Task B5): Google/Apple buttons appear when
/// GET /api/auth/providers says the provider is enabled on the server AND
/// the local build has its client id (--dart-define). Same guest-entries
/// migration + session path as OTP; Apple is iOS-only (entitlement).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../services/social_signin_service.dart';
import '../../state/providers.dart';
import '../../state/referral_state.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

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

  // Social sign-in (B5).
  bool _socialGoogle = false;
  bool _socialApple = false;
  bool _socialBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  /// Which social buttons to show: server-enabled AND locally configured.
  /// Offline/failed fetch or `flutter test` ⇒ everything hidden (the OTP flow
  /// is always available).
  Future<void> _loadProviders() async {
    if (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true') return;
    final service = SocialSignInService.instance;
    try {
      final providers = await ref.read(apiProvider).authProviders();
      if (!mounted) return;
      setState(() {
        _socialGoogle = providers.google && service.googleAvailable;
        _socialApple = providers.apple && service.appleAvailable;
      });
    } on ApiException {
      // offline / server down — social stays hidden, OTP unaffected
    }
  }

  Future<void> _signInSocial(SocialProvider provider) async {
    if (_socialBusy) return;
    setState(() {
      _socialBusy = true;
      _error = null;
    });
    try {
      final service = SocialSignInService.instance;
      final idToken = provider == SocialProvider.google
          ? await service.googleIdToken()
          : await service.appleIdToken();
      final profile = ref.read(profileProvider);
      // C-W3h: a pending /join referral rides along on social sign-in too.
      final referral = ref.read(pendingReferralProvider).valueOrNull;
      await ref
          .read(authProvider.notifier)
          .signInWithSocial(
            provider: provider.name,
            idToken: idToken,
            name: profile.name,
            gender: profile.gender,
            referredByCode: referral,
          );
      // The router redirect handles the gender-less account case
      // (/complete-profile); everyone else lands home.
      if (mounted) context.go('/');
    } on SocialSignInCanceled {
      // user closed the provider sheet — silently back to the login screen
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = S.tr(context.lang, 'auth_social_error'));
    } finally {
      if (mounted) setState(() => _socialBusy = false);
    }
  }

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
        // Auto-fill ONLY in debug builds (mock SMS): a release build must
        // never auto-fill the code even if a misconfigured server returned
        // one (Phase C/W2b).
        if (res.devCode != null && kDebugMode) _code.text = res.devCode!;
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
      // C-W3h: the pending /join referral (stored by the deep-link service)
      // rides along on this OTP verify — the server creates the ReferralClosure
      // rows. Consumed + cleared by the notifier on success only.
      final referral = ref.read(pendingReferralProvider).valueOrNull;
      await ref
          .read(authProvider.notifier)
          .signIn(
            phone: _phone.text.trim(),
            code: _code.text.trim(),
            name: profile.name,
            gender: profile.gender,
            referredByCode: referral,
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
    // C-W3h: the pending /join referral (deep-link tap before sign-up).
    final referralCode = ref.watch(pendingReferralProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('auth_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s20),
        children: [
          Icon(
            PhosphorIconsRegular.deviceMobile,
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
          if (referralCode != null) ...[
            const SizedBox(height: SLSpacing.s12),
            // Subtle chip: the inviter's code will be attached to the
            // account on sign-in (OTP + social both).
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s12,
                vertical: SLSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: SLRadius.brMd,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.userPlus,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Flexible(
                    child: Text(
                      '${context.t('referral_by')}: $referralCode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s24),
          if (_socialGoogle || _socialApple) ...[
            if (_socialGoogle)
              OutlinedButton.icon(
                onPressed: _socialBusy
                    ? null
                    : () => _signInSocial(SocialProvider.google),
                icon: const Icon(PhosphorIconsRegular.googleLogo),
                label: Text(context.t('auth_google')),
              ),
            const SizedBox(height: SLSpacing.s12),
            if (_socialApple)
              OutlinedButton.icon(
                onPressed: _socialBusy
                    ? null
                    : () => _signInSocial(SocialProvider.apple),
                icon: const Icon(PhosphorIconsRegular.appleLogo),
                label: Text(context.t('auth_apple')),
              ),
            const SizedBox(height: SLSpacing.s16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s12,
                  ),
                  child: Text(
                    context.t('auth_or'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: SLSpacing.s16),
          ],
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
                    Icon(
                      PhosphorIconsRegular.code,
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
