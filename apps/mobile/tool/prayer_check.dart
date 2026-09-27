// ignore_for_file: avoid_print

import 'package:sunnah_life/core/prayer_engine.dart';

void main() {
  final cases = [
    ('Dhaka 2025-06-15', '2025-06-15', 23.8103, 90.4125, 6.0),
    ('Dhaka 2025-12-21', '2025-12-21', 23.8103, 90.4125, 6.0),
    ('Riyadh 2025-06-15', '2025-06-15', 24.7136, 46.6753, 3.0),
    ('London 2025-06-21', '2025-06-21', 51.5074, -0.1278, 0.0),
  ];
  for (final (name, date, lat, lng, tz) in cases) {
    final t = PrayerEngine.compute(date, lat: lat, lng: lng, tz: tz);
    String f(double m) {
      final h = (m ~/ 60) % 24; final mm = (m % 60).round();
      return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    print('$name: Fajr ${f(t.fajr)} Sunrise ${f(t.sunrise)} Dhuhr ${f(t.dhuhr)} '
        'Asr ${f(t.asr)} Maghrib ${f(t.maghrib)} Isha ${f(t.isha)} Tahajjud ${f(t.tahajjud)} Ishraq ${f(t.ishraq)} Duha ${f(t.duha)}');
  }
}
