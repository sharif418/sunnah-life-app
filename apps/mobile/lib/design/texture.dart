/// W4f: the subtle Islamic geometric texture — an eight-point-star
/// lattice painted with plain line geometry (no assets, no packages).
///
/// Drawn at ≤ 5 % foreground opacity over the deep-green hero gradient:
/// present, never loud — a shadow, not a pattern. Const painter state,
/// one paint pass per size.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

class SLGeometricTexture extends StatelessWidget {
  const SLGeometricTexture({
    super.key,
    this.opacity = 0.05,
    this.tileSize = 56,
  });

  /// Foreground alpha — 0.04–0.06 reads as texture, above it reads as
  /// noise.
  final double opacity;

  /// Lattice cell (logical px). 56 keeps ~6–8 stars on a phone hero.
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      foregroundPainter: _LatticePainter(
        color: (dark ? SLColors.darkForeground : SLColors.lightPrimarySoft)
            .withValues(alpha: opacity),
        tile: tileSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter({required this.color, required this.tile});

  final Color color;
  final double tile;

  /// Half of the outer square's side — the arm the star's rays reach.
  static const double _arm = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Eight-point stars (khatam-lite) on a square lattice: a 0° square +
    // a 45° square + thin ties to the diagonal neighbours — the geometry
    // IS the ornament.
    for (var x = -tile; x < size.width + tile; x += tile) {
      for (var y = -tile; y < size.height + tile; y += tile) {
        final c = Offset(x, y);
        canvas.drawRect(
          Rect.fromCenter(center: c, width: _arm * 2, height: _arm * 2),
          paint,
        );
        final d = _arm * math.sqrt1_2;
        canvas.drawRect(
          Rect.fromCenter(center: c, width: d * 2, height: d * 2),
          paint,
        );
        // Rays: connect the outer square's corners to the inner one's.
        for (final angle in const [0.0, 1.5708, 3.1416, 4.7124]) {
          final outer = Offset(
            c.dx + _arm * math.cos(angle),
            c.dy + _arm * math.sin(angle),
          );
          final inner = Offset(
            c.dx + d * math.cos(angle + math.pi / 4),
            c.dy + d * math.sin(angle + math.pi / 4),
          );
          canvas.drawLine(outer, inner, paint);
        }
        // Tie towards the diagonal neighbour.
        final diag = Offset(x + tile / 2, y + tile / 2);
        canvas.drawLine(
          c.translate(0, -_arm),
          diag.translate(0, -_arm),
          paint,
        );
        canvas.drawLine(
          c.translate(_arm, 0),
          diag.translate(_arm, 0),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.color != color || old.tile != tile;
}
