/// The four-colour Google "G" (Google's sign-in branding asks for the
/// coloured mark on a "Sign in with Google" button; the vendored icon font
/// only has a one-colour glyph). Drawn, not bundled — no asset, no new
/// dependency.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _GPainter()),
  );
}

class _GPainter extends CustomPainter {
  const _GPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final r = (s - stroke) / 2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;

    // angles clockwise from 3 o'clock; the opening sits at the upper right
    canvas.drawArc(rect, rad(-5), rad(50), false, p(_blue));
    canvas.drawArc(rect, rad(45), rad(90), false, p(_green));
    canvas.drawArc(rect, rad(135), rad(80), false, p(_yellow));
    canvas.drawArc(rect, rad(215), rad(100), false, p(_red));
    // the crossbar
    canvas.drawRect(
      Rect.fromLTWH(c.dx - stroke * 0.1, c.dy - stroke / 2, r + stroke / 2, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GPainter oldDelegate) => false;
}
