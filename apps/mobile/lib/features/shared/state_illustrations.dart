/// W4f — illustrated empty/error states: small custom-painted vignettes in
/// the khatam-lattice line language of design/texture.dart (plain stroke
/// geometry, eight-point stars, no assets, no packages) over token colors.
///
/// Both vignettes share one frame — a soft rounded box + a thin painted
/// motif + the caller's glyph in a calm surface chip — so the pair reads as
/// a family:
///   · EmptyState — an open book cradle beneath a few gold khatam sparks
///     ("the page waits to be filled"), on the primary-soft surface.
///   · ErrorState — an open ring with a gap ("the loop broke; retry closes
///     it") on the alert-soft surface with an alert-tinted icon chip — the
///     calm forbidden-times idiom (#FCE4E4/#C0392B light,
///     darkAlertSoft/darkAlert dark), never a saturated red flood.
///
/// The illustration is a fixed decorative surface (no text-scaling — WCAG
/// 1.4.4 text grows, ornaments must not) and sized to sit comfortably
/// inside a 360dp viewport.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';

/// The shared vignette frame: rounded box + motif painter + icon chip.
class _StateVignette extends StatelessWidget {
  const _StateVignette({
    required this.background,
    required this.chipBackground,
    required this.chipBorder,
    required this.icon,
    required this.iconColor,
    required this.painter,
  });

  final Color background;
  final Color chipBackground;
  final Color chipBorder;
  final IconData icon;
  final Color iconColor;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 136,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: SLRadius.brXl,
        ),
        child: CustomPaint(
          painter: painter,
          child: Align(
            // Slightly above center so the book cradle reads below the glyph.
            alignment: const Alignment(0, -0.12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: chipBackground,
                shape: BoxShape.circle,
                border: Border.all(color: chipBorder),
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// One eight-point star (khatam-lite) — a 0° square + a 45° square + rays
/// tying the corners, exactly the lattice glyph of design/texture.dart at
/// toy size.
void _paintKhatam(Canvas canvas, Offset c, double s, Color color) {
  final p = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = true;
  canvas.drawRect(
    Rect.fromCenter(center: c, width: s * 2, height: s * 2),
    p,
  );
  final d = s * math.sqrt1_2;
  canvas.drawRect(Rect.fromCenter(center: c, width: d * 2, height: d * 2), p);
  for (final angle in const [0.0, 1.5708, 3.1416, 4.7124]) {
    canvas.drawLine(
      Offset(c.dx + s * math.cos(angle), c.dy + s * math.sin(angle)),
      Offset(c.dx + d * math.cos(angle + math.pi / 4),
          c.dy + d * math.sin(angle + math.pi / 4)),
      p,
    );
  }
}

/// The empty-state motif: an open book across the bottom band + gold khatam
/// sparks above it.
class _BookCradlePainter extends CustomPainter {
  const _BookCradlePainter({required this.ink, required this.gold});

  final Color ink;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // One page (the left); the right is its mirror.
    final spineTop = Offset(w / 2, h * 0.78);
    final spineBase = Offset(w / 2, h * 0.92);
    for (final dir in const [-1.0, 1.0]) {
      final outerTop = Offset(w / 2 + dir * w * 0.34, h * 0.64);
      final outerBase = Offset(w / 2 + dir * w * 0.34, h * 0.88);
      final ctrlX = w / 2 + dir * w * 0.17;
      final path = Path()
        ..moveTo(spineTop.dx, spineTop.dy)
        ..quadraticBezierTo(ctrlX, h * 0.66, outerTop.dx, outerTop.dy)
        ..lineTo(outerBase.dx, outerBase.dy)
        ..quadraticBezierTo(ctrlX, h * 0.90, spineBase.dx, spineBase.dy);
      canvas.drawPath(path, paint);
    }
    // The spine ties the two pages.
    canvas.drawLine(spineTop, spineBase, paint);

    // Gold sparks — the lattice above the waiting page.
    _paintKhatam(canvas, Offset(w * 0.20, h * 0.24), 5, gold);
    _paintKhatam(canvas, Offset(w * 0.80, h * 0.20), 3.5, gold);
    _paintKhatam(canvas, Offset(w * 0.50, h * 0.10), 2.5, gold);
  }

  @override
  bool shouldRepaint(_BookCradlePainter old) =>
      old.ink != ink || old.gold != gold;
}

/// The error-state motif: an open ring (a 40° gap at 12 o'clock — the
/// broken circuit a retry closes) with gold sparks at the arc's tips.
class _OpenRingPainter extends CustomPainter {
  const _OpenRingPainter({required this.ink, required this.gold});

  final Color ink;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.44);
    final radius = h * 0.36;

    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const gapCenter = -math.pi / 2; // 12 o'clock
    const gapHalf = 0.35; // ~40° total
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      gapCenter + gapHalf,
      2 * math.pi - 2 * gapHalf,
      false,
      paint,
    );

    // Gold sparks at the arc tips — where the loop would close.
    for (final dir in const [-1.0, 1.0]) {
      final tip = Offset(
        center.dx + radius * math.cos(gapCenter + dir * gapHalf),
        center.dy + radius * math.sin(gapCenter + dir * gapHalf),
      );
      _paintKhatam(canvas, tip.translate(0, -3), 3, gold);
    }
  }

  @override
  bool shouldRepaint(_OpenRingPainter old) =>
      old.ink != ink || old.gold != gold;
}

/// The illustrated empty state (public seam for the kit gallery).
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _StateVignette(
      background: dark ? SLColors.darkPrimarySoft : SLColors.lightPrimarySoft,
      chipBackground: dark ? SLColors.darkCard : SLColors.lightCard,
      chipBorder: dark ? SLColors.darkBorder : SLColors.lightBorder,
      icon: icon ?? PhosphorIconsRegular.tray,
      iconColor: dark ? SLColors.darkPrimary : SLColors.lightPrimary,
      painter: _BookCradlePainter(
        ink: (dark ? SLColors.darkPrimary : SLColors.lightPrimary)
            .withValues(alpha: 0.55),
        gold: (dark ? SLColors.darkGold : SLColors.lightGold)
            .withValues(alpha: 0.9),
      ),
    );
  }
}

/// The illustrated error state (public seam for the kit gallery).
class ErrorIllustration extends StatelessWidget {
  const ErrorIllustration({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final alertFg = dark ? SLColors.darkAlert : SLColors.lightDestructive;
    return _StateVignette(
      background: dark ? SLColors.darkAlertSoft : SLColors.alertSoftLight,
      chipBackground: dark ? SLColors.darkCard : SLColors.lightCard,
      chipBorder: alertFg.withValues(alpha: 0.25),
      icon: icon ?? PhosphorIconsRegular.warningCircle,
      iconColor: alertFg,
      painter: _OpenRingPainter(
        ink: alertFg.withValues(alpha: 0.45),
        gold: (dark ? SLColors.darkGold : SLColors.lightGold)
            .withValues(alpha: 0.9),
      ),
    );
  }
}
