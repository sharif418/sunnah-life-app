/// Compass-signal quality heuristic for the qibla screen — PURE (no platform
/// channels); fed from flutter_compass events by the widget.
library;

enum CompassQuality { good, poor }

/// Smallest absolute difference between two angles (degrees, either sign).
double angDist(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Decide whether the live heading can be trusted for the qibla dial.
///
/// [accuracy] is flutter_compass's deviation claim: on iOS it is computed by
/// the platform and reliable; on Android several values are hard-coded in the
/// plugin, so `null`/small values are NOT proof of quality — that is why the
/// jitter window ([recentHeadings], oldest first, caller-capped) is the
/// primary signal. `null` accuracy with a short window is "unknown → good"
/// (showing a calibration nag on no evidence is worse than a slightly-off
/// needle; the manual dial is one tap away).
CompassQuality compassSignalQuality({
  double? accuracy,
  List<double> recentHeadings = const [],
}) {
  if (recentHeadings.length >= 4) {
    // Repeated big consecutive swings → the needle is hunting.
    var swings = 0;
    for (var i = 1; i < recentHeadings.length; i++) {
      if (angDist(recentHeadings[i], recentHeadings[i - 1]) > 20) swings++;
    }
    if (swings >= 2) return CompassQuality.poor;
    // Wide circular spread across the window → uncalibrated magnetometer.
    var spread = 0.0;
    for (var i = 0; i < recentHeadings.length; i++) {
      for (var j = i + 1; j < recentHeadings.length; j++) {
        final d = angDist(recentHeadings[i], recentHeadings[j]);
        if (d > spread) spread = d;
      }
    }
    if (spread > 25) return CompassQuality.poor;
  }
  if (accuracy != null && accuracy > 15) return CompassQuality.poor;
  return CompassQuality.good;
}
