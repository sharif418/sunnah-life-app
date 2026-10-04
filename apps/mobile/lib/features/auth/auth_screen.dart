/// সাইন ইন — one calm screen, two ways in.
///
///  1. Google (the primary path: free, no SMS, one tap for most members) —
///     shown when GET /api/auth/providers enables it AND this build carries
///     the client id (--dart-define GOOGLE_SERVER_CLIENT_ID).
///  2. Mobile number + 6-digit code (request → verify), with a resend timer
///     and "নম্বর বদলান". On staging (mock SMS) the server returns the code
///     and the screen offers it with a one-tap fill — production never sends
///     one (shouldExposeDevCode is the server-side gate).
///
/// Guests can always step back ("এখন নয়"). On success the guest's local amal
/// diary rides along (the server merges by latest clientUpdatedAt); a
/// pending /join referral rides along on both paths. Gender-less social
/// accounts are routed to /complete-profile by the router.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/brand_mark.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../l10n/app_strings.dart';
import '../../services/social_signin_service.dart';
import '../../state/providers.dart';
import '../../state/referral_state.dart';
import '../shared/widgets.dart';
import 'google_g_logo.dart';

const _kResendAfter = 30;

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.debugForceGoogle = false});

  /// Tests/renders: show the Google button without the platform plugin.
  @visibleForTesting
  final bool debugForceGoogle;

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
  int _resendIn = 0;
  Timer? _resendTimer;

  bool _socialGoogle = false;
  bool _socialApple = false;
  bool _socialBusy = false;

  @override
  void initState() {
    super.initState();
    _socialGoogle = widget.debugForceGoogle;
    _loadProviders();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Which social buttons to show: server-enabled AND locally configured.
  /// Offline/failed fetch or `flutter test` ⇒ hidden (the phone path is
  /// always there).
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
      // offline / server down — social stays hidden, the phone path works
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
      if (mounted) context.go('/');
    } on SocialSignInCanceled {
      // the member closed the Google sheet — quietly back here
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = S.tr(context.lang, 'auth_social_error'));
    } finally {
      if (mounted) setState(() => _socialBusy = false);
    }
  }

  bool get _phoneValid => RegExp(r'^01[3-9]\d{8}$').hasMatch(_asciiPhone);

  /// Bengali digits typed on a Bengali keyboard are accepted.
  String get _asciiPhone => _phone.text.trim().replaceAllMapped(
    RegExp('[০-৯]'),
    (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m.group(0)!)}',
  );

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _kResendAfter);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _requestOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).requestOtp(_asciiPhone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devCode = res.devCode;
        _code.clear();
      });
      _startResendTimer();
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
      final profile = ref.read(profileProvider);
      final referral = ref.read(pendingReferralProvider).valueOrNull;
      await ref
          .read(authProvider.notifier)
          .signIn(
            phone: _asciiPhone,
            code: _code.text.trim(),
            name: profile.name,
            gender: profile.gender,
            referredByCode: referral,
          );
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _devCode = null;
      _resendIn = 0;
      _error = null;
      _code.clear();
    });
  }

  void _notNow() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final referralCode = ref.watch(pendingReferralProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: [
          TextButton(
            key: const ValueKey('auth_not_now'),
            onPressed: _notNow,
            child: Text(context.t('auth_not_now')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s20,
            0,
            SLSpacing.s20,
            SLSpacing.s24,
          ),
          children: [
            // ── who we are ───────────────────────────────────────────────
            const Center(child: SLBrandMark(size: 64)),
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('auth_welcome'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            // the code step is one task: the intro and Google step aside
            if (!_codeSent) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(
                context.t('auth_welcome_sub'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SLSpacing.s16),

              // ── why an account ───────────────────────────────────────────
              AppCard(
                child: Column(
                  children: [
                    for (final (icon, key) in const [
                      (PhosphorIconsRegular.cloudCheck, 'guest_nudge_backup'),
                      (PhosphorIconsRegular.usersThree, 'guest_nudge_usrah'),
                      (PhosphorIconsRegular.trendUp, 'guest_nudge_journey'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SLSpacing.s4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(icon, size: 20, color: cs.primary),
                            ),
                            const SizedBox(width: SLSpacing.s12),
                            Expanded(
                              child: Text(
                                context.t(key),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (referralCode != null) ...[
                const SizedBox(height: SLSpacing.s12),
                _ReferralChip(code: referralCode),
              ],
              const SizedBox(height: SLSpacing.s20),

              // ── 1. Google ────────────────────────────────────────────────
              if (_socialGoogle) ...[
                _GoogleButton(
                  busy: _socialBusy,
                  onPressed: _socialBusy || _sending || _verifying
                      ? null
                      : () => _signInSocial(SocialProvider.google),
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  context.t('auth_google_hint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (_socialApple) ...[
                const SizedBox(height: SLSpacing.s12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _socialBusy
                      ? null
                      : () => _signInSocial(SocialProvider.apple),
                  icon: const Icon(PhosphorIconsRegular.appleLogo),
                  label: Text(context.t('auth_apple')),
                ),
              ],
              if (_socialGoogle || _socialApple) ...[
                const SizedBox(height: SLSpacing.s16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SLSpacing.s12,
                      ),
                      child: Text(
                        context.t('auth_or_phone'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: SLSpacing.s16),
              ],
            ] else
              const SizedBox(height: SLSpacing.s20),

            // ── 2. mobile number + code ──────────────────────────────────
            if (!_codeSent) ...[
              TextField(
                key: const ValueKey('auth_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9০-৯]')),
                ],
                maxLength: 11,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) =>
                    _phoneValid && !_sending ? _requestOtp() : null,
                decoration: InputDecoration(
                  labelText: context.t('auth_phone'),
                  hintText: context.t('auth_phone_hint'),
                  prefixIcon: const Icon(PhosphorIconsRegular.phone),
                  counterText: '',
                  errorText: _phone.text.length >= 11 && !_phoneValid
                      ? context.t('auth_invalid_phone')
                      : null,
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              _ProgressButton(
                key: const ValueKey('auth_send'),
                busy: _sending,
                label: context.t('auth_request_otp'),
                onPressed: _phoneValid && !_sending && !_socialBusy
                    ? _requestOtp
                    : null,
                filled: !_socialGoogle, // Google leads when present
              ),
            ] else ...[
              Text(
                context
                    .t('auth_code_sent_to')
                    .replaceAll('%n%', bn ? toBn(_asciiPhone) : _asciiPhone),
                style: theme.textTheme.bodyMedium,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('auth_change_number'),
                  onPressed: _verifying ? null : _changeNumber,
                  child: Text(context.t('auth_change_number')),
                ),
              ),
              if (_devCode != null)
                // staging only: the server sends the code (mock SMS)
                Padding(
                  padding: const EdgeInsets.only(bottom: SLSpacing.s12),
                  child: Material(
                    color: cs.tertiaryContainer,
                    borderRadius: SLRadius.brMd,
                    child: InkWell(
                      key: const ValueKey('auth_dev_code_fill'),
                      borderRadius: SLRadius.brMd,
                      onTap: () => setState(() => _code.text = _devCode!),
                      child: Padding(
                        padding: const EdgeInsets.all(SLSpacing.s12),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsRegular.code,
                              color: cs.onTertiaryContainer,
                            ),
                            const SizedBox(width: SLSpacing.s8),
                            Expanded(
                              child: Text(
                                '${context.t('auth_dev_code')}: ${bn ? toBn(_devCode!) : _devCode!}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              context.t('auth_dev_fill'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              TextField(
                key: const ValueKey('auth_code'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (v) {
                  setState(() => _error = null);
                  if (v.length == 6 && !_verifying) _verify();
                },
                decoration: InputDecoration(
                  labelText: context.t('auth_otp'),
                  hintText: '••••••',
                  counterText: '',
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              _ProgressButton(
                key: const ValueKey('auth_verify'),
                busy: _verifying,
                label: context.t('auth_verify'),
                onPressed: _code.text.length >= 4 && !_verifying
                    ? _verify
                    : null,
                filled: true,
              ),
              const SizedBox(height: SLSpacing.s4),
              Center(
                child: _resendIn > 0
                    ? Text(
                        context
                            .t('auth_resend_in')
                            .replaceAll(
                              '%n%',
                              bn ? toBn(_resendIn) : '$_resendIn',
                            ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : TextButton(
                        key: const ValueKey('auth_resend'),
                        onPressed: _sending ? null : _requestOtp,
                        child: Text(context.t('auth_resend')),
                      ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: SLSpacing.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 20,
                    color: cs.error,
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── trust ────────────────────────────────────────────────────
            const SizedBox(height: SLSpacing.s24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIconsRegular.lockSimple,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: Text(
                    context.t('auth_privacy'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              context.t('auth_guest_note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google's sign-in button look: a neutral surface, the four-colour G,
/// "Google দিয়ে চালিয়ে যান".
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return OutlinedButton(
      key: const ValueKey('auth_google'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
        foregroundColor: dark
            ? const Color(0xFFE3E3E3)
            : const Color(0xFF1F1F1F),
        side: BorderSide(
          color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
        ),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleGLogo(size: 20),
                const SizedBox(width: SLSpacing.s12),
                Flexible(
                  child: Text(
                    context.t('auth_google_continue'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFFE3E3E3)
                          : const Color(0xFF1F1F1F),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProgressButton extends StatelessWidget {
  const _ProgressButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
    required this.filled,
  });
  final bool busy;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(50)),
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _ReferralChip extends StatelessWidget {
  const _ReferralChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s12,
        vertical: SLSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: SLRadius.brMd,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.userPlus, size: 18, color: cs.primary),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              '${context.t('referral_by')}: $code',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
