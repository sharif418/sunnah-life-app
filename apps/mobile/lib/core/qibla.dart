/// Qibla bearing + distance — port of src/lib/qibla.ts.
library;

import 'dart:math' as math;

const double _deg = math.pi / 180;

/// Kaaba coordinates (Masjid al-Haram).
const double kaabaLat = 21.4224779;
const double kaabaLng = 39.8251832;

/// Initial great-circle bearing (degrees from true north) to the Kaaba.
double qiblaBearing(double lat, double lng) {
  final dLng = (kaabaLng - lng) * _deg;
  final p1 = lat * _deg;
  final p2 = kaabaLat * _deg;
  final y = math.sin(dLng);
  final x = math.cos(p1) * math.tan(p2) - math.sin(p1) * math.cos(dLng);
  var brng = math.atan2(y, x) / _deg;
  brng = ((brng % 360) + 360) % 360;
  return brng;
}

/// Great-circle distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * _deg;
  final dLng = (lng2 - lng1) * _deg;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * _deg) *
          math.cos(lat2 * _deg) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Compass-point ARB key nearest to a bearing (bn/en/ar localized — the old
/// Bengali-only label is now `S.tr(lang, compassKeyFor(bearing))`).
String compassKeyFor(double bearing) {
  final points = <double, String>{
    0: 'compass_n',
    45: 'compass_ne',
    90: 'compass_e',
    135: 'compass_se',
    180: 'compass_s',
    225: 'compass_sw',
    270: 'compass_w',
    315: 'compass_nw',
  };
  var best = points.keys.first;
  var bestDiff = 360.0;
  for (final angle in points.keys) {
    final raw = (bearing - angle).abs();
    final diff = math.min(raw, 360 - raw);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = angle;
    }
  }
  return points[best]!;
}

/// Compass-point label (Bengali) nearest to a bearing.
String compassLabelBn(double bearing) {
  final points = <double, String>{
    0: 'উত্তর',
    45: 'উত্তর-পূর্ব',
    90: 'পূর্ব',
    135: 'দক্ষিণ-পূর্ব',
    180: 'দক্ষিণ',
    225: 'দক্ষিণ-পশ্চিম',
    270: 'পশ্চিম',
    315: 'উত্তর-পশ্চিম',
  };
  var best = points.keys.first;
  var bestDiff = 360.0;
  for (final angle in points.keys) {
    final raw = (bearing - angle).abs();
    final diff = math.min(raw, 360 - raw);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = angle;
    }
  }
  return points[best]!;
}
