/// আমাদের সম্পর্কে + জিজ্ঞাসা (FAQ) + মতামত — the info cluster.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final _feedback = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_feedback.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).feedback(_feedback.text.trim());
      setState(() => _sent = true);
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_about')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          // About
          AppCard(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: SLColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsFill.star,
                      color: SLColors.primaryDeep, size: 32),
                ),
                const SizedBox(height: SLSpacing.s12),
                Text(
                  context.t('app_title'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  context.t('app_about'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s12),

          // Play's rule: the privacy policy is reachable inside the app
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('about_privacy'),
              leading: const Icon(PhosphorIconsRegular.shieldCheck),
              title: Text(context.t('privacy_policy')),
              subtitle: Text(context.t('privacy_policy_sub')),
              trailing: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 18),
              onTap: () => openInAppBrowser('${webBaseFor(ApiClient.baseUrl)}/privacy'),
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // FAQ
          SectionHeader(context.t('more_faq'), icon: PhosphorIconsRegular.question),
          FutureBuilder<List<FaqItem>>(
            future: ContentPack.faq(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Skeleton(height: 48, count: 3);
              }
              final faqs = snap.data ?? const <FaqItem>[];
              if (faqs.isEmpty) {
                return EmptyState(
                    message: context.t('empty_generic'),
                    icon: PhosphorIconsRegular.question);
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < faqs.length; i++)
                      ExpansionTile(
                        shape: const Border(),
                        title: Text(
                          faqs[i].q,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  SLSpacing.s16, 0, SLSpacing.s16, SLSpacing.s12),
                              child: Text(faqs[i].a,
                                  style: theme.textTheme.bodyMedium),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: SLSpacing.s16),

          // Feedback
          SectionHeader(context.t('more_feedback'), icon: PhosphorIconsRegular.star),
          if (_sent)
            AppCard(
              child: Row(
                children: [
                  Icon(PhosphorIconsFill.checkCircle,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(child: Text(context.t('feedback_sent'))),
                ],
              ),
            )
          else
            AppCard(
              child: Column(
                children: [
                  TextField(
                    controller: _feedback,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.t('feedback_hint'),
                      border: InputBorder.none,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                      label: Text(context.t('send')),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: SLSpacing.s24),
        ],
      ),
    );
  }

}
