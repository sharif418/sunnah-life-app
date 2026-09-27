/// Onboarding — 3 steps (ভাষা / নাম+লিঙ্গ+গোপনীয়তা / শহর+মাযহাব+পদ্ধতি),
/// guest-mode start, sign-in entry, and the female privacy trust note.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bn_digits.dart';
import '../../core/cities.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../shared/city_picker.dart';
import '../shared/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  late final TextEditingController _name;
  Gender? _gender;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _name = TextEditingController(text: p.name);
    _gender = p.onboardingDone ? p.gender : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canNext =>
      _step == 0 ||
      (_step == 1 && _name.text.trim().isNotEmpty && _gender != null) ||
      _step == 2;

  Future<void> _finish() async {
    await ref
        .read(profileProvider.notifier)
        .update(
          name: _name.text.trim(),
          gender: _gender ?? Gender.m,
          onboardingDone: true,
        );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      body: Column(
        children: [
          // Hero header
          Container(
            width: double.infinity,
            color: SLColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + SLSpacing.s24,
              bottom: SLSpacing.s24,
              left: SLSpacing.s20,
              right: SLSpacing.s20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: SLColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: SLColors.primaryDeep,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'সুন্নাহ লাইফ',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: SLColors.lightPrimaryForeground,
                          ),
                        ),
                        Text(
                          'আস-সুন্নাহ ফাউন্ডেশন — দাওয়াতুস সুন্নাহ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SLColors.lightPrimaryForeground
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s20),
                ClipRRect(
                  borderRadius: SLRadius.brPill,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (_step + 1) / 3),
                    duration: SLMotion.slow,
                    curve: SLMotion.standard,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: SLColors.lightPrimaryForeground
                          .withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(SLColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  '${context.isBn ? toBn(_step + 1) : _step + 1} / ${context.isBn ? toBn(3) : 3} — সেটআপ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SLColors.lightPrimaryForeground.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Steps
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(SLSpacing.s20),
              children: [
                if (_step == 0) ..._languageStep(context, profile.language),
                if (_step == 1) ..._identityStep(context),
                if (_step == 2) ..._locationStep(context, profile),
              ],
            ),
          ),
          // Footer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SLSpacing.s20,
                SLSpacing.s8,
                SLSpacing.s20,
                SLSpacing.s16,
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(context.t('back')),
                    ),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canNext
                          ? () {
                              if (_step < 2) {
                                setState(() => _step++);
                              } else {
                                _finish();
                              }
                            }
                          : null,
                      child: Text(
                        _step < 2
                            ? context.t('next')
                            : 'বিসমিল্লাহ — শুরু করুন',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _languageStep(BuildContext context, String current) {
    return [
      Text(
        context.t('onb_step1_title'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: SLSpacing.s16),
      for (final l in Lang.values)
        Padding(
          padding: const EdgeInsets.only(bottom: SLSpacing.s12),
          child: _OptionTile(
            selected: current == l.code,
            title: l.labelNative,
            subtitle: switch (l) {
              Lang.bn => 'বাংলাদেশের প্রধান ভাষা',
              Lang.en => 'For international users',
              Lang.ar => 'بالدعم الكامل للاتجاه من اليمين إلى اليسار',
            },
            onTap: () =>
                ref.read(profileProvider.notifier).update(language: l.code),
          ),
        ),
    ];
  }

  List<Widget> _identityStep(BuildContext context) {
    return [
      Text(
        context.t('onb_step2_title'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: SLSpacing.s16),
      TextField(
        controller: _name,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: context.t('onb_name'),
          hintText: context.t('onb_name_hint'),
        ),
      ),
      const SizedBox(height: SLSpacing.s16),
      Text(
        context.t('onb_gender'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: SLSpacing.s8),
      Row(
        children: [
          Expanded(
            child: _OptionTile(
              selected: _gender == Gender.m,
              icon: Icons.man_outlined,
              title: context.t('onb_male'),
              onTap: () => setState(() => _gender = Gender.m),
            ),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: _OptionTile(
              selected: _gender == Gender.f,
              icon: Icons.woman_outlined,
              title: context.t('onb_female'),
              onTap: () => setState(() => _gender = Gender.f),
            ),
          ),
        ],
      ),
      if (_gender == Gender.f) ...[
        const SizedBox(height: SLSpacing.s12),
        Container(
          padding: const EdgeInsets.all(SLSpacing.s12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
            borderRadius: SLRadius.brMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌸'),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  context.t('onb_female_privacy'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _locationStep(BuildContext context, ProfileState profile) {
    final theme = Theme.of(context);
    final city = findCity(profile.city);
    return [
      Text(context.t('onb_step3_title'), style: theme.textTheme.titleMedium),
      const SizedBox(height: SLSpacing.s16),
      _OptionTile(
        icon: Icons.location_on_outlined,
        title: city?.nameBn ?? profile.city,
        subtitle: city == null || !city.isBd ? 'বিদেশ' : 'বাংলাদেশ',
        onTap: () async {
          final picked = await showCityPicker(context);
          if (picked != null) {
            await ref
                .read(profileProvider.notifier)
                .update(
                  city: picked.nameBn,
                  lat: picked.lat,
                  lng: picked.lng,
                  tz: picked.tz,
                );
          }
        },
      ),
      const SizedBox(height: SLSpacing.s16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('onb_madhhab'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: SLSpacing.s8),
                SegmentedButton<Madhhab>(
                  segments: [
                    ButtonSegment(
                      value: Madhhab.hanafi,
                      label: Text(Madhhab.hanafi.labelBn),
                    ),
                    ButtonSegment(
                      value: Madhhab.shafii,
                      label: Text(Madhhab.shafii.labelBn),
                    ),
                  ],
                  selected: {profile.madhhab},
                  onSelectionChanged: (s) => ref
                      .read(profileProvider.notifier)
                      .update(madhhab: s.first),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: SLSpacing.s16),
      Text(context.t('onb_method'), style: theme.textTheme.bodyMedium),
      const SizedBox(height: SLSpacing.s8),
      DropdownButtonFormField<CalcMethod>(
        initialValue: profile.method,
        decoration: const InputDecoration(isDense: true),
        items: [
          for (final m in CalcMethod.values)
            DropdownMenuItem(value: m, child: Text(m.labelBn)),
        ],
        onChanged: (m) {
          if (m != null) {
            ref.read(profileProvider.notifier).update(method: m);
          }
        },
      ),
      const SizedBox(height: SLSpacing.s12),
      Text(
        'বাংলাদেশের জন্য ডিফল্ট: করাচি পদ্ধতি ও হানাফি আসর। সব হিসাব আপনার ফোনেই হয় — ইন্টারনেট ছাড়াও কাজ করবে।',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: SLSpacing.s16),
      OutlinedButton.icon(
        icon: const Icon(Icons.login),
        label: Text(context.t('onb_signin')),
        onPressed: () => context.push('/auth'),
      ),
    ];
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.onTap,
    this.selected = false,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: SLRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brMd,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: SLSpacing.minTapTarget + 8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: SLSpacing.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: SLRadius.brMd,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SLSpacing.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
