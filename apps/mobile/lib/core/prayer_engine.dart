/// On-device prayer engine — adhan_dart (Karachi 18°/18° default, Hanafi Asr)
/// plus the Sunnah Life extensions ported from src/lib/prayer-times.ts:
/// Ishraq (+20m), Duha (¼ of sunrise→dhuhr), Tahajjud (last third),
/// Maghrib (+3m BD safety) and the three forbidden windows.
library;

import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../models/domain.dart';
import 'prayer_adjust.dart';

class PrayerTimesBundle {
  const PrayerTimesBundle({
    required this.fajr,
    required this.sunrise,
    required this.ishraq,
    required this.duha,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.sunset,
    required this.isha,
    required this.tahajjud,
    double? noon,
  }) : noon = noon ?? dhuhr;

  /// Minutes from local midnight (floats) — same shape as the web engine.
  final double fajr;
  final double sunrise;
  final double ishraq;
  final double duha;
  final double dhuhr;
  final double asr;
  final double maghrib;
  final double sunset;
  final double isha;
  final double tahajjud;

  /// The sun's transit — Zawal's anchor. Equals [dhuhr] unless the reader
  /// moved Dhuhr to their mosque's time (PrayerAdjust).
  final double noon;

  double byKey(PrayerKey key) => switch (key) {
    PrayerKey.fajr => fajr,
    PrayerKey.sunrise => sunrise,
    PrayerKey.ishraq => ishraq,
    PrayerKey.duha => duha,
    PrayerKey.dhuhr => dhuhr,
    PrayerKey.asr => asr,
    PrayerKey.maghrib => maghrib,
    PrayerKey.sunset => sunset,
    PrayerKey.isha => isha,
    PrayerKey.tahajjud => tahajjud,
  };
}

enum PrayerKey {
  fajr,
  sunrise,
  ishraq,
  duha,
  dhuhr,
  asr,
  maghrib,
  sunset,
  isha,
  tahajjud,
}

const Map<PrayerKey, String> prayerLabelsBn = {
  PrayerKey.fajr: 'ফজর',
  PrayerKey.sunrise: 'সূর্যোদয়',
  PrayerKey.ishraq: 'ইশরাক',
  PrayerKey.duha: 'দুহা',
  PrayerKey.dhuhr: 'যোহর',
  PrayerKey.asr: 'আসর',
  PrayerKey.maghrib: 'মাগরিব',
  PrayerKey.sunset: 'সূর্যাস্ত',
  PrayerKey.isha: 'এশা',
  PrayerKey.tahajjud: 'তাহাজ্জুদ',
};


const List<PrayerKey> farzPrayers = [
  PrayerKey.fajr,
  PrayerKey.dhuhr,
  PrayerKey.asr,
  PrayerKey.maghrib,
  PrayerKey.isha,
];

/// Schedule rows shown on Home (order matters).
const List<PrayerKey> scheduleOrder = [
  PrayerKey.fajr,
  PrayerKey.sunrise,
  PrayerKey.ishraq,
  PrayerKey.duha,
  PrayerKey.dhuhr,
  PrayerKey.asr,
  PrayerKey.maghrib,
  PrayerKey.isha,
  PrayerKey.tahajjud,
];

class PrayerEngine {
  const PrayerEngine._();

  static const int ishraqOffsetMin = 20;
  static const int maghribSafetyMin = 3;

  static adhan.CalculationParameters _params(
    CalcMethod method,
    Madhhab madhhab,
  ) {
    final p = switch (method) {
      // Islamic Foundation Bangladesh = the Karachi angles; its start times
      // are rounded up to the minute in compute() (see the web/API engine)
      CalcMethod.ifb => adhan.CalculationMethodParameters.karachi(),
      CalcMethod.karachi => adhan.CalculationMethodParameters.karachi(),
      CalcMethod.mwl => adhan.CalculationMethodParameters.muslimWorldLeague(),
      CalcMethod.isna => adhan.CalculationMethodParameters.northAmerica(),
      CalcMethod.egypt => adhan.CalculationMethodParameters.egyptian(),
      CalcMethod.makkah => adhan.CalculationMethodParameters.ummAlQura(),
      CalcMethod.dubai => adhan.CalculationMethodParameters.dubai(),
    };
    p.madhab = madhhab == Madhhab.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;
    // The bundled karachi() preset carries a +1 min dhuhr methodAdjustment;
    // the canonical web engine (src/lib/prayer-times.ts, PrayTimes.org)
    // applies none — drop it so mobile and web agree to the minute.
    p.methodAdjustments = {};
    return p;
  }

  static double _minutesUtcAsLocal(DateTime utcTime, double tzOffsetHours) {
    final shifted = utcTime.add(
      Duration(milliseconds: (tzOffsetHours * 3600000).round()),
    );
    return shifted.hour * 60.0 + shifted.minute + shifted.second / 60.0;
  }

