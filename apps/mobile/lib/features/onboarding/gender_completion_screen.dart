/// One-time gender + name completion (Task B5) — shown when a signed-in
/// account was created via social sign-in WITHOUT a gender (created on
/// another device/platform, or without the onboarding payload). Mirrors the
/// onboarding identity step (same strings + female privacy note), then
/// PATCHes /api/me with {name, gender}. The API sets gender exactly once and
/// locks it afterwards ("লিঙ্গ পরিবর্তন করা যায় না") — leaving this screen
/// incomplete keeps the account functional but gender-scoped features stay
/// off until finished.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class GenderCompletionScreen extends ConsumerStatefulWidget {
  const GenderCompletionScreen({super.key});

  @override
  ConsumerState<GenderCompletionScreen> createState() =>
      _GenderCompletionScreenState();
}

class _GenderCompletionScreenState
    extends ConsumerState<GenderCompletionScreen> {
  late final TextEditingController _name;
  Gender? _gender;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).userOrNull;
    final profile = ref.read(profileProvider);
    _name = TextEditingController(
      // Prefer the guest's onboarding name when the account has none yet.
      text: (user?.name.isNotEmpty ?? false) ? user!.name : profile.name,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _gender != null;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final user = await api.updateMe({
        'name': _name.text.trim(),
        'gender': _gender!.json,
      });
      // Update the session user + the local profile, then head home.
      ref.read(authProvider.notifier).updateUser(user);
      await ref
          .read(profileProvider.notifier)
          .update(name: user.name, gender: user.gender);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('complete_profile_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s20),
        children: [
          Icon(
            PhosphorIconsRegular.identificationBadge,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: SLSpacing.s12),
          Text(
            context.t('complete_profile_note'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s24),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.t('onb_name'),
              hintText: context.t('onb_name_hint'),
            ),
          ),
          const SizedBox(height: SLSpacing.s16),
          Text(context.t('onb_gender'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: SLSpacing.s8),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  selected: _gender == Gender.m,
                  icon: PhosphorIconsRegular.genderMale,
                  title: context.t('onb_male'),
                  onTap: () => setState(() => _gender = Gender.m),
                ),
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: _ChoiceTile(
                  selected: _gender == Gender.f,
                  icon: PhosphorIconsRegular.genderFemale,
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
                color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
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
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s24),
          FilledButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t('done')),
          ),
          if (_error != null) ...[
            const SizedBox(height: SLSpacing.s12),
            ErrorState(message: _error!, onRetry: _save),
          ],
        ],
      ),
    );
  }
}

/// Same option-tile visual as the onboarding identity step (kept local — the
/// onboarding's tile is private to that file).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.onTap,
    required this.selected,
    this.icon,
  });
  final String title;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

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
          constraints: const BoxConstraints(minHeight: SLSpacing.minTapTarget + 8),
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
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  PhosphorIconsFill.checkCircle,
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
