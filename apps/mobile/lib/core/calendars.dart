/// Calendars: Bangla বঙ্গাব্দ (2019 Bangladesh reform), Hijri (hijri package
/// with Kuwaiti arithmetic fallback), Bengali clock periods — ports of
/// src/lib/calendars.ts so web + mobile always agree.
library;

import 'package:hijri/hijri_calendar.dart' as hijri;

import 'bn_digits.dart';
import 'date_keys.dart';

// ── Gregorian labels ─────────────────────────────────────────────────────────

const List<String> gregMonthsBn = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

const List<String> weekdaysBn = [
  'রবিবার',
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
];

const List<String> weekdaysShortBn = [
  'রবি',
  'সোম',
  'মঙ্গল',
  'বুধ',
  'বৃহঃ',
  'শুক্র',
  'শনি',
];

String weekdayBn(DateTime d) => weekdaysBn[d.weekday % 7];

// ── Bangla calendar (বঙ্গাব্দ) ───────────────────────────────────────────────

const List<String> banglaMonthsBn = [
  'বৈশাখ',
  'জ্যৈষ্ঠ',
  'আষাঢ়',
  'শ্রাবণ',
  'ভাদ্র',
  'আশ্বিন',
  'কার্তিক',
  'অগ্রহায়ণ',
  'পৌষ',
  'মাঘ',
  'ফাল্গুন',
  'চৈত্র',
];

bool _isLeapGreg(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

class BanglaDate {
  const BanglaDate({
    required this.year,
    required this.monthIndex,
    required this.day,
    required this.formatted,
  });
  final int year;
  final int monthIndex; // 0-11
  final int day;
  final String formatted; // "১৫ আষাঢ় ১৪৩২"
}

/// Bangla (বঙ্গাব্দ) date per the Bangladesh 2019 revised calendar:
/// Boishakh 1 = April 14; Falgun has 30 days iff the starting Greg year is leap.
BanglaDate banglaDate(DateTime d) {
  final gy = d.year;
  final startYear =
      DateTime(gy, 4, 14).isBefore(d) ||
          dateKey(DateTime(gy, 4, 14)) == dateKey(d)
      ? gy
      : gy - 1;
  final epoch = DateTime(startYear, 4, 14);
  var days = d.difference(epoch).inDays;
  final banglaYear = startYear - 593;

  final lengths = <int>[
    31,
    31,
    31,
    31,
    31,
    30,
    30,
    30,
    30,
    30,
    _isLeapGreg(startYear) ? 30 : 29,
    30,
  ];
  var monthIndex = 0;
  while (monthIndex < 12 && days >= lengths[monthIndex]) {
    days -= lengths[monthIndex];
    monthIndex++;
  }
  if (monthIndex > 11) monthIndex = 11;
  final day = (days < 0 ? 0 : days) + 1;
  return BanglaDate(
    year: banglaYear,
    monthIndex: monthIndex,
    day: day,
    formatted:
        '${toBn(day)} ${banglaMonthsBn[monthIndex.clamp(0, 11)]} ${toBn(banglaYear)}',
  );
}

// ── Hijri calendar ───────────────────────────────────────────────────────────

const List<String> hijriMonthsBn = [
  'মুহাররম',
  'সফর',
  'রবিউল আউয়াল',
  'রবিউস সানি',
  'জমাদিউল আউয়াল',
  'জমাদিউস সানি',
  'রজব',
  'শাবান',
  'রমজান',
  'শাওয়াল',
  'জিলকদ',
  'জিলহজ',
];

class HijriDate {
  const HijriDate({
    required this.year,
    required this.monthIndex,
    required this.day,
    required this.formatted,
  });
  final int year;
  final int monthIndex; // 0-11
  final int day;
  final String formatted; // "১০ জিলহজ ১৪৪৬"
}

/// Kuwaiti arithmetic Hijri — deterministic fallback, ported from the web
/// engine (identical numbers on both platforms when the table lookup misses).
HijriDate _hijriArithmetic(DateTime d) {
  final jd =
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000 +
      2440588;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j =
      ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l =
      l -
      ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) +
      29;
  final month = (24 * l) ~/ 709;
  final day = l - (709 * month) ~/ 24;
  final year = 30 * n + j - 30;
  return HijriDate(
    year: year,
    monthIndex: (month - 1).clamp(0, 11),
    day: day,
    formatted:
        '${toBn(day)} ${hijriMonthsBn[(month - 1).clamp(0, 11)]} ${toBn(year)}',
  );
}

/// Hijri date with admin-set ±N day moon-sighting adjustment.
HijriDate hijriDate(DateTime d, {int adjustDays = 0}) {
  final adj = d.add(Duration(days: adjustDays));
  try {
    final h = hijri.HijriCalendar.fromDate(adj);
    final y = h.hYear;
    final mi = (h.hMonth - 1).clamp(0, 11);
    final day = h.hDay;
    if (y > 1300 && y < 1600 && day >= 1 && day <= 30) {
      return HijriDate(
        year: y,
        monthIndex: mi,
        day: day,
        formatted: '${toBn(day)} ${hijriMonthsBn[mi]} ${toBn(y)}',
      );
    }
  } catch (_) {
    // fall through to the arithmetic port
  }
  return _hijriArithmetic(adj);
}

/// Ayyam-e-Beez: Hijri 13–15 of any lunar month (white days).
bool isAyyamBeez(DateTime d, {int adjustDays = 0}) {
  final day = hijriDate(d, adjustDays: adjustDays).day;
  return day == 13 || day == 14 || day == 15;
}

// ── Bengali clock ────────────────────────────────────────────────────────────

String timePeriodBn(int hour) {
  if (hour < 4) return 'রাত';
  if (hour < 6) return 'ভোর';
  if (hour < 12) return 'সকাল';
  if (hour < 16) return 'দুপুর';
  if (hour < 18) return 'বিকাল';
  if (hour < 19) return 'সন্ধ্যা';
  return 'রাত';
}

/// Minutes-from-midnight → "ভোর ৩:৪৩" (Bengali) or "3:43 AM" (en/ar).
String formatTimeBn(double minutes, {bool bengali = true}) {
  final m = ((minutes % 1440) + 1440) % 1440;
  final h24 = m ~/ 60;
  final mm = (m % 60).round().toString().padLeft(2, '0');
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  if (bengali) {
    return '${timePeriodBn(h24)} ${toBn(h12)}:${toBn(mm)}';
  }
  final ampm = h24 < 12 ? 'AM' : 'PM';
  return '$h12:$mm $ampm';
}

/// "১৫ জুন, রবিবার" style day header.
String formatDayHeaderBn(DateTime d, {bool bengali = true}) {
  if (!bengali) {
    return '${d.day} ${_gregMonthsEn[d.month - 1]}, ${_weekdaysEn[d.weekday - 1]}';
  }
  return '${toBn(d.day)} ${gregMonthsBn[d.month - 1]}, ${weekdaysBn[d.weekday % 7]}';
}

const List<String> _gregMonthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdaysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
