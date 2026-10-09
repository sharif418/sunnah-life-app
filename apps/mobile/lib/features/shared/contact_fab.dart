/// Contact panel (C-W4a) — the floating headset button + its bottom sheet.
///
/// 2026-10-10: the sheet opened on five near-identical institution cards
/// with only a website chip — nothing a headset promises. It now leads with
/// help for the app (live support, FAQ, masala), then the institutions as
/// one compact list (row → website; mail/call buttons where given).
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
import 'package:go_router/go_router.dart';

import '../../design/phosphor_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../state/remote_state.dart' show configProvider;
import 'widgets.dart';

/// Bottom clearance for scrollables that sit under the floating contact
/// button on the five root tabs (W5): the FAB is 52dp tall and floats 16dp
/// above the nav bar, so list content needs 52 + 16 + 12 (breathing gap)
/// = 80dp of trailing padding to scroll clear of it — otherwise it covers
/// the chevrons of the last visible rows.
const double kContactFabClearance = 52 + SLSpacing.s16 + SLSpacing.s12;

/// The floating action: a 52 dp primary circle, elevated, safe-area aware
/// (its parent Stack lives in the scaffold body, ABOVE the bottom bar).
class ContactFab extends ConsumerWidget {
  const ContactFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref
        .watch(configProvider)
        .maybeWhen(
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
    isScrollControlled: true,
    builder: (context) => const _ContactSheet(),
  );
}

/// "সাহায্য ও যোগাযোগ": what a headset promises first — help with the app
/// (live support, FAQ, a question for the mufti) — then the institutions
/// as one compact list (tap a row for its website; mail/call where given).
class _ContactSheet extends ConsumerWidget {
  const _ContactSheet();

  /// tel:/mailto: go to the phone's own app (and never throw).
  static Future<bool> _launch(String scheme, String to) async {
    final uri = Uri.tryParse('$scheme:${to.trim()}');
    if (uri == null || to.trim().isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contacts = ref
        .watch(configProvider)
        .maybeWhen(
          data: (c) => c.contacts,
          orElse: () => const <ConfigContact>[],
        );

    // take the router before the sheet closes — its context goes with it
    void go(String path) {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(path);
    }

    void failed(String key) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t(key))));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          0,
          SLSpacing.s16,
          SLSpacing.s24,
        ),
        children: [
          Text(
            context.t('contact_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('contact_sub'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s16),
          MenuGroupCard(
            rows: [
              MenuRow(
                key: const ValueKey('contact_support'),
                icon: PhosphorIconsRegular.headset,
                title: context.t('more_support'),
                subtitle: context.t('contact_support_sub'),
                onTap: () => go('/more/support'),
              ),
              MenuRow(
                icon: PhosphorIconsRegular.question,
                title: context.t('more_faq'),
                subtitle: context.t('about_faq_sub'),
                onTap: () => go('/more/faq'),
              ),
              MenuRow(
                icon: PhosphorIconsRegular.chatCircle,
                title: context.t('more_masala'),
                subtitle: context.t('contact_masala_sub'),
                onTap: () => go('/more/masala'),
              ),
            ],
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s8),
            SectionHeader(
              context.t('contact_orgs'),
              icon: PhosphorIconsRegular.buildings,
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, c) in contacts.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: SLSpacing.s16,
                        endIndent: SLSpacing.s16,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    _OrgRow(
                      contact: c,
                      onWebsite: () async {
                        if (!await openInAppBrowser(c.website ?? '')) {
                          failed('donation_open_failed');
                        }
                      },
                      onEmail: () async {
                        if (!await _launch('mailto', c.email ?? '')) {
                          failed('donation_open_failed');
                        }
                      },
                      onCall: () async {
                        if (!await _launch('tel', c.phone ?? '')) {
                          failed('contact_call_failed');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One institution: name and what it does; the row opens its website, the
/// small buttons mail or call it where the Foundation gave those.
class _OrgRow extends StatelessWidget {
  const _OrgRow({
    required this.contact,
    required this.onWebsite,
    required this.onEmail,
    required this.onCall,
  });

  final ConfigContact contact;
  final Future<void> Function() onWebsite;
  final Future<void> Function() onEmail;
  final Future<void> Function() onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final org = contact.org;
    final hasPhone = (contact.phone ?? '').trim().isNotEmpty;
    final hasMail = (contact.email ?? '').trim().isNotEmpty;
    final hasSite = isLaunchableHttpUrl(contact.website ?? '');
    String a11y(String key) => context.t(key).replaceAll('%o', org);
    return InkWell(
      onTap: hasSite ? onWebsite : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SLSpacing.s16,
          SLSpacing.s12,
          SLSpacing.s4,
          SLSpacing.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (contact.descBn.isNotEmpty)
                    Text(
                      contact.descBn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (hasPhone)
              IconButton(
                tooltip: a11y('contact_call_a11y'),
                onPressed: onCall,
                icon: Icon(PhosphorIconsRegular.phone, color: cs.primary),
              ),
            if (hasMail)
              IconButton(
                tooltip: a11y('contact_email_a11y'),
                onPressed: onEmail,
                icon: Icon(
                  PhosphorIconsRegular.envelopeSimple,
                  color: cs.primary,
                ),
              ),
            if (hasSite)
              IconButton(
                tooltip: a11y('contact_site_a11y'),
                onPressed: onWebsite,
                icon: Icon(
                  PhosphorIconsRegular.arrowSquareOut,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
