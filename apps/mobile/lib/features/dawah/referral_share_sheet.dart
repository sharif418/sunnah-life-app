/// W4e — the referral card PREVIEW sheet: the card rendered live (aspect
/// locked 4:5, what-you-see-is-what-you-share) + the "শেয়ার করুন" button
/// that renders the PNG off-screen and hands it to the native share sheet.
///
/// Honest degradation: when the platform can't carry a file (iOS stub —
/// SystemChannel.shareFile returns false there, or the render itself fails)
/// the flow falls back to the plain-text share so the invitation still goes
/// out with the join link.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/design_tokens.dart';
import '../../services/platform_channels.dart';
import '../shared/widgets.dart';
import 'referral_card.dart';
import '../../design/phosphor_icons.dart';

/// The capture behind the শেয়ার করুন button — injectable for tests: the
/// engine's toImage/toByteData pipeline is real-async, which the fake-async
/// test zone starves. UX tests inject a stub file; the REAL capture is
/// proven by a dedicated runAsync-driven test of [renderReferralCardPng].
@visibleForTesting
Future<File?> Function(BuildContext context, ReferralCard card)
referralCardCapture = renderReferralCardPng;

/// Opens the referral card preview sheet over the Da'wah overview.
Future<void> showReferralCardSheet(
  BuildContext context, {
  required String memberName,
  required String memberCode,
  required String joinLink,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReferralShareSheet(
      memberName: memberName,
      memberCode: memberCode,
      joinLink: joinLink,
    ),
  );
}

class _ReferralShareSheet extends StatefulWidget {
  const _ReferralShareSheet({
    required this.memberName,
    required this.memberCode,
    required this.joinLink,
  });

  final String memberName;
  final String memberCode;
  final String joinLink;

  @override
  State<_ReferralShareSheet> createState() => _ReferralShareSheetState();
}

class _ReferralShareSheetState extends State<_ReferralShareSheet> {
  bool _busy = false;

  ReferralCard _card() => ReferralCard(
    appTitle: context.t('app_title'),
    tagline: context.t('dawah_card_tagline'),
    memberName: widget.memberName,
    memberCodeLabel: context.t('dawah_member_code'),
    memberCode: widget.memberCode,
    joinLink: widget.joinLink,
  );

  String _shareText() =>
      '${context.t('dawah_share_message')} ${widget.joinLink}';

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    var sharedAsImage = false;
    try {
      final file = await referralCardCapture(context, _card());
      if (file != null) {
        sharedAsImage = await SystemChannel.shareFile(
          path: file.path,
          text: _shareText(),
        );
      }
    } catch (_) {
      // Render or temp-dir failure — the text share below is the fallback.
    }
    if (!sharedAsImage) {
      // iOS (no image handler in the stub) / a platform that refused the
      // file — the invitation text still carries the join link.
      await SystemChannel.shareText(_shareText());
    }
    if (mounted) {
      setState(() => _busy = false);
      // The root ScaffoldMessenger owns snackbars, so the toast outlives
      // the sheet we are about to close.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('dawah_card_shared_toast'))),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bounded height (85% of the screen — the sheet is isScrollControlled)
    // with the preview in an Expanded: the 4:5 card scales to whatever
    // height remains after the texts + button, so the sheet NEVER
    // overflows on short surfaces or large text scales.
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s16,
            SLSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('dawah_card_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s4),
              Text(
                context.t('dawah_card_preview_note'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              // The live card, aspect-locked 4:5 — the exact widget the
              // button renders to PNG (scaled to the remaining height,
              // never reflowed, never overflowing).
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        ReferralCard.size.width / ReferralCard.size.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: SLRadius.brLg,
                        border: Border.all(color: theme.colorScheme.outline),
                        boxShadow: SLElevation.lifted(
                          theme.brightness == Brightness.dark,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: SLRadius.brLg,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: ReferralCard.size.width,
                            height: ReferralCard.size.height,
                            child: _card(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SLSpacing.s16),
              FilledButton.icon(
                key: const Key('referralShareButton'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(SLSpacing.minTapTarget),
                ),
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.shareNetwork),
                label: Text(context.t('dawah_share_now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
