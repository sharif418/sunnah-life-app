/// আরও (W4d §4.3) — the More hub as a SECTIONED list: donate + Foundation
/// services, ইবাদত ও টুলস, জ্ঞান, সহায়তা, অ্যাপ (+ app-user group links).
/// Every §4.3 inventory item has exactly one home here; the knowledge tiles
/// point at the SAME /ilm routes (no duplicate screens).
library;

import 'package:package_info_plus/package_info_plus.dart';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../../models/domain.dart';
import '../../services/platform_channels.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show configProvider;
import '../shared/global_header.dart';
import '../shared/widgets.dart';
import 'usrah_join_sheet.dart';
import '../../design/phosphor_icons.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    // C-W3g: the donation tile opens the admin-configured donation URL in
    // the in-app browser (Chrome Custom Tabs). Hidden when the config has
    // no usable http(s) URL — a dead tile is worse than no tile.
    final config = ref
        .watch(configProvider)
        .maybeWhen(data: (c) => c, orElse: () => null);
    final donationUrl = config?.donationUrl ?? '';
    final canDonate = isLaunchableHttpUrl(donationUrl);
    final contacts = config?.contacts ?? const <ConfigContact>[];
    final groups = config?.groups ?? const <ConfigGroup>[];
    // Guard-module seed — the detox tile itself is config-gated.
    final detoxEnabled = config?.detoxEnabled ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          // W5: the list must scroll CLEAR of the floating contact button
          // (52 + 16 + 12 = 80dp) — it used to cover the last rows' chevrons.
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s16,
            kContactFabClearance,
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
                  const DirectionalIcon(PhosphorIconsRegular.caretRight),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s16),

            // ── ফাউন্ডেশন — donate + the five services ──
            SectionHeader(
              context.t('more_section_foundation'),
              icon: PhosphorIconsRegular.handHeart,
            ),
            if (canDonate) _DonateCard(url: donationUrl),
            if (contacts.isNotEmpty)
              _FoundationServicesCard(contacts: contacts),

            // ── ইবাদত ও টুলস ──
            SectionHeader(
              context.t('more_section_worship'),
              icon: PhosphorIconsRegular.mosque,
            ),
            _MoreGroupCard(
              rows: [
                _MoreRow(
                  icon: PhosphorIconsRegular.calculator,
                  title: context.t('more_zakat'),
                  onTap: () => context.push('/more/zakat'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.compass,
                  title: context.t('more_qibla'),
                  onTap: () => context.push('/more/qibla'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.mosque,
                  title: context.t('more_mosque'),
                  onTap: () => context.push('/more/mosques'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.question,
                  title: context.t('more_masala'),
                  onTap: () => context.push('/more/masala'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.broadcast,
                  title: context.t('more_live'),
                  onTap: () => context.push('/more/live'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.minusCircle,
                  title: context.t('more_autosilent'),
                  onTap: () => context.push('/more/autosilent'),
                ),
                // Guard-module seed (W4d) — hidden while the admin flag is off.
                if (detoxEnabled)
                  _MoreRow(
                    icon: PhosphorIconsRegular.shield,
                    title: context.t('more_detox'),
                    onTap: () => context.push('/more/detox'),
                  ),
              ],
            ),

            // ── জ্ঞান ── (same routes as the Ilm tab — no duplicates)
            SectionHeader(
              context.t('more_section_knowledge'),
              icon: PhosphorIconsRegular.graduationCap,
            ),
            _MoreGroupCard(
              rows: [
                _MoreRow(
                  icon: PhosphorIconsRegular.sun,
                  title: context.t('ilm_names99'),
                  onTap: () => context.push('/ilm/names99'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.baby,
                  title: context.t('ilm_baby_names'),
                  onTap: () => context.push('/ilm/islamic-names'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.heart,
                  title: context.t('ilm_iman_branches'),
                  onTap: () => context.push('/ilm/iman-branches'),
                ),
              ],
            ),

            // ── সহায়তা ──
            SectionHeader(
              context.t('more_section_support'),
              icon: PhosphorIconsRegular.headset,
            ),
            _MoreGroupCard(
              rows: [
                _MoreRow(
                  icon: PhosphorIconsRegular.headset,
                  title: context.t('more_support'),
                  onTap: () => context.push('/more/support'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.userPlus,
                  title: context.t('more_usrah_join'),
                  onTap: () => showUsrahJoinSheet(context),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.star,
                  title: context.t('more_feedback'),
                  onTap: () => showFeedbackSheet(context),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.question,
                  title: context.t('more_faq'),
                  onTap: () => context.push('/more/faq'),
                ),
              ],
            ),

            // ── অ্যাপ ──
            SectionHeader(
              context.t('more_section_app'),
              icon: PhosphorIconsRegular.dotsNine,
            ),
            _MoreGroupCard(
              rows: [
                _MoreRow(
                  icon: PhosphorIconsRegular.info,
                  title: context.t('more_about'),
                  onTap: () => context.push('/more/about'),
                ),
                _MoreRow(
                  icon: PhosphorIconsRegular.shareNetwork,
                  title: context.t('more_share_app'),
                  onTap: () => _shareApp(context),
                ),
              ],
            ),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s4),
                child: Text(context.t('more_groups')),
              ),
              const SizedBox(height: SLSpacing.s4),
              _MoreGroupCard(
                rows: [
                  for (final g in groups)
                    _MoreRow(
                      icon: PhosphorIconsRegular.globe,
                      title: g.titleBn,
                      subtitle: g.descBn,
                      onTap: () async {
                        final opened = await openInAppBrowser(g.url);
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.t('group_open_failed')),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ],

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

/// The share flow — the profile-screen idiom: clipboard copy (web/desktop
/// fallback) + the zero-plugin native sheet (SystemChannel, W4-FIX1 note:
/// NO share_plus dependency — a spec deviation documented in the worklog).
Future<void> _shareApp(BuildContext context) async {
  final text = context.t('more_share_text');
  // The native share sheet is the primary action — fire it FIRST, and keep
  // the clipboard copy best-effort: a platform without a clipboard service
  // (or a test bed without a handler) must never break the share itself.
  await SystemChannel.shareText(text);
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {
    // Clipboard is a convenience, not a requirement.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.t('copied')} — ${context.t('more_share_app')}',
        ),
      ),
    );
  }
}

/// দান করুন — gold-accent card (the OfflineBanner token pairing: goldSoft
/// surface + lightGoldText ink in light, darkGoldSoft + darkGoldText in dark).
class _DonateCard extends StatelessWidget {
  const _DonateCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? SLColors.darkGoldSoft : SLColors.goldSoftLight;
    final fg = dark ? SLColors.darkGoldText : SLColors.lightGoldText;
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: Material(
        color: bg,
        borderRadius: SLRadius.brLg,
        child: InkWell(
          borderRadius: SLRadius.brLg,
          onTap: () async {
            final opened = await openInAppBrowser(url);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('donation_open_failed'))),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s16,
              vertical: SLSpacing.s12,
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.handHeart, color: fg),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    context.t('more_donate'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(PhosphorIconsRegular.arrowSquareOut, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The five Foundation institutions (config contacts — the same data the
/// floating Contact panel renders). Whole row → website (fallback: call);
/// trailing icon actions for phone / email when present (44px targets).
class _FoundationServicesCard extends StatelessWidget {
  const _FoundationServicesCard({required this.contacts});
  final List<ConfigContact> contacts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < contacts.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16,
                endIndent: SLSpacing.s16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            _ServiceRow(contact: contacts[i]),
          ],
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.contact});
  final ConfigContact contact;

  Future<bool> _call(String phone) async {
    final uri = Uri.tryParse('tel:${phone.trim()}');
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _email(String email) async {
    final uri = Uri.tryParse('mailto:${email.trim()}');
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _snack(BuildContext context, String key) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.t(key))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhone = (contact.phone ?? '').trim().isNotEmpty;
    final hasEmail = (contact.email ?? '').trim().isNotEmpty;
    final hasSite = isLaunchableHttpUrl(contact.website ?? '');

    return InkWell(
      // Whole row → the org's website (the primary action — every seeded
      // contact has one); falls back to the dialer when only a phone exists.
      onTap: hasSite
          ? () async {
              final opened = await openInAppBrowser(contact.website ?? '');
              if (!opened && context.mounted) {
                _snack(context, 'donation_open_failed');
              }
            }
          : hasPhone
          ? () async {
              final opened = await _call(contact.phone ?? '');
              if (!opened && context.mounted) {
                _snack(context, 'contact_call_failed');
              }
            }
          : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s16,
            vertical: SLSpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.org,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (contact.descBn.isNotEmpty)
                      Text(
                        contact.descBn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasPhone)
                IconButton(
                  tooltip: context.t('contact_call'),
                  icon: const Icon(PhosphorIconsRegular.phone),
                  iconSize: 20,
                  color: theme.colorScheme.primary,
                  onPressed: () async {
                    final opened = await _call(contact.phone ?? '');
                    if (!opened && context.mounted) {
                      _snack(context, 'contact_call_failed');
                    }
                  },
                ),
              if (hasEmail)
                IconButton(
                  tooltip: context.t('contact_email'),
                  icon: const Icon(PhosphorIconsRegular.envelopeSimple),
                  iconSize: 20,
                  color: theme.colorScheme.primary,
                  onPressed: () async {
                    final opened = await _email(contact.email ?? '');
                    if (!opened && context.mounted) {
                      _snack(context, 'group_open_failed');
                    }
                  },
                ),
              if (hasSite)
                IconButton(
                  tooltip: context.t('contact_website'),
                  icon: const Icon(PhosphorIconsRegular.arrowSquareOut),
                  iconSize: 20,
                  color: theme.colorScheme.primary,
                  onPressed: () async {
                    final opened = await openInAppBrowser(
                      contact.website ?? '',
                    );
                    if (!opened && context.mounted) {
                      _snack(context, 'donation_open_failed');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One grouped-card section: hairline dividers between the rows (the Amal
/// Today compact-row idiom).
class _MoreGroupCard extends StatelessWidget {
  const _MoreGroupCard({required this.rows});
  final List<_MoreRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16,
                endIndent: SLSpacing.s16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One More row — the WHOLE row is tappable (44px+; list rows 60–64dp).
class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s16,
            vertical: SLSpacing.s12,
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle?.isNotEmpty ?? false)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const DirectionalIcon(PhosphorIconsRegular.caretRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// মতামত — textarea + POST /api/feedback, from the More tile (kept a
/// sheet per spec; works for guests too — the endpoint is public).
Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet();

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .feedback(text, context: await feedbackContext());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('feedback_sent'))));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SLSpacing.s16,
        0,
        SLSpacing.s16,
        MediaQuery.of(context).viewInsets.bottom + SLSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('more_feedback'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SLSpacing.s12),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: context.t('feedback_hint'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.paperPlaneTilt),
              label: Text(context.t('send')),
            ),
          ),
        ],
      ),
    );
  }
}

/// "app 1.0.0+12 · Android 13 (…)" — attached to each মতামত so the admin
/// knows which build and phone a report came from. Never throws.
Future<String> feedbackContext() async {
  var app = 'app ?';
  try {
    final info = await PackageInfo.fromPlatform();
    app = 'app ${info.version}+${info.buildNumber}';
  } catch (_) {}
  var os = '';
  try {
    if (!kIsWeb) {
      os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
  } catch (_) {}
  final out = [app, if (os.isNotEmpty) os].join(' · ');
  return out.length > 300 ? out.substring(0, 300) : out;
}
