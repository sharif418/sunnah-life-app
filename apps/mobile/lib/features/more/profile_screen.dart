/// প্রোফাইল — name, gender (read-only — only Full Admin can change it),
/// category, madhhab, city, language, theme, hijri adjust, OTP sign-in /
/// sign-out, the female privacy note, share + version.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../api/api_client.dart' show ApiException;
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../models/domain.dart';
import '../../services/platform_channels.dart';
import '../../state/providers.dart';
import '../shared/city_picker.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final user = auth.userOrNull;
    final notifier = ref.read(profileProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          // Identity card
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (user?.name.isNotEmpty ?? false)
                        ? user!.name.characters.first
                        : (profile.name.isNotEmpty
                            ? profile.name.characters.first
                            : '👤'),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  user?.name ?? (profile.name.isNotEmpty ? profile.name : context.t('guest')),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  user == null
                      ? context.t('guest')
                      : [
                          context.t(user.role.labelKey),
                          if (user.memberCode != null) user.memberCode!,
                          context.t(user.level.labelKey),
                        ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (user == null) ...[
                  const SizedBox(height: SLSpacing.s12),
                  FilledButton.icon(
                    icon: const Icon(PhosphorIconsRegular.signIn),
                    label: Text(context.t('onb_signin')),
                    onPressed: () => context.push('/auth'),
                  ),
                ] else ...[
                  const SizedBox(height: SLSpacing.s12),
                  OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.signOut),
                    label: Text(context.t('auth_signout')),
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // Identity (read-only gender)
          SectionHeader(context.t('onb_step2_title'), icon: PhosphorIconsRegular.identificationBadge),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.user),
                  title: Text(context.t('onb_name')),
                  subtitle: Text(user?.name ?? profile.name),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: user == null
                      ? () => _editName(context)
                      : () => _editAccountField(
                            context,
                            field: 'name',
                            titleKey: 'onb_name',
                            current: user.name,
                          ),
                ),
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.lockSimple,
                    size: 20,
                  ),
                  title: Text(context.t('onb_gender')),
                  subtitle: Text(
                    '${profile.gender == Gender.f ? context.t('onb_female') : context.t('onb_male')} — ${context.t('gender_admin_only')}',
                  ),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.graduationCap),
                  title: Text(context.t('profile_category')),
                  subtitle: Text(switch (profile.category) {
                    UserCategory.general => context.t('profile_category_general'),
                    UserCategory.hafez => context.t('profile_category_hafez'),
                    UserCategory.alim => context.t('profile_category_alim'),
                  }),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () => _pickCategory(context),
                ),
                // The Dawatus Sunnah member register (the old prototypes'
                // inventory): workplace, department, district — kept on the
                // account, visible to the member's own supervisors only.
                // PROF-04: contact e-mail (PATCH /api/me) and the sign-in
                // phone (changed only after an OTP to the new number)
                if (user != null) ...[
                  ListTile(
                    key: const ValueKey('profile_field_phone'),
                    leading: const Icon(PhosphorIconsRegular.phone),
                    title: Text(context.t('profile_phone')),
                    subtitle: Text(
                      (user.phone ?? '').isEmpty
                          ? context.t('profile_not_set')
                          : (context.isBn ? toBn(user.phone!) : user.phone!),
                    ),
                    trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _PhoneChangeSheet(),
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('profile_field_email'),
                    leading: const Icon(PhosphorIconsRegular.envelopeSimple),
                    title: Text(context.t('profile_email')),
                    subtitle: Text(
                      (user.email ?? '').isEmpty ? context.t('profile_not_set') : user.email!,
                    ),
                    trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                    onTap: () => _editAccountField(
                      context,
                      field: 'email',
                      titleKey: 'profile_email',
                      current: user.email ?? '',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
                if (user != null)
                  for (final (field, icon, titleKey, value) in [
                    ('workplace', PhosphorIconsRegular.buildings, 'profile_workplace', user.workplace),
                    ('department', PhosphorIconsRegular.identificationBadge, 'profile_department', user.department),
                    ('district', PhosphorIconsRegular.mapPin, 'profile_district', user.district),
                  ])
                    ListTile(
                      key: ValueKey('profile_field_$field'),
                      leading: Icon(icon),
                      title: Text(context.t(titleKey)),
                      subtitle: Text(
                        (value ?? '').trim().isEmpty ? context.t('profile_not_set') : value!,
                      ),
                      trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                      onTap: () => _editAccountField(
                        context,
                        field: field,
                        titleKey: titleKey,
                        current: value ?? '',
                      ),
                    ),
              ],
            ),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(SLSpacing.s4, SLSpacing.s8, SLSpacing.s4, 0),
              child: Text(
                context.t('profile_inventory_note'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: SLSpacing.s16),

          // Prayer settings
          SectionHeader(context.t('onb_step3_title'),
              icon: PhosphorIconsRegular.mapPin),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.buildings),
                  title: Text(context.t('onb_city')),
                  subtitle: Text(profile.city),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () async {
                    final picked = await showCityPicker(context);
                    if (picked != null) {
                      await notifier.update(
                        city: picked.nameBn,
                        lat: picked.lat,
                        lng: picked.lng,
                        tz: picked.tz,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.scales),
                  title: Text(context.t('onb_madhhab')),
                  subtitle: Text(context.t(profile.madhhab.labelKey)),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () => _pickMadhhab(context),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.calculator),
                  title: Text(context.t('onb_method')),
                  subtitle: Text(context.t(profile.method.labelKey)),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () => _pickMethod(context),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.calendarBlank),
                  title: Text(context.t('hijri_adjust')),
                  subtitle: Text(
                      '${profile.hijriAdjust >= 0 ? '+' : ''}${profile.hijriAdjust}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('hijri_decrease'),
                        icon: const Icon(PhosphorIconsRegular.minusCircle),
                        onPressed: () => notifier.update(
                            hijriAdjust:
                                (profile.hijriAdjust - 1).clamp(-2, 2)),
                      ),
                      IconButton(
                        tooltip: context.t('hijri_increase'),
                        icon: const Icon(PhosphorIconsRegular.plusCircle),
                        onPressed: () => notifier.update(
                            hijriAdjust:
                                (profile.hijriAdjust + 1).clamp(-2, 2)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // App settings
          SectionHeader(context.t('profile_app_section'),
              icon: PhosphorIconsRegular.gear),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.translate),
                  title: Text(context.t('profile_language')),
                  subtitle: Text(
                      LangX.fromCode(profile.language).labelNative),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () => _pickLanguage(context),
                ),
                ListTile(
                  leading: Icon(theme.brightness == Brightness.dark
                      ? PhosphorIconsRegular.moonStars
                      : PhosphorIconsRegular.sun),
                  title: Text(context.t('profile_theme')),
                  subtitle: Text(switch (profile.themeMode) {
                    'light' => context.t('profile_theme_light'),
                    'dark' => context.t('profile_theme_dark'),
                    _ => context.t('profile_theme_system'),
                  }),
                  trailing: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  onTap: () => _pickTheme(context),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.shareNetwork),
                  title: Text(context.t('more_share_app')),
                  onTap: () async {
                    final text = context.t('more_share_text');
                    await Clipboard.setData(ClipboardData(text: text));
                    await SystemChannel.shareText(text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('${context.t('copied')} — ${context.t('more_share_app')}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Female privacy note
          if (profile.gender == Gender.f) ...[
            const SizedBox(height: SLSpacing.s16),
            Container(
              padding: const EdgeInsets.all(SLSpacing.s12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                borderRadius: SLRadius.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌸'),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('profile_female_privacy_title'),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.t('onb_female_privacy'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s24),
          Center(
            child: Text(
              _version.isEmpty
                  ? context.t('version')
                  : '${context.t('version')} ${context.isBn ? _version : _version}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _editName(BuildContext context) async {
    final controller =
        TextEditingController(text: ref.read(profileProvider).name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('onb_name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.t('onb_name_hint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(context.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(context.t('save'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(profileProvider.notifier).update(name: name);
    }
  }

  /// Edit one account field through PATCH /api/me and refresh the signed-in
  /// user (name, workplace, department, district).
  Future<void> _editAccountField(
    BuildContext context, {
    required String field,
    required String titleKey,
    required String current,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t(titleKey)),
        content: TextField(
          key: ValueKey('profile_edit_$field'),
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          maxLength: field == 'name' ? 80 : (field == 'email' ? 200 : 160),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(dialogContext.t('save')),
          ),
        ],
      ),
    );
    if (value == null || value == current.trim()) return;
    if (field == 'name' && value.isEmpty) return;
    try {
      final updated = await ref.read(apiProvider).updateMe({field: value});
      ref.read(authProvider.notifier).updateUser(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('profile_saved'))),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showModalBottomSheet<UserCategory>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in UserCategory.values)
              ListTile(
                title: Text(switch (c) {
                  UserCategory.general => context.t('profile_category_general'),
                  UserCategory.hafez => context.t('profile_category_hafez'),
                  UserCategory.alim => context.t('profile_category_alim'),
                }),
                subtitle: Text(switch (c) {
                  UserCategory.general => context.t('tilawat_target_general'),
                  UserCategory.hafez => context.t('tilawat_target_hafez'),
                  UserCategory.alim => context.t('tilawat_target_alim'),
                }),
                selected:
                    c == ref.read(profileProvider).category,
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(profileProvider.notifier).update(category: picked);
    }
  }

  Future<void> _pickMadhhab(BuildContext context) async {
    final picked = await showModalBottomSheet<Madhhab>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in Madhhab.values)
              ListTile(
                title: Text(context.t(m.labelKey)),
                selected: m == ref.read(profileProvider).madhhab,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(profileProvider.notifier).update(madhhab: picked);
    }
  }

  Future<void> _pickMethod(BuildContext context) async {
    final picked = await showModalBottomSheet<CalcMethod>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in CalcMethod.values)
              ListTile(
                title: Text(context.t(m.labelKey)),
                selected: m == ref.read(profileProvider).method,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(profileProvider.notifier).update(method: picked);
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showModalBottomSheet<Lang>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in Lang.values)
              ListTile(
                title: Text(l.labelNative),
                selected:
                    l == LangX.fromCode(ref.read(profileProvider).language),
                onTap: () => Navigator.pop(context, l),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(profileProvider.notifier).update(language: picked.code);
    }
  }

  Future<void> _pickTheme(BuildContext context) async {
    final current = ref.read(profileProvider).themeMode;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, label) in [
              ('system', context.t('profile_theme_system')),
              ('light', context.t('profile_theme_light')),
              ('dark', context.t('profile_theme_dark')),
            ])
              ListTile(
                title: Text(label),
                selected: key == current,
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(profileProvider.notifier).update(themeMode: picked);
    }
  }
}

/// PROF-04: add or change the sign-in phone. Two steps on one sheet — the new
/// number, then the 6-digit code sent to it; the account switches only after
/// the code is verified.
class _PhoneChangeSheet extends ConsumerStatefulWidget {
  const _PhoneChangeSheet();

  @override
  ConsumerState<_PhoneChangeSheet> createState() => _PhoneChangeSheetState();
}

class _PhoneChangeSheetState extends ConsumerState<_PhoneChangeSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dev = await ref.read(apiProvider).requestPhoneChange(_phone.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        if (dev != null) _code.text = dev; // mock SMS (dev/staging only)
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(apiProvider)
          .verifyPhoneChange(_phone.text.trim(), _code.text.trim());
      ref.read(authProvider.notifier).updateUser(user);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('profile_phone_changed'))),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SLSpacing.s16,
        0,
        SLSpacing.s16,
        MediaQuery.viewInsetsOf(context).bottom + SLSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('profile_phone_change_title'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('profile_phone_change_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          TextField(
            key: const ValueKey('phone_change_number'),
            controller: _phone,
            enabled: !_codeSent && !_busy,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.t('profile_phone_new'),
              hintText: '01XXXXXXXXX',
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: SLSpacing.s8),
            TextField(
              key: const ValueKey('phone_change_code'),
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(labelText: context.t('auth_otp')),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: SLSpacing.s4),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: SLSpacing.s12),
          FilledButton(
            key: const ValueKey('phone_change_submit'),
            onPressed: _busy ? null : (_codeSent ? _verify : _send),
            child: Text(
              context.t(_codeSent ? 'profile_phone_verify' : 'profile_phone_send_code'),
            ),
          ),
        ],
      ),
    );
  }
}
