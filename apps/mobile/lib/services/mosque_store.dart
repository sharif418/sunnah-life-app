/// What the mosque screen keeps on the phone:
///  • "আমার মসজিদ" — the mosques the reader starred (works for guests,
///    offline, and survives reinstall-free updates);
///  • the last nearby list and where it was asked, so the screen still has
///    something to show without internet.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/qibla.dart' show distanceKm;
import '../models/content_models.dart';

class MosqueStore {
  const MosqueStore();

  static const _savedKey = 'my_mosques_v1';
  static const _nearKey = 'mosques_near_v1';

  Future<List<MosqueInfo>> saved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => MosqueInfo.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSaved(List<MosqueInfo> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedKey,
      jsonEncode([for (final m in list) m.toJson()]),
    );
  }

  Future<void> rememberNear(
    double lat,
    double lng,
    List<MosqueInfo> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _nearKey,
        jsonEncode({
          'lat': lat,
          'lng': lng,
          'mosques': [for (final m in list) m.toJson()],
        }),
      );
    } catch (_) {}
  }

  /// The last list, if it was asked within 3 km of here.
  Future<List<MosqueInfo>?> nearFromCache(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_nearKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final cLat = (j['lat'] as num).toDouble();
      final cLng = (j['lng'] as num).toDouble();
      if (distanceKm(lat, lng, cLat, cLng) > 3) return null;
      return (j['mosques'] as List)
          .whereType<Map>()
          .map((e) => MosqueInfo.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
