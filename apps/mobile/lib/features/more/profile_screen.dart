/// প্রোফাইল — name, gender (read-only — only Full Admin can change it),
/// category, madhhab, city, language, theme, hijri adjust, OTP sign-in /
/// sign-out, the female privacy note, share + version.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../models/domain.dart';
import '../../services/platform_channels.dart';
import '../../state/providers.dart';
import '../shared/city_picker.dart';
import '../shared/widgets.dart';

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
                    icon: const Icon(Icons.login),
                    label: Text(context.t('onb_signin')),
                    onPressed: () => context.push('/auth'),
                  ),
                ] else ...[
                  const SizedBox(height: SLSpacing.s12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text(context.t('auth_signout')),
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // Identity (read-only gender)
          SectionHeader(context.t('onb_step2_title'), icon: Icons.badge_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(context.t('onb_name')),
                  subtitle: Text(user?.name ?? profile.name),
                  trailing: user == null
                      ? const Icon(Icons.edit_outlined, size: 18)
                      : null,
                  onTap: user == null ? () => _editName(context) : null,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    size: 20,
                  ),
                  title: Text(context.t('onb_gender')),
                  subtitle: Text(
                    '${profile.gender == Gender.f ? context.t('onb_female') : context.t('onb_male')} — ${context.t('gender_admin_only')}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(context.t('profile_category')),
                  subtitle: Text(switch (profile.category) {
                    UserCategory.general => context.t('profile_category_general'),
                    UserCategory.hafez => context.t('profile_category_hafez'),
                    UserCategory.alim => context.t('profile_category_alim'),
                  }),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _pickCategory(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // Prayer settings
          SectionHeader(context.t('onb_step3_title'),
              icon: Icons.location_on_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_city_outlined),
                  title: Text(context.t('onb_city')),
                  subtitle: Text(profile.city),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
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
                  leading: const Icon(Icons.balance_outlined),
                  title: Text(context.t('onb_madhhab')),
                  subtitle: Text(context.t(profile.madhhab.labelKey)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _pickMadhhab(context),
                ),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: Text(context.t('onb_method')),
                  subtitle: Text(context.t(profile.method.labelKey)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _pickMethod(context),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(context.t('hijri_adjust')),
                  subtitle: Text(
                      '${profile.hijriAdjust >= 0 ? '+' : ''}${profile.hijriAdjust}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('hijri_decrease'),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => notifier.update(
                            hijriAdjust:
                                (profile.hijriAdjust - 1).clamp(-2, 2)),
                      ),
                      IconButton(
                        tooltip: context.t('hijri_increase'),
                        icon: const Icon(Icons.add_circle_outline),
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
              icon: Icons.settings_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(context.t('profile_language')),
                  subtitle: Text(
                      LangX.fromCode(profile.language).labelNative),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _pickLanguage(context),
                ),
                ListTile(
                  leading: Icon(theme.brightness == Brightness.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined),
                  title: Text(context.t('profile_theme')),
                  subtitle: Text(switch (profile.themeMode) {
                    'light' => context.t('profile_theme_light'),
                    'dark' => context.t('profile_theme_dark'),
                    _ => context.t('profile_theme_system'),
                  }),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _pickTheme(context),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
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
