// ignore_for_file: avoid_print

import 'package:adhan_dart/adhan_dart.dart';

void main() {
  final coords = Coordinates(24.7136, 46.6753);
  final params = CalculationMethodParameters.karachi();
  params.madhab = Madhab.hanafi;
  final t = PrayerTimes(date: DateTime(2025, 6, 15), coordinates: coords, calculationParameters: params);
  print('raw fajr (utc): ${t.fajr}');
  print('raw sunrise: ${t.sunrise}');
  print('raw dhuhr: ${t.dhuhr}');
  print('raw isha: ${t.isha}');
  final t2 = PrayerTimes(date: DateTime(2025, 6, 15), coordinates: coords, calculationParameters: params, precision: true);
  print('precision fajr: ${t2.fajr} sunrise ${t2.sunrise}');
}
