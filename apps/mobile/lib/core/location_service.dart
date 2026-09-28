/// GPS location — permission flow + snap-to-nearest-district.
///
/// Split deliberately into a PURE half and a THIN platform half:
///   · [snapToNearestCity] and [locationGate] are pure functions over plain
///     data — unit-tested with no platform channel involvement.
///   · [LocationService] is the only place geolocator is touched; it is never
///     invoked from tests (the pure halves carry the logic).
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'cities.dart';
import 'qibla.dart';

/// Beyond this distance the snapped city is a district-level guess, not a
/// locality match — the UI must label the snap "অনুমান" (approximate).
const double kApproxSnapKm = 50.0;

/// A GPS fix snapped to the nearest catalog city.
class CitySnap {
  const CitySnap({
    required this.city,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.distanceKm,
  });

  /// The nearest city in the catalog (great-circle to the city center).
  final CityEntry city;

  /// The raw GPS fix (not the city center) — "near me" features should use
  /// these for distance/bearing math, not the snapped center.
  final double lat;
  final double lng;

  /// geolocator's claimed accuracy radius in meters (0 when unknown).
  final double accuracyM;

  /// Great-circle distance from the fix to the snapped city center (km).
  final double distanceKm;

  /// The fix is far from the snapped city center — assert "approximate",
  /// never the district, in the UI.
  bool get approximate => distanceKm > kApproxSnapKm;
}

/// Pure: great-circle nearest city over the whole catalog (85 rows — trivial).
///
/// Always returns a city: a mid-Atlantic fix still snaps to *some* city; the
/// [CitySnap.approximate] flag is how the UI says "this is a guess".
CitySnap snapToNearestCity(
  double lat,
  double lng,
  List<CityEntry> cities, {
  double accuracyM = 0,
}) {
  if (cities.isEmpty) {
    throw ArgumentError.value(cities, 'cities', 'city catalog is empty');
  }
  var best = cities.first;
  var bestKm = distanceKm(lat, lng, best.lat, best.lng);
  for (final c in cities.skip(1)) {
    final km = distanceKm(lat, lng, c.lat, c.lng);
    if (km < bestKm) {
      bestKm = km;
      best = c;
    }
  }
  return CitySnap(
    city: best,
    lat: lat,
    lng: lng,
    accuracyM: accuracyM,
    distanceKm: bestKm,
  );
}

/// Pure permission-flow state machine: (service × permission) → what the UI
/// should do next. Every [LocationPermission] value is covered.
enum LocationGate {
  /// Permission usable → go get a fix.
  fetchPosition,

  /// Denied (not forever) → the OS request dialog can still be shown.
  requestPermission,

  /// deniedForever → only the app-settings screen can fix it.
  openSettings,

  /// The device location service is off → offer the location settings.
  openLocationSettings,

  /// Unusable/unknown state → friendly message, manual fallback.
  blocked,
}

LocationGate locationGate({
  required bool serviceEnabled,
  required LocationPermission permission,
}) {
  if (!serviceEnabled) return LocationGate.openLocationSettings;
  return switch (permission) {
    LocationPermission.denied => LocationGate.requestPermission,
    LocationPermission.deniedForever => LocationGate.openSettings,
    LocationPermission.whileInUse ||
    LocationPermission.always => LocationGate.fetchPosition,
    LocationPermission.unableToDetermine => LocationGate.blocked,
  };
}

/// Failure kinds the UI maps to friendly l10n strings — geolocator's own
/// exceptions never leak into widgets.
enum LocationFailure {
  /// Device location service off (LocationServiceDisabledException).
  serviceOff,

  /// Request refused (or the platform cannot even ask).
  permissionDenied,

  /// refused + "don't ask again" — only app settings can recover.
  permissionDeniedForever,

  /// No fix within the time limit.
  timeout,

  /// Anything else (sensor-less device, platform error).
  unavailable,
}

/// Typed failure carrying the friendly-failure kind.
class LocationFailureException implements Exception {
  const LocationFailureException(this.failure);
  final LocationFailure failure;

  @override
  String toString() => 'LocationFailureException($failure)';
}

/// Thin geolocator wrapper — the ONLY file the app imports geolocator from.
class LocationService {
  const LocationService();

  /// City-level accuracy is plenty (snapping to a district center), so the
  /// balanced-power priority keeps battery drain minimal.
  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    timeLimit: Duration(seconds: 20),
  );

  /// Full prompted flow: service check → request permission if needed →
  /// one-shot fix → snap. Throws [LocationFailureException] on every failure
  /// path (never a raw geolocator exception).
  Future<CitySnap> currentCitySnap({List<CityEntry> cities = kCities}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationFailureException(LocationFailure.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (locationGate(serviceEnabled: true, permission: permission)) {
        case LocationGate.fetchPosition:
          return await _fetch(cities);
        case LocationGate.requestPermission:
        case LocationGate.blocked:
          throw const LocationFailureException(
            LocationFailure.permissionDenied,
          );
        case LocationGate.openSettings:
          throw const LocationFailureException(
            LocationFailure.permissionDeniedForever,
          );
        case LocationGate.openLocationSettings:
          throw const LocationFailureException(LocationFailure.serviceOff);
      }
    } on LocationFailureException {
      rethrow;
    } on TimeoutException {
      throw const LocationFailureException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailureException(LocationFailure.serviceOff);
    } on PermissionDefinitionsNotFoundException {
      // Platform permission declarations missing — nothing the user can do
      // from the dialog.
      throw const LocationFailureException(LocationFailure.permissionDenied);
    } on PermissionDeniedException {
      throw const LocationFailureException(LocationFailure.permissionDenied);
    } on PermissionRequestInProgressException {
      throw const LocationFailureException(LocationFailure.permissionDenied);
    } catch (_) {
      throw const LocationFailureException(LocationFailure.unavailable);
    }
  }

  /// Silent probe for screens that want "near me" WITHOUT prompting: returns
  /// null unless permission is already granted and a fix arrives quickly.
  Future<CitySnap?> currentSnapIfGranted({
    List<CityEntry> cities = kCities,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      return await _fetch(cities);
    } on LocationFailureException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CitySnap> _fetch(List<CityEntry> cities) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
      return snapToNearestCity(
        pos.latitude,
        pos.longitude,
        cities,
        accuracyM: pos.accuracy,
      );
    } on TimeoutException {
      throw const LocationFailureException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailureException(LocationFailure.serviceOff);
    } on PermissionDefinitionsNotFoundException {
      throw const LocationFailureException(LocationFailure.permissionDenied);
    } on PermissionDeniedException {
      throw const LocationFailureException(LocationFailure.permissionDenied);
    } on PermissionRequestInProgressException {
      throw const LocationFailureException(LocationFailure.permissionDenied);
    }
  }

  /// deniedForever recovery: send the user to the app's permission settings.
  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// serviceOff recovery: send the user to the device location settings.
  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
