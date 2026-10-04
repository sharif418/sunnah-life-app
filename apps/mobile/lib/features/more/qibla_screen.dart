/// কিবলা — bearing + distance with a live magnetometer compass when the
/// device has one (flutter_compass), falling back to the manual dial
/// (emulators, desktops, sensor-less phones). Works fully offline.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/compass_quality.dart';
import '../../core/qibla.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

/// Whether flutter_compass's heading is TRUE north on this platform.
///
/// flutter_compass 0.8.1 — checked against its native sources:
///   · iOS reports CLLocationManager's `trueHeading` → TRUE north
///     (declination-corrected by CoreLocation).
///   · Android derives the azimuth via `SensorManager.getOrientation()` on
///     the ROTATION_VECTOR sensor → MAGNETIC north. The plugin does NOT
///     apply a `GeomagneticField` declination correction, and neither do we
///     (a per-fix method channel is not worth the surface here). In
///     Bangladesh the declination is ≈1°, small against the typical
///     uncalibrated-magnetometer error the calibration hint exists for.
/// The dial is drawn against the heading as reported; the manual dial below
/// remains the exact, offline fallback.
bool get compassHeadingIsTrueNorth => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  double _dialRotation = 0; // how far the user has "turned" the dial north
  double? _heading; // live device heading (deg, clockwise from north)
  double? _headingAccuracy;
  final List<double> _recentHeadings = [];
  bool _compassMode = false;
  bool _probeSettled = false; // first event received / probe gave up
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _probeTimer;

  static const int _recentMax = 8;
  static const Duration _probeTimeout = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _probeCompass();
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  /// Listen to the compass stream but never crash: emulators/desktops throw
  /// MissingPluginException, sensor-less phones stay silent, and some
  /// devices emit events with a null heading — every path degrades to the
  /// manual dial.
  void _probeCompass() {
    try {
      final stream = FlutterCompass.events;
      if (stream == null) {
        _settleManual();
        return;
      }
      _compassSub = stream.listen(
        (event) {
          if (!mounted) return;
          if (!_probeSettled) _probeTimer?.cancel();
          setState(() {
            _probeSettled = true;
            // Negative heading = iOS's "trueHeading unavailable" sentinel
            // (e.g. location authorization absent) — unusable, degrade.
            final h = event.heading;
            if (h == null || h < 0) {
              _compassMode = false;
              return;
            }
            _compassMode = true;
            _heading = h;
            _headingAccuracy = event.accuracy;
            _recentHeadings.add(h);
            if (_recentHeadings.length > _recentMax) {
              _recentHeadings.removeAt(0);
            }
          });
        },
        onError: (_) => _settleManual(),
        onDone: _settleManual,
      );
      _probeTimer = Timer(_probeTimeout, () {
        // No event at all (desktop/test stubs, silent sensor) → manual only.
        if (mounted && !_probeSettled) _settleManual();
      });
    } catch (_) {
      _settleManual();
    }
  }

  void _settleManual() {
    _probeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _probeSettled = true;
      _compassMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    final bearing = qiblaBearing(profile.lat, profile.lng);
    final distance = distanceKm(profile.lat, profile.lng, kaabaLat, kaabaLng);
    final lang = context.lang;
    final compass = S.tr(lang, compassKeyFor(bearing));

    // Compass mode: the dial's north tick is rotated to where real north is
    // relative to the device's up edge (heading = direction of device-up,
    // so north sits at -heading on screen). Manual mode: the user's slider.
    final rotation = _compassMode ? -(_heading ?? 0) : _dialRotation;
    final quality = _compassMode
        ? compassSignalQuality(
            accuracy: _headingAccuracy,
            recentHeadings: List<double>.unmodifiable(_recentHeadings),
          )
        : CompassQuality.good;

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
                    rotation: rotation,
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
                PhosphorIconsRegular.compass,
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

          // ── Compass-specific chrome ──
          if (_compassMode) ...[
            if (quality == CompassQuality.poor)
              _CalibrationCard(bn: bn)
            else
              const SizedBox.shrink(),
            const SizedBox(height: SLSpacing.s8),
            Text(
              '${context.t('qibla_compass_heading')}: ${bn ? toBn(_heading?.round() ?? 0) : (_heading?.round() ?? 0)}°'
              '${_headingAccuracy != null ? ' (±${bn ? toBn(_headingAccuracy!.round()) : _headingAccuracy!.round()}°)' : ''}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            // ── Manual fallback ──
            if (_probeSettled)
              Text(
                context.t('qibla_compass_unavailable'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${context.t('qibla_dial_hint')} (${bn ? context.t('qibla_north') : 'N'} = ${bn ? toBn(0) : 0}°)',
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
        ],
      ),
    );
  }
}

/// Figure-8 calibration hint — the standard Android magnetometer gesture.
class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.bn});
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s12),
        child: Row(
          children: [
            Text('8', // the figure-8 gesture itself
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.tertiary,
                )),
            const SizedBox(width: SLSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('qibla_calibration_title'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    context.t('qibla_calibration_hint'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
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

    // The Qibla arrow — rides ON the rotating dial (its bearing is measured
    // from the dial's north, so it must rotate with it). When the dial's N
    // points at real north — via the live compass or the manual slider —
    // the arrow points at the Kaaba.
    final arrowAngle = (qiblaBearing + rotation - 90) * math.pi / 180;
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
