/// W4e — the branded referral share card: a fixed 1080×1350 design (deep
/// green + cream + gold, bundled SolaimanLipi only) that the Da'wah
/// overview renders to a PNG via `RepaintBoundary.toImage` and shares
/// through SystemChannel.shareFile (ACTION_SEND image/* + FileProvider).
///
/// The card paints with EXPLICIT token colors — never Theme.of — so the
/// shared image is identical in light and dark mode (a dark-mode phone must
/// not ship a dark-mode da'wah card; the brand is the brand).
///
/// Note: lib/features/app/logo.dart does not exist in this repo — the mark
/// below mirrors the _SplashLogo idiom from app.dart (gold circle + star,
/// token colors) instead of inventing a new one.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';

/// The shared referral card. Fixed design surface — NOT reflowed for any
/// screen; the preview scales it with FittedBox, the PNG renders it
/// off-screen at exactly [size] logical px (pixelRatio 1).
class ReferralCard extends StatelessWidget {
  const ReferralCard({
    super.key,
    required this.appTitle,
    required this.tagline,
    required this.memberName,
    required this.memberCodeLabel,
    required this.memberCode,
    required this.joinLink,
  });

  /// Design surface: 1080×1350 (4:5 portrait) — screen-independent by
  /// construction because the renderer lays it out at exactly this size.
  static const Size size = Size(1080, 1350);

  /// App wordmark (context.t('app_title')).
  final String appTitle;

  /// One-line da'wah tagline (context.t('dawah_card_tagline')).
  final String tagline;

  /// The sharing member's display name ('' hides the row).
  final String memberName;

  /// Small label over the big code (context.t('dawah_member_code')).
  final String memberCodeLabel;

  /// The member's referral code — the hero of the card, in gold.
  final String memberCode;

  /// The join link (https://sunnahlife.app/join/<code>).
  final String joinLink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: SLColors.primaryDeep),
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: Column(
            children: [
              // ── Logo mark + wordmark ─────────────────────────────────
              const _LogoMark(diameter: 132, starSize: 76),
              const SizedBox(height: 24),
              _CardText(
                text: appTitle,
                fontSize: 54,
                fontWeight: FontWeight.w700,
                color: SLColors.lightPrimaryForeground,
                letterSpacing: 2,
              ),
              const SizedBox(height: 48),
              const _Hairline(color: SLColors.gold),
              const SizedBox(height: 48),
              // ── Da'wah tagline ───────────────────────────────────────
              _CardText(
                text: tagline,
                fontSize: 44,
                fontWeight: FontWeight.w600,
                color: SLColors.lightPrimaryForeground,
                height: 1.6,
                maxLines: 2,
              ),
              const Spacer(),
              // ── The invitation panel ──────────────────────────────────
              _InvitePanel(
                memberName: memberName,
                memberCodeLabel: memberCodeLabel,
                memberCode: memberCode,
                joinLink: joinLink,
              ),
              const Spacer(),
              // gold @ 35% — the base rule framing the card. W4f dark pass:
              // token + alpha, not a raw ARGB literal (0x59 = 89 = 89/255 —
              // byte-identical to the legacy Color(0x59C99A3B)).
              _Hairline(color: SLColors.gold.withValues(alpha: 89 / 255)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold circle + star — the app's logo mark (the _SplashLogo idiom).
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.diameter, required this.starSize});
  final double diameter;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        color: SLColors.gold,
        shape: BoxShape.circle,
      ),
      child: Icon(
        PhosphorIconsFill.star,
        color: SLColors.primaryDeep,
        size: starSize,
      ),
    );
  }
}

/// Every text on the card renders through the bundled SolaimanLipi family
/// (tofu rule) with explicit token colors — no theme, no fallback family.
class _CardText extends StatelessWidget {
  const _CardText({
    required this.text,
    required this.fontSize,
    required this.color,
    this.fontWeight,
    this.height,
    this.letterSpacing,
    this.maxLines,
  });

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight? fontWeight;
  final double? height;
  final double? letterSpacing;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: kAppFontFamily,
        fontFamilyFallback: kAppFontFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, height: 2, color: color);
  }
}

/// Cream invitation panel: member name, the BIG gold member code, the join
/// link. The link is scaleDown-fitted so any code length stays on one line.
class _InvitePanel extends StatelessWidget {
  const _InvitePanel({
    required this.memberName,
    required this.memberCodeLabel,
    required this.memberCode,
    required this.joinLink,
  });

