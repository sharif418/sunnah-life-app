/// কিবলা — bearing + distance ported from the web engine, with a manual
/// dial (align the dial north using a real compass / the sun, then face the
/// arrow). No sensors required — works on the lowest-end phones offline.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/qibla.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  double _dialRotation = 0; // how far the user has "turned" the phone north

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    final bearing = qiblaBearing(profile.lat, profile.lng);
    final distance = distanceKm(profile.lat, profile.lng, kaabaLat, kaabaLng);
    final lang = context.lang;
    final compass = S.tr(lang, compassKeyFor(bearing));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_qibla')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          Text(
            context.t('qibla_note'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SLSpacing.s16),
          SizedBox(
            height: 300,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _QiblaDialPainter(
                    qiblaBearing: bearing,
                    rotation: _dialRotation,
                    primary: theme.colorScheme.primary,
                    tertiary: theme.colorScheme.tertiary,
                    track: theme.colorScheme.surfaceContainerHighest,
                    outline: theme.colorScheme.outline,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: SLSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s4),
              Text(
                '${bn ? toBn(bearing.toStringAsFixed(1)) : bearing.toStringAsFixed(1)}° · $compass',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            '${context.t('qibla_distance')}: ${bn ? toBn(distance.round()) : distance.round()} ${context.t('unit_km')}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SLSpacing.s16),
          Text(
            '${context.t('qibla_dial_hint')} (${bn ? context.t('qibla_north') : 'N'} → ${bn ? toBn(0) : 0}°)',
            style: theme.textTheme.bodySmall,
          ),
          // A11y: give the manual dial control a screen-reader label.
          Semantics(
            label: context.t('qibla_dial'),
            child: Slider(
              value: _dialRotation,
              min: -180,
              max: 180,
              onChanged: (v) => setState(() => _dialRotation = v),
            ),
          ),
          Text(
            '${context.t('qibla_dial')}: ${bn ? toBn(_dialRotation.round().abs()) : _dialRotation.round().abs()}°',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _QiblaDialPainter extends CustomPainter {
  _QiblaDialPainter({
    required this.qiblaBearing,
    required this.rotation,
    required this.primary,
    required this.tertiary,
    required this.track,
    required this.outline,
  });
  final double qiblaBearing;
  final double rotation;
  final Color primary;
  final Color tertiary;
  final Color track;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outline;
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.08, ring);

    // Tick marks + cardinal labels on the rotating dial.
    final dialPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = track;
    for (var deg = 0; deg < 360; deg += 15) {
      final isMajor = deg % 90 == 0;
      final angle = (deg + rotation - 90) * math.pi / 180;
      final r1 = radius * (isMajor ? 0.86 : 0.92);
      final r2 = radius * 0.98;
      canvas.drawLine(
        center + Offset(r1 * math.cos(angle), r1 * math.sin(angle)),
        center + Offset(r2 * math.cos(angle), r2 * math.sin(angle)),
        dialPaint..strokeWidth = isMajor ? 3 : 1.5,
      );
    }
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final (deg, label) in [(0, 'N'), (90, 'E'), (180, 'S'), (270, 'W')]) {
      final angle = (deg + rotation - 90) * math.pi / 180;
      final pos =
          center +
          Offset(
            radius * 0.76 * math.cos(angle),
            radius * 0.76 * math.sin(angle),
          );
      labelPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: outline,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, pos - labelPainter.size.center(Offset.zero));
    }

    // The Qibla arrow — fixed on the card, pointing at the bearing.
    final arrowAngle = (qiblaBearing - 90) * math.pi / 180;
    final tip =
        center +
        Offset(
          radius * 0.72 * math.cos(arrowAngle),
          radius * 0.72 * math.sin(arrowAngle),
        );
    final back =
        center -
        Offset(
          radius * 0.30 * math.cos(arrowAngle),
          radius * 0.30 * math.sin(arrowAngle),
        );
    final arrowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = primary;
    canvas.drawLine(back, tip, arrowPaint);
    final headPaint = Paint()..color = primary;
    final headAngle = arrowAngle + math.pi;
    for (final side in [0.4, -0.4]) {
      final a = headAngle + side;
      canvas.drawLine(
        tip,
        tip + Offset(16 * math.cos(a), 16 * math.sin(a)),
        arrowPaint..color = primary,
      );
    }
    // Kaaba marker at the tip.
    canvas.drawCircle(tip, 6, headPaint);

    // Fixed "up" indicator (phone's up direction).
    final upPaint = Paint()
      ..color = tertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 2),
      Offset(center.dx, center.dy - radius + 12),
      upPaint,
    );
  }

  @override
  bool shouldRepaint(_QiblaDialPainter old) =>
      old.qiblaBearing != qiblaBearing || old.rotation != rotation;
}
