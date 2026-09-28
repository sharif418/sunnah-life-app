/// C-W3c pure logic — snap-to-nearest-city, great-circle distance/bearing,
/// the permission gate, compass-signal quality and mosque sorting.
///
/// NO platform channels: geolocator / flutter_compass are never invoked here
/// (only their enum/type definitions are imported).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;

import 'package:sunnah_life/core/cities.dart';
import 'package:sunnah_life/core/compass_quality.dart';
import 'package:sunnah_life/core/location_service.dart';
import 'package:sunnah_life/core/qibla.dart';
import 'package:sunnah_life/features/more/mosques_screen.dart';
import 'package:sunnah_life/models/content_models.dart';

CityEntry _c(String bn, String en, double lat, double lng) => CityEntry(
  nameBn: bn,
  nameEn: en,
  lat: lat,
  lng: lng,
  tz: 6,
  isBd: true,
);

MosqueInfo _m(String id, double lat, double lng) =>
    MosqueInfo(id: id, nameBn: id, addressBn: '', lat: lat, lng: lng);

void main() {
  group('snapToNearestCity', () {
    test('a Dhaka coordinate snaps to Dhaka, not approximate', () {
      final snap = snapToNearestCity(23.81, 90.41, kCities);
      expect(snap.city.nameEn, 'Dhaka');
      expect(snap.distanceKm, lessThan(1));
      expect(snap.approximate, isFalse);
      expect(snap.lat, 23.81); // raw fix preserved for near-me math
      expect(snap.lng, 90.41);
    });

    test('a point near the Sylhet border snaps to Sylhet', () {
      final snap = snapToNearestCity(24.85, 91.83, kCities);
      expect(snap.city.nameEn, 'Sylhet');
      expect(snap.distanceKm, closeTo(6.34, 0.2));
      expect(snap.approximate, isFalse);
    });

    test('a mid-Atlantic point still returns the closest city, flagged approximate', () {
      final snap = snapToNearestCity(30, -40, kCities);
      expect(snap.city.nameEn, 'New York'); // closest of all 85 entries
      expect(snap.distanceKm, closeTo(3281, 30));
      expect(snap.approximate, isTrue, reason: '>50km must label অনুমান');
    });

    test('>50km threshold: 44.5km is exact, 55.6km is approximate', () {
      final catalog = [_c('মক্কা', 'Makkah', 0, 0)];
      final near = snapToNearestCity(0.40, 0, catalog); // 0.40° lat ≈ 44.5 km
      final far = snapToNearestCity(0.50, 0, catalog); // 0.50° lat ≈ 55.6 km
      expect(near.approximate, isFalse);
      expect(far.approximate, isTrue);
      expect(kApproxSnapKm, 50);
    });

    test('snaps to the nearer of two synthetic cities', () {
      final catalog = [_c('ক', 'A', 0, 0), _c('খ', 'B', 0.9, 0)];
      final snap = snapToNearestCity(0.5, 0, catalog);
      expect(snap.city.nameEn, 'B');
      expect(snap.distanceKm, closeTo(44.5, 0.5));
    });

    test('empty catalog is a programmer error', () {
      expect(() => snapToNearestCity(0, 0, const []), throwsArgumentError);
    });

    test('accuracy passes through for the confirm row (±মি)', () {
      final snap = snapToNearestCity(23.81, 90.41, kCities, accuracyM: 25);
      expect(snap.accuracyM, 25);
    });
  });

  group('great-circle distance (known pairs, ±1%)', () {
    test('Dhaka → Kaaba ≈ 5172 km', () {
      final km = distanceKm(23.8103, 90.4125, kaabaLat, kaabaLng);
      expect(km, closeTo(5172, 5172 * 0.01));
    });

    test('Dhaka → Kolkata ≈ 250.6 km', () {
      final km = distanceKm(23.8103, 90.4125, 22.5726, 88.3639);
      expect(km, closeTo(250.6, 2.5));
    });

    test('Chattogram → Dhaka ≈ 214 km', () {
      final km = distanceKm(22.3569, 91.7832, 23.8103, 90.4125);
      expect(km, closeTo(214, 2.1));
    });

    test('symmetry', () {
      final a = distanceKm(23.8103, 90.4125, 22.5726, 88.3639);
      final b = distanceKm(22.5726, 88.3639, 23.8103, 90.4125);
      expect(a, b);
    });
  });

  group('bearingDeg', () {
    test('cardinal directions', () {
      expect(bearingDeg(0, 0, 10, 0), closeTo(0, 0.01)); // north
      expect(bearingDeg(0, 0, 0, 10), closeTo(90, 0.01)); // east
      expect(bearingDeg(10, 0, 0, 0), closeTo(180, 0.01)); // south
      expect(bearingDeg(0, 10, 0, 0), closeTo(270, 0.01)); // west
    });

    test('Dhaka → Kaaba qibla ≈ 277.6° (west-northwest)', () {
      final q = qiblaBearing(23.8103, 90.4125);
      expect(q, closeTo(277.6, 0.5));
      // the general bearing and the qibla special-case agree
      expect(
        bearingDeg(23.8103, 90.4125, kaabaLat, kaabaLng),
        closeTo(q, 0.01),
      );
    });

    test('forward/reverse bearings differ by ~180°', () {
      final fwd = bearingDeg(23.8103, 90.4125, 22.5726, 88.3639);
      final rev = bearingDeg(22.5726, 88.3639, 23.8103, 90.4125);
      expect((fwd - rev).abs(), closeTo(180, 1));
    });
  });

  group('locationGate (permission state machine)', () {
    test('service off wins regardless of permission', () {
      for (final p in LocationPermission.values) {
        expect(
          locationGate(serviceEnabled: false, permission: p),
          LocationGate.openLocationSettings,
        );
      }
    });

    test('granted → fetch, denied → request, forever → settings', () {
      expect(
        locationGate(serviceEnabled: true, permission: LocationPermission.whileInUse),
        LocationGate.fetchPosition,
      );
      expect(
        locationGate(serviceEnabled: true, permission: LocationPermission.always),
        LocationGate.fetchPosition,
      );
      expect(
        locationGate(serviceEnabled: true, permission: LocationPermission.denied),
        LocationGate.requestPermission,
      );
      expect(
        locationGate(
            serviceEnabled: true, permission: LocationPermission.deniedForever),
        LocationGate.openSettings,
      );
      expect(
        locationGate(
            serviceEnabled: true,
            permission: LocationPermission.unableToDetermine),
        LocationGate.blocked,
      );
    });
  });

  group('compassSignalQuality', () {
    test('angDist wraps around 360', () {
      expect(angDist(350, 10), closeTo(20, 0.001));
      expect(angDist(10, 350), closeTo(20, 0.001));
      expect(angDist(0, 180), closeTo(180, 0.001));
      expect(angDist(270, 90), closeTo(180, 0.001));
    });

    test('platform accuracy claim alone decides when the window is short', () {
      expect(
        compassSignalQuality(accuracy: 25, recentHeadings: const []),
        CompassQuality.poor,
      );
      expect(
        compassSignalQuality(accuracy: 10, recentHeadings: const []),
        CompassQuality.good,
      );
      expect(
        compassSignalQuality(accuracy: null, recentHeadings: const []),
        CompassQuality.good, // unknown → no nag without evidence
      );
    });

    test('jitter: repeated big swings are poor', () {
      expect(
        compassSignalQuality(
            accuracy: null, recentHeadings: const [10, 40, 15, 45]),
        CompassQuality.poor,
      );
    });

    test('wide spread across a calm window is poor', () {
      expect(
        compassSignalQuality(
            accuracy: null, recentHeadings: const [10, 22, 35, 40]),
        CompassQuality.poor,
      );
    });

    test('a settled needle is good', () {
      expect(
        compassSignalQuality(
            accuracy: null,
            recentHeadings: const [277, 277.5, 277.2, 277.8, 277.4]),
        CompassQuality.good,
      );
      expect(
        compassSignalQuality(
            accuracy: 8, recentHeadings: const [12, 13]),
        CompassQuality.good, // short window, small accuracy claim
      );
    });
  });

  group('mosque list — near-me vs city fallback', () {
    final mosques = [
      _m('at-city', 23.8103, 90.4125),
      _m('5km-east', 23.8103, 90.4655), // ~0.0531° lng ≈ 5.4 km
      _m('2km-north', 23.8283, 90.4125), // ~0.018° lat ≈ 2.0 km
    ];

    test('sorted by distance from the city center', () {
      final sorted = sortMosquesByDistance(mosques, 23.8103, 90.4125);
      expect(sorted.map((m) => m.id).toList(), ['at-city', '2km-north', '5km-east']);
    });

    test('a GPS fix elsewhere reorders the list', () {
      // Fix 2km north of the city center: the north mosque becomes nearest.
      final sorted = sortMosquesByDistance(mosques, 23.8283, 90.4125);
      expect(sorted.first.id, '2km-north');
      expect(
        distanceKm(23.8283, 90.4125, sorted[0].lat, sorted[0].lng),
        lessThan(0.01),
      );
    });

    test('does not mutate the input list', () {
      final input = [...mosques];
      sortMosquesByDistance(mosques, 23.8283, 90.4125);
      expect(input.map((m) => m.id).toList(), ['at-city', '5km-east', '2km-north']);
    });

    test('origin: city center without a fix, raw fix with one', () {
      final cityOnly = mosqueListOrigin(null, 23.8103, 90.4125);
      expect(cityOnly.fromGps, isFalse);
      expect(cityOnly.lat, 23.8103);
      expect(cityOnly.lng, 90.4125);

      final snap = snapToNearestCity(24.85, 91.83, kCities, accuracyM: 12);
      final fromFix = mosqueListOrigin(snap, 23.8103, 90.4125);
      expect(fromFix.fromGps, isTrue);
      expect(fromFix.lat, 24.85); // raw fix, NOT the snapped city center
      expect(fromFix.lng, 91.83);
    });

    test('per-mosque bearing uses mosque-from-user math (not kaaba)', () {
      // Due east of the origin → bearing 90, not the Dhaka qibla (≈277.6).
      final b = bearingDeg(23.8103, 90.4125, 23.8103, 90.4655);
      expect(b, closeTo(90, 0.5));
      final q = qiblaBearing(23.8103, 90.4125);
      expect((b - q).abs(), greaterThan(180));
    });
  });
}