  final String memberName;
  final String memberCodeLabel;
  final String memberCode;
  final String joinLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      decoration: BoxDecoration(
        color: SLColors.lightBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          if (memberName.isNotEmpty) ...[
            _CardText(
              text: memberName,
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: SLColors.lightForeground,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
          ],
          _CardText(
            text: memberCodeLabel,
            fontSize: 26,
            color: SLColors.lightMutedForeground,
          ),
          const SizedBox(height: 16),
          // The hero: the member code, big and gold.
          _CardText(
            text: memberCode,
            fontSize: 104,
            fontWeight: FontWeight.w800,
            color: SLColors.goldDeep,
            letterSpacing: 6,
            maxLines: 1,
          ),
          const SizedBox(height: 40),
          const _Hairline(color: SLColors.lightBorder),
          const SizedBox(height: 40),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _CardText(
              text: joinLink,
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: SLColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [card] to a PNG file for the native share sheet.
///
/// The card is laid out and painted OFF-SCREEN at its fixed [ReferralCard
/// .size] inside a temporary OverlayEntry (negatively positioned so nothing
/// is ever visible), captured with `toImage(pixelRatio: 1)` — the output is
/// exactly 1080×1350 px regardless of screen size, DPR or text scale (the
/// entry wraps the card in no-text-scaling so the shared image never
/// reflows).
///
/// The file lands in `<tmp>/share/sunnahlife_referral_card.png` — the ONLY
/// subtree the app's FileProvider exposes (res/xml/file_paths.xml), so the
/// ACTION_SEND intent needs no storage permission.
/// Stages the off-screen capture entry and returns its (painted) boundary
/// plus the teardown. Split out from [renderReferralCardPng] so tests can
/// drive the REAL engine pipeline exactly like the golden matcher does:
/// stage + pump in the fake zone, then `toImage`/`toByteData` INSIDE
/// `tester.runAsync` (the fake-async zone starves the engine's real-async
/// capture callbacks).
Future<(RenderRepaintBoundary, void Function())> stageReferralCard(
  BuildContext context,
  ReferralCard card,
) async {
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -ReferralCard.size.width, // fully off-screen — never visible
      top: 0,
      width: ReferralCard.size.width,
      height: ReferralCard.size.height,
      child: MediaQuery.withNoTextScaling(
        child: RepaintBoundary(key: boundaryKey, child: card),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  try {
    // One frame so the entry is laid out AND painted before capture.
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return (boundary, entry.remove);
  } catch (e) {
    entry.remove();
    rethrow;
  }
}

/// Captures a painted boundary to the share PNG file. The file lands in
/// `<tmp>/share/sunnahlife_referral_card.png` — the ONLY subtree the app's
/// FileProvider exposes (res/xml/file_paths.xml), so the ACTION_SEND
/// intent needs no storage permission.
///
/// Zone notes for tests (mirrors flutter_test's own golden matcher):
/// `toImage()` may be CALLED outside `runAsync`, but the await (and the
/// PNG encode) must happen INSIDE it — the fake-async zone starves the
/// engine's real-async capture callbacks. [captureImageToPngFile] exists
/// so tests can await exactly the golden-matcher way.
Future<File> captureBoundaryToPng(RenderRepaintBoundary boundary) =>
    captureImageToPngFile(boundary.toImage(pixelRatio: 1));

/// Awaits an in-flight boundary capture (or any image future), encodes to
/// PNG and writes the share file. Pure real-async (no frame dependency):
/// tests MUST await it inside `tester.runAsync`.
Future<File> captureImageToPngFile(Future<ui.Image> image) async {
  final img = await image;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data == null) {
    throw StateError('toByteData returned null');
  }
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory('${tmp.path}/share')..createSync(recursive: true);
  final file = File('${shareDir.path}/sunnahlife_referral_card.png');
  // Sync write: a few hundred KB, already off the UI critical path, and
  // a real-async write starves under fake-async test beds.
  file.writeAsBytesSync(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  return file;
}

/// The full production flow: stage → capture → teardown.
Future<File> renderReferralCardPng(
  BuildContext context,
  ReferralCard card,
) async {
  final (boundary, remove) = await stageReferralCard(context, card);
  try {
    return await captureBoundaryToPng(boundary);
  } finally {
    remove();
  }
}
