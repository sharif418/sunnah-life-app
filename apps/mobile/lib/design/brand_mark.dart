/// The Sunnah Life brand mark, drawn — the app icon (apps/web/public/icon.svg:
/// deep-green tile, gold interlaced-square khatam, dome and three receding
/// bars) as a CustomPainter, so the header carries the real mark with no
/// image asset and no decode (identical in widget tests and goldens).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

class SLBrandMark extends StatelessWidget {
  const SLBrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sunnah Life',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _BrandMarkPainter()),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // icon.svg is drawn on a 48-unit box
    canvas.scale(size.width / 48, size.height / 48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 48, 48),
        const Radius.circular(13),
      ),
      Paint()..color = SLColors.primary,
    );

    final stroke = Paint()
      ..color = SLColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final square = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14.5, 14.5, 19, 19),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(square, stroke);
    canvas
      ..save()
      ..translate(24, 24)
      ..rotate(math.pi / 4)
      ..translate(-24, -24)
      ..drawRRect(square, stroke)
      ..restore();

    final fill = Paint()..color = SLColors.gold;
    // the dome (icon.svg path, simplified to the same silhouette)
    final dome = Path()
      ..moveTo(24, 12.2)
      ..cubicTo(24.5, 12.2, 24.9, 12.6, 24.9, 13.1)
      ..lineTo(24.9, 13.6)
      ..cubicTo(27.7, 14.1, 29.8, 16.5, 29.8, 19.4)
      ..cubicTo(29.8, 20.9, 29.4, 22.0, 28.8, 23.1)
      ..lineTo(29.7, 24.7)
      ..lineTo(20.1, 24.7)
      ..lineTo(21.0, 23.1)
      ..cubicTo(20.4, 22.0, 20.0, 20.9, 20.0, 19.4)
      ..cubicTo(20.0, 16.5, 22.1, 14.1, 24.9 - 1.8, 13.6)
      ..lineTo(23.1, 13.1)
      ..cubicTo(23.1, 12.6, 23.5, 12.2, 24, 12.2)
      ..close();
    canvas.drawPath(dome, fill);

    for (final (x, y, w, alpha) in const [
      (18.6, 26.2, 10.8, 1.0),
      (20.2, 29.4, 7.6, 0.7),
      (21.8, 32.6, 4.4, 0.45),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, 1.7),
          const Radius.circular(0.85),
        ),
        Paint()..color = SLColors.gold.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