  /// Compute the full times bundle for a date (YYYY-MM-DD).
  static PrayerTimesBundle compute(
    String dateKey, {
    double lat = 23.8103,
    double lng = 90.4125,
    double tz = 6.0,
    CalcMethod method = CalcMethod.ifb,
    Madhhab madhhab = Madhhab.hanafi,
    PrayerAdjust adjust = const PrayerAdjust(),
  }) {
    final parts = dateKey.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final coordinates = adhan.Coordinates(lat, lng);
    final params = _params(method, madhhab);
    final times = adhan.PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: params,
      // IFB rounds UP below — it needs the seconds (the library otherwise
      // rounds to the NEAREST minute, which would undo the precaution)
      precision: method == CalcMethod.ifb,
    );

    final fajr = _minutesUtcAsLocal(times.fajr, tz);
    final sunrise = _minutesUtcAsLocal(times.sunrise, tz);
    final dhuhr = _minutesUtcAsLocal(times.dhuhr, tz);
    final asr = _minutesUtcAsLocal(times.asr, tz);
    final sunset = _minutesUtcAsLocal(times.maghrib, tz);
    final isha = _minutesUtcAsLocal(times.isha, tz);

    final ishraq = sunrise + ishraqOffsetMin;
    final duha = sunrise + (dhuhr - sunrise) / 4;
    final maghrib = sunset + maghribSafetyMin;

    // Tahajjud window start = last third of the night, where the night runs
    // SUNSET → next SUNRISE (the fiqh definition the web engine uses:
    // sunset + 2/3 × N, N = sunrise+1440−sunset, wrapped over midnight).
    final nightLen = sunrise + 24 * 60.0 - sunset;
    final tahajjudCont = sunset + (2 * nightLen) / 3;
    final tahajjud = tahajjudCont >= 1440 ? tahajjudCont - 1440 : tahajjudCont;

    // Islamic Foundation Bangladesh: every start time rounded UP to the
    // whole minute (precaution) — matches IFB's published Dhaka timetable
    // to the minute or within one (same rule as src/lib/prayer-times.ts)
    double start(double m) =>
        method == CalcMethod.ifb ? (m - 1e-9).ceilToDouble() : m;
    // then the reader's own minutes (their mosque's azan), start times only
    double mine(PrayerKey k, double m) => start(m) + adjust.of(k);

    return PrayerTimesBundle(
      fajr: mine(PrayerKey.fajr, fajr),
      sunrise: sunrise,
      ishraq: ishraq,
      duha: duha,
      dhuhr: mine(PrayerKey.dhuhr, dhuhr),
      asr: mine(PrayerKey.asr, asr),
      maghrib: mine(PrayerKey.maghrib, maghrib),
      sunset: sunset,
      isha: mine(PrayerKey.isha, isha),
      tahajjud: tahajjud,
      noon: start(dhuhr),
    );
  }

  /// Current waqt: the last farz prayer whose time has begun today
  /// (before the next one). Null between isha and tomorrow's fajr means
  /// isha is still current.
  static PrayerKey currentWaqt(PrayerTimesBundle t, double nowMinutes) {
    if (nowMinutes < t.fajr) return PrayerKey.isha; // pre-fajr = isha waqt
    if (nowMinutes < t.dhuhr) return PrayerKey.fajr;
    if (nowMinutes < t.asr) return PrayerKey.dhuhr;
    if (nowMinutes < t.maghrib) return PrayerKey.asr;
    if (nowMinutes < t.isha) return PrayerKey.maghrib;
    return PrayerKey.isha;
  }

  /// Next prayer + minutes until it (resolves across midnight).
  static (PrayerKey, double) nextPrayer(
    PrayerTimesBundle t,
    double nowMinutes,
  ) {
    for (final key in farzPrayers) {
      final m = t.byKey(key);
      if (nowMinutes < m) return (key, m - nowMinutes);
    }
    return (PrayerKey.fajr, (24 * 60.0 - nowMinutes) + t.fajr);
  }

  /// The three forbidden windows — (start, end) minutes. Port of the web
  /// forbiddenWindows: sunrise −15/+20, zawal −10/+5, sunset −15/+5.
  static List<(String, double, double)> forbiddenWindows(PrayerTimesBundle t) {
    return [
      ('sunrise', t.sunrise - 15, t.sunrise + 20),
      ('zawal', t.noon - 10, t.noon + 5),
      ('sunset', t.sunset - 15, t.sunset + 5),
    ];
  }

  /// Is `nowMinutes` inside any forbidden window? Returns its label or null.
  static String? inForbiddenWindow(PrayerTimesBundle t, double nowMinutes) {
    for (final (label, start, end) in forbiddenWindows(t)) {
      if (nowMinutes >= start && nowMinutes <= end) return label;
    }
    return null;
  }

  /// The post-prayer prompt window: 20 minutes after each waqt begins.
  static PrayerKey? activePostPrayerPrompt(
    PrayerTimesBundle t,
    double nowMinutes,
  ) {
    for (final key in farzPrayers) {
      final m = t.byKey(key);
      if (nowMinutes >= m + 20 && nowMinutes < m + 20 + 30) return key;
    }
    return null;
  }
}
