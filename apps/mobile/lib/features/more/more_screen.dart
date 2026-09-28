/// আরও — the More hub: donate, zakat, qibla, mosques, masala, live,
/// about, profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show configProvider;
import '../shared/global_header.dart';
import '../shared/widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    // C-W3g: the donation tile opens the admin-configured donation URL in
    // the in-app browser (Chrome Custom Tabs). Hidden when the config has
    // no usable http(s) URL — a dead tile is worse than no tile.
    final donationUrl = ref.watch(configProvider).maybeWhen(
      data: (c) => c.donationUrl,
      orElse: () => '',
    );
    final canDonate = isLaunchableHttpUrl(donationUrl);

    final entries = <({IconData icon, String title, VoidCallback onTap})>[
      if (canDonate)
        (
          icon: Icons.volunteer_activism_outlined,
          title: context.t('more_donate'),
          onTap: () async {
            final opened = await openInAppBrowser(donationUrl);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('donation_open_failed'))),
              );
            }
          },
        ),
      (
        icon: Icons.calculate_outlined,
        title: context.t('more_zakat'),
        onTap: () => context.push('/more/zakat'),
      ),
      (
        icon: Icons.explore_outlined,
        title: context.t('more_qibla'),
        onTap: () => context.push('/more/qibla'),
      ),
      (
        icon: Icons.do_not_disturb_on_outlined,
        title: context.t('more_autosilent'),
        onTap: () => context.push('/more/autosilent'),
      ),
      (
        icon: Icons.mosque_outlined,
        title: context.t('more_mosque'),
        onTap: () => context.push('/more/mosques'),
      ),
      (
        icon: Icons.help_outline,
        title: context.t('more_masala'),
        onTap: () => context.push('/more/masala'),
      ),
      (
        icon: Icons.podcasts_outlined,
        title: context.t('more_live'),
        onTap: () => context.push('/more/live'),
      ),
      (
        icon: Icons.info_outline,
        title: context.t('more_about'),
        onTap: () => context.push('/more/about'),
      ),
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
            // C-W4a: the shared global header (logo, location, triple
            // calendar, notification/reminder/profile, sync badge).
            const GlobalHeader(),
            const SizedBox(height: SLSpacing.s8),
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
                              ? '${context.t(auth.user!.role.labelKey)}${auth.user!.memberCode != null ? ' · ${auth.user!.memberCode}' : ''}'
                              : context.t('guest'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const DirectionalIcon(Icons.chevron_right),
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
                final entry = entries[i];
                return AppCard(
                  onTap: entry.onTap,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          entry.icon,
                          size: 30,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: SLSpacing.s8),
                        Text(
                          entry.title,
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
                context.t('org_footer'),
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
