// Day-part labeller boundaries — W5.
//
// The reported bug: যোহর at 11:59 rendered as "সকাল ১১:৫৯" on the Home
// schedule because the labeller cut at whole hours (hour < 12 → সকাল).
// দুপুর starts at 11:30 — minute precision is required, so the boundary
// table is exercised at every edge (one minute before, exactly at, and
// mid-interval) for all six Bengali day parts.
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/core/calendars.dart';

void main() {
  void expectPeriod(int h, int m, String expected, {String? via}) {
    final minutes = h * 60 + m;
    expect(
      timePeriodBnFromMinutes(minutes),
      expected,
      reason: '$h:${m.toString().padLeft(2, '0')} must be $expected',
    );
    if (via != null) {
      expect(
        via,
        contains(expected),
        reason: 'formatTimeBn output "$via" must carry the $expected label',
      );
    }
  }

  test('day-part boundaries — minute precision', () {
    // রাত: 00:00–03:59
    expectPeriod(0, 0, 'রাত');
    expectPeriod(3, 59, 'রাত');
    // ভোর: 04:00–05:59
    expectPeriod(4, 0, 'ভোর');
    expectPeriod(5, 59, 'ভোর');
    // সকাল: 06:00–11:29
    expectPeriod(6, 0, 'সকাল');
    expectPeriod(11, 29, 'সকাল');
    // দুপুর: 11:30–14:59 — THE FIX: Zuhr at 11:59 is midday.
    expectPeriod(11, 30, 'দুপুর');
    expectPeriod(11, 59, 'দুপুর');
    expectPeriod(14, 59, 'দুপুর');
    // বিকাল: 15:00–16:59
    expectPeriod(15, 0, 'বিকাল');
    expectPeriod(16, 59, 'বিকাল');
    // সন্ধ্যা: 17:00–18:59 — Maghrib (17:12–18:47 across the BD year)
    // must never read বিকাল.
    expectPeriod(17, 0, 'সন্ধ্যা');
    expectPeriod(17, 51, 'সন্ধ্যা');
    expectPeriod(18, 59, 'সন্ধ্যা');
    // রাত: 19:00–23:59
    expectPeriod(19, 0, 'রাত');
    expectPeriod(23, 59, 'রাত');
  });

  test('formatTimeBn carries the minute-precision label', () {
    // The exact reported case: a Zuhr window starting 11:59.
    expect(
      formatTimeBn(11 * 60 + 59, bengali: true),
      'দুপুর ১১:৫৯',
    );
    // One minute earlier is still morning.
    expect(
      formatTimeBn(11 * 60 + 29, bengali: true),
      'সকাল ১১:২৯',
    );
    // The Asr boundary: 15:00 sharp flips to বিকাল.
    expect(
      formatTimeBn(15 * 60, bengali: true),
      'বিকাল ৩:০০',
    );
  });

  test('hour-only timePeriodBn delegates at the hour grid', () {
    // Kept for compatibility: whole hours land exactly on grid points.
    expect(timePeriodBn(11), 'সকাল');
    expect(timePeriodBn(12), 'দুপুর');
    expect(timePeriodBn(15), 'বিকাল');
    expect(timePeriodBn(19), 'রাত');
  });
}
