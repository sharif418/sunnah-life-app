/// Contact panel (C-W4a) — the floating headset button + its bottom sheet.
///
/// The five institutions come from GET /api/config contacts (admin-editable,
/// `AppConfig.contacts`) — parsed since B1 but previously unused on mobile.
/// Each row: org name + Bengali description + a phone action (tel: via
/// url_launcher externalApplication) + a website action (the W3g
/// openInAppBrowser helper — Chrome Custom Tabs / SFSafariViewController).
///
/// Hidden entirely when the config carries no contacts (the fallback config
/// has none) — a dead FAB is worse than no FAB. It sits bottom-END above
/// the nav bar, never over the SyncBadge or any CTA (those live at the top
/// of the screens), and is only mounted on the five root tab paths.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../state/remote_state.dart' show configProvider;
import 'widgets.dart';

/// The floating action: a 52 dp primary circle, elevated, safe-area aware
/// (its parent Stack lives in the scaffold body, ABOVE the bottom bar).
class ContactFab extends ConsumerWidget {
  const ContactFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(configProvider).maybeWhen(
          data: (c) => c.contacts,
          orElse: () => const <ConfigContact>[],
        );
    if (contacts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: context.t('contact_title'),
      child: Material(
        color: theme.colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showContactSheet(context),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              PhosphorIconsFill.headset,
              size: 24,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showContactSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _ContactSheet(),
  );
}

class _ContactSheet extends ConsumerWidget {
  const _ContactSheet();

  /// tel: launch — the in-app browser view cannot dial; phone links always
  /// go to the external dialer (and never throw).
  Future<bool> _call(BuildContext context, String phone) async {
    final uri = Uri.tryParse('tel:${phone.trim()}');
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contacts = ref.watch(configProvider).maybeWhen(
          data: (c) => c.contacts,
          orElse: () => const <ConfigContact>[],
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          0,
          SLSpacing.s16,
          SLSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('contact_title'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SLSpacing.s4),
            Flexible(
              child: contacts.isEmpty
                  ? EmptyState(
                      message: context.t('notifications_empty'),
                      icon: PhosphorIconsRegular.headset,
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in contacts)
                            _ContactRow(
                              contact: c,
                              onCall: () async {
                                final opened = await _call(
                                  context,
                                  c.phone ?? '',
                                );
                                if (!opened && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.t('contact_call_failed'),
                                      ),
                                    ),
                                  );
                                }
                              },
                              onWebsite: () async {
                                final url = c.website ?? '';
                                final opened = await openInAppBrowser(url);
                                if (!opened && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.t('donation_open_failed'),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onCall,
    required this.onWebsite,
  });

  final ConfigContact contact;
  final Future<void> Function() onCall;
  final Future<void> Function() onWebsite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhone = (contact.phone ?? '').trim().isNotEmpty;
    final hasSite = isLaunchableHttpUrl(contact.website ?? '');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.org,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (contact.descBn.isNotEmpty)
            Text(
              contact.descBn,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: SLSpacing.s8),
          Row(
            children: [
              if (hasPhone)
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsFill.phone,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(context.t('contact_call')),
                  onPressed: onCall,
                ),
              if (hasPhone && hasSite) const SizedBox(width: SLSpacing.s8),
              if (hasSite)
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsRegular.globe,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(context.t('contact_website')),
                  onPressed: onWebsite,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
