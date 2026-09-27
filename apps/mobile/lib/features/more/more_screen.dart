/// আরও — the More hub: zakat, qibla, mosques, masala, live, about, profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    final entries = <(IconData, String, String)>[
      (Icons.calculate_outlined, context.t('more_zakat'), '/more/zakat'),
      (Icons.explore_outlined, context.t('more_qibla'), '/more/qibla'),
      (Icons.mosque_outlined, context.t('more_mosque'), '/more/mosques'),
      (Icons.help_outline, context.t('more_masala'), '/more/masala'),
      (Icons.podcasts_outlined, context.t('more_live'), '/more/live'),
      (Icons.info_outline, context.t('more_about'), '/more/about'),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s16,
            SLSpacing.s24,
          ),
          children: [
            Text(
              context.t('tab_more'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),

            // Profile card
            AppCard(
              onTap: () => context.push('/more/profile'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (auth.userOrNull?.name.isNotEmpty ?? false)
                          ? auth.user!.name.characters.first
                          : '👤',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userOrNull?.name ??
                              ref.watch(profileProvider).name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          auth.signedIn
                              ? '${auth.user!.role.labelBn}${auth.user!.memberCode != null ? ' · ${auth.user!.memberCode}' : ''}'
                              : context.t('guest'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s16),

            // Feature grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: SLSpacing.s12,
                crossAxisSpacing: SLSpacing.s12,
                childAspectRatio: 1.55,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final (icon, title, route) = entries[i];
                return AppCard(
                  onTap: () => context.push(route),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 30, color: theme.colorScheme.primary),
                        const SizedBox(height: SLSpacing.s8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: SLSpacing.s24),
            Center(
              child: Text(
                'আস-সুন্নাহ ফাউন্ডেশন · দাওয়াতুস সুন্নাহ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
