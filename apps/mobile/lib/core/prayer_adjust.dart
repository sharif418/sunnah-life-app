/// The reader's own minutes on each farz waqt — to match the azan of the
/// mosque they pray at (each mosque adds its own few minutes to the
/// calculated time). Applied to the five START times only: sunrise, sunset
/// and the forbidden windows stay astronomical.
library;

import 'dart:convert';

import 'prayer_engine.dart';

class PrayerAdjust {
  const PrayerAdjust([this.minutes = const {}]);

  /// The waqts that can be adjusted, in day order.
  static const keys = [
    PrayerKey.fajr,
    PrayerKey.dhuhr,
    PrayerKey.asr,
    PrayerKey.maghrib,
    PrayerKey.isha,
  ];
  static const min = -30;
  static const max = 30;

  final Map<PrayerKey, int> minutes;

  int of(PrayerKey k) => minutes[k] ?? 0;
  bool get isEmpty => keys.every((k) => of(k) == 0);
  bool get anyEarlier => keys.any((k) => of(k) < 0);

  PrayerAdjust withValue(PrayerKey k, int v) {
    final next = Map<PrayerKey, int>.from(minutes);
    final c = v.clamp(min, max);
    if (c == 0) {
      next.remove(k);
    } else {
      next[k] = c;
    }
    return PrayerAdjust(next);
  }

  /// {"fajr": 2, "maghrib": 5} — only the non-zero ones.
  Map<String, int> toJson() => {
    for (final k in keys)
      if (of(k) != 0) k.name: of(k),
  };

  String encode() => jsonEncode(toJson());

  /// From a decoded map or a JSON string; unknown keys and bad values drop.
  factory PrayerAdjust.parse(Object? raw) {
    Object? v = raw;
    if (v is String) {
      try {
        v = v.isEmpty ? null : jsonDecode(v);
      } catch (_) {
        v = null;
      }
    }
    if (v is! Map) return const PrayerAdjust();
    final out = <PrayerKey, int>{};
    for (final k in keys) {
      final n = v[k.name];
      if (n is num && n.isFinite && n.round() != 0) {
        out[k] = n.round().clamp(min, max);
      }
    }
    return PrayerAdjust(out);
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerAdjust && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;
}
