/// Widget snapshot — persists the next-prayer data the Android home widget
/// (C-W3f) will read, so it survives app death (no "--:--" reset).
///
/// Layout (SharedPreferences key `widget_snapshot`; FlutterSharedPreferences
/// is readable from the Kotlin widget provider):
/// ```json
/// {
///   "city": "ঢাকা",
///   "dateKey": "2026-02-08",
///   "times": {"fajr": "05:12", "sunrise": "06:33", ... all 10 waqts},
///   "nextKey": "fajr",
///   "nextAt": 1770000000000,
///   "nextLabelBn": "ফজর"
/// }
/// ```
/// `nextAt` is the epoch-millis wall clock of the NEXT farz prayer — when
/// the next prayer is tomorrow's fajr (post-isha), it is computed from
/// TODAY's fajr + 24h (±1 min across seasons; the widget only shows a
/// countdown). Written after every prayer tick; failure is always
/// swallowed — the snapshot is an enhancement, never a crash.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/date_keys.dart';
import '../core/prayer_engine.dart';

class WidgetSnapshotService {
  const WidgetSnapshotService._();

  static const String prefKey = 'widget_snapshot';

  /// Build + persist the snapshot for [times] (the bundle of [dateKey]),
  /// resolving [nextKey] to a concrete wall clock (crossing midnight when
  /// the next prayer is tomorrow's fajr).
  static Future<void> write({
    required String city,
    required String dateKey,
    required PrayerTimesBundle times,
    required PrayerKey nextKey,
  }) async {
    try {
      final day = parseKey(dateKey);
      final nextMinutes = times.byKey(nextKey);
      var nextAt = DateTime(
        day.year,
        day.month,
        day.day,
        nextMinutes ~/ 60,
        (nextMinutes % 60).round(),
      );
      if (!nextAt.isAfter(DateTime.now())) {
        // Already past today's slot — the next prayer is tomorrow's fajr.
        nextAt = nextAt.add(const Duration(days: 1));
      }

      final snapshot = <String, Object>{
        'city': city,
        'dateKey': dateKey,
        'times': {
          for (final key in PrayerKey.values) key.name: _hhmm(times.byKey(key)),
        },
        'nextKey': nextKey.name,
        'nextAt': nextAt.millisecondsSinceEpoch,
        'nextLabelBn': prayerLabelsBn[nextKey] ?? nextKey.name,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, jsonEncode(snapshot));
    } catch (e) {
      debugPrint('widget snapshot write failed: $e');
    }
  }

  /// minutes-from-midnight → zero-padded "HH:mm" (wraps at 24h defensively).
  static String _hhmm(double minutes) {
    final total = minutes.round() % 1440;
    final h = (total ~/ 60).toString().padLeft(2, '0');
    final m = (total % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
