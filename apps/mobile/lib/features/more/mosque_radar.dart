/// FEAT-12 "আমার মসজিদ: ম্যাপ" without a tile engine: a radar-style map —
/// you at the centre, distance rings, each mosque at its true bearing and
/// scaled distance (north up). Offline, no new dependency, light on low-end
/// phones; a tap selects the nearest pin and the screen offers directions.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../core/qibla.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart' show L10nX;

/// Where [m] sits on a radar of [radiusPx] whose outer ring is [maxKm] from
/// ([lat], [lng]); north is up. Pure — unit tested.
Offset radarOffset(
  MosqueInfo m,
  double lat,
  double lng, {
  required double maxKm,
  required double radiusPx,
}) {
  final km = distanceKm(lat, lng, m.lat, m.lng).clamp(0.0, maxKm);
  final r = maxKm <= 0 ? 0.0 : km / maxKm * radiusPx;
  final a = bearingDeg(lat, lng, m.lat, m.lng) * math.pi / 180;
  return Offset(r * math.sin(a), -r * math.cos(a));
}

/// A ring step that reads well: 0.5 / 1 / 2 / 5 / 10 / 20 / 50 km …
double niceRingKm(double maxKm) {
  const steps = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0];
  for (final s in steps) {
    if (maxKm / s <= 4) return s;
  }
  return 1000;
}

class MosqueRadar extends StatelessWidget {
  const MosqueRadar({
    super.key,
    required this.mosques,
    required this.lat,
    required this.lng,
    required this.selectedId,
    required this.onSelect,
  });

  /// Already distance-sorted and trimmed by the caller.
  final List<MosqueInfo> mosques;
  final double lat;
  final double lng;
  final String? selectedId;
  final ValueChanged<MosqueInfo> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final unitKm = context.t('unit_km');
    final farthest = mosques.isEmpty
        ? 1.0
        : mosques
              .map((m) => distanceKm(lat, lng, m.lat, m.lng))
              .reduce(math.max);
    final ring = niceRingKm(farthest);
    final maxKm = (farthest / ring).ceil().clamp(1, 4) * ring;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final radius = box.maxWidth / 2 - 18;
          final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
          Offset at(MosqueInfo m) =>
              center + radarOffset(m, lat, lng, maxKm: maxKm, radiusPx: radius);
          return GestureDetector(
            key: const ValueKey('mosque_radar'),
            onTapUp: (d) {
              MosqueInfo? best;
              var bestD = 36.0; // finger-sized hit radius
              for (final m in mosques) {
                final dist = (at(m) - d.localPosition).distance;
                if (dist < bestD) {
                  bestD = dist;
                  best = m;
                }
              }
              if (best != null) onSelect(best);
            },
            child: CustomPaint(
              painter: _RadarPainter(
                center: center,
                radius: radius,
                rings: (maxKm / ring).round(),
                ringLabel: (i) {
                  final km = ring * i;
                  final s = km == km.roundToDouble()
                      ? '${km.round()}'
                      : km.toStringAsFixed(1);
                  return '${bn ? toBn(s) : s} $unitKm';
                },
                pins: [for (final m in mosques) (at(m), m.id == selectedId)],
                cs: theme.colorScheme,
                labelStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                north: context.t('mosque_north'),
                youLabel: context.t('mosque_you'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.center,
    required this.radius,
    required this.rings,
    required this.ringLabel,
    required this.pins,
    required this.cs,
    required this.labelStyle,
    required this.north,
    required this.youLabel,
  });

  final String north;
  final String youLabel;
  final Offset center;
  final double radius;
  final int rings;
  final String Function(int) ringLabel;
  final List<(Offset, bool)> pins;
  final ColorScheme cs;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = cs.outline;
    for (var i = 1; i <= rings; i++) {
      final r = radius * i / rings;
      canvas.drawCircle(center, r, ringPaint);
      final tp = TextPainter(
        text: TextSpan(text: ringLabel(i), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      // labels sit on the north-east diagonal, clear of the N marker
      const d = 0.7071;
      tp.paint(canvas, center + Offset(r * d + 2, -r * d - tp.height));
    }
    // north marker
    final n = TextPainter(
      text: TextSpan(
        text: north,
        style: labelStyle.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, center + Offset(-n.width / 2, -radius - n.height - 2));

    // you — a location marker (hollow ring + dot), unlike the mosque pins
    canvas.drawCircle(center, 11, Paint()..color = cs.onSurface.withValues(alpha: 0.12));
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = cs.onSurface,
    );
    canvas.drawCircle(center, 3, Paint()..color = cs.onSurface);

    // mosques — the selected one last, larger, gold
    final ordered = [...pins.where((p) => !p.$2), ...pins.where((p) => p.$2)];
    for (final (o, selected) in ordered) {
      canvas.drawCircle(
        o,
        selected ? 10 : 7,
        Paint()..color = selected ? cs.tertiary : cs.primary,
      );
      canvas.drawCircle(
        o,
        selected ? 10 : 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cs.surface,
      );
    }

    // the "you" label last, on a backdrop, so no pin ever covers it
    final you = TextPainter(
      text: TextSpan(text: youLabel, style: labelStyle.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = center + Offset(-you.width / 2, -you.height - 13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx - 5, at.dy - 1, you.width + 10, you.height + 2),
        const Radius.circular(6),
      ),
      Paint()..color = cs.surface.withValues(alpha: 0.9),
    );
    you.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.pins != pins || old.radius != radius || old.cs != cs;
}
