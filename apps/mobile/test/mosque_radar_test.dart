// FEAT-12: the tile-free mosque map — pins at their true bearing and scaled
// distance (north up), readable ring steps, tap selects the nearest pin; and
// the Google Maps links it hands off to.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/external_urls.dart';
import 'package:sunnah_life/db/database.dart';
import 'package:sunnah_life/design/design_tokens.dart';
import 'package:sunnah_life/features/more/mosque_radar.dart';
import 'package:sunnah_life/models/content_models.dart';
import 'package:sunnah_life/state/providers.dart';

const _lat = 23.8103, _lng = 90.4125; // Dhaka
const _north = MosqueInfo(id: 'n', nameBn: 'উত্তর', addressBn: '', lat: 23.8553, lng: 90.4125); // ~5 km N
const _east = MosqueInfo(id: 'e', nameBn: 'পূর্ব', addressBn: '', lat: 23.8103, lng: 90.4617); // ~5 km E

void main() {
  test('north is up, east is right; the outer ring is maxKm', () {
    final n = radarOffset(_north, _lat, _lng, maxKm: 10, radiusPx: 100);
    expect(n.dx.abs(), lessThan(1));
    expect(n.dy, closeTo(-50, 2)); // up = negative y
    final e = radarOffset(_east, _lat, _lng, maxKm: 10, radiusPx: 100);
    expect(e.dx, closeTo(50, 2));
    expect(e.dy.abs(), lessThan(1));
    // beyond maxKm clamps onto the outer ring
    final far = radarOffset(_north, _lat, _lng, maxKm: 2, radiusPx: 100);
    expect(far.distance, closeTo(100, 0.5));
  });

  test('ring steps read well', () {
    expect(niceRingKm(1.5), 0.5);
    expect(niceRingKm(3), 1);
    expect(niceRingKm(7), 2);
    expect(niceRingKm(18), 5);
    expect(niceRingKm(250), 100);
  });

  test('maps hand-off links', () {
    expect(mapsDirectionsUrl(23.81, 90.41),
        'https://www.google.com/maps/dir/?api=1&destination=23.81,90.41');
    expect(mapsNearbySearchUrl('mosque', 23.81, 90.41),
        'https://www.google.com/maps/search/mosque/@23.81,90.41,14z');
    // no point given: the Maps app searches around the phone itself
    expect(mapsSearchUrl('mosque'), 'https://www.google.com/maps/search/mosque');
  });

  testWidgets('tapping near a pin selects that mosque', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    MosqueInfo? picked;
    await tester.pumpWidget(ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildSunnahLightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: MosqueRadar(
              mosques: const [_north, _east],
              lat: _lat,
              lng: _lng,
              selectedId: null,
              onSelect: (m) => picked = m,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(const ValueKey('mosque_radar')));
    // 5 km of a 6 km radar (ring 2 km × 3) toward the east
    final radius = box.width / 2 - 18;
    await tester.tapAt(box.center + Offset(radius * 5 / 6, 0));
    expect(picked?.id, 'e');
  });
}
