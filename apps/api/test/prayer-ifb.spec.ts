// The Islamic Foundation Bangladesh method (the engine the API and the web
// share): Karachi angles, start times rounded up to the minute — against
// IFB's published Dhaka timetable.
import { computePrayerTimesForDate, CALC_METHODS } from "src/shared/prayer-times";

const dhaka = (method: string) =>
  ({ lat: 23.8103, lng: 90.4125, tzOffsetHours: 6, method, madhhab: "hanafi" }) as never;
const at = (h: number, m: number) => h * 60 + m;

describe("Islamic Foundation Bangladesh", () => {
  it("is listed first, under its own name", () => {
    expect(Object.keys(CALC_METHODS)[0]).toBe("ifb");
    expect(CALC_METHODS.ifb.labelBn).toBe("ইসলামিক ফাউন্ডেশন বাংলাদেশ");
  });

  it("matches the published 12 Dec 2025 Dhaka times", () => {
    const t = computePrayerTimesForDate(new Date("2025-12-12T06:00:00Z"), dhaka("ifb"));
    expect([t.dhuhr, t.asr, t.maghrib, t.isha]).toEqual([at(11, 52), at(15, 37), at(17, 16), at(18, 34)]);
  });

  it("is within a minute on 28 Aug 2026 and never earlier than Karachi", () => {
    const t = computePrayerTimesForDate(new Date("2026-08-28T06:00:00Z"), dhaka("ifb"));
    const k = computePrayerTimesForDate(new Date("2026-08-28T06:00:00Z"), dhaka("karachi"));
    for (const [ours, ifb] of [[t.asr, at(16, 31)], [t.maghrib, at(18, 24)], [t.isha, at(19, 40)]]) {
      expect(Math.abs(ours - ifb)).toBeLessThanOrEqual(1);
    }
    for (const key of ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const) {
      expect(Number.isInteger(t[key])).toBe(true);
      expect(t[key] - k[key]).toBeGreaterThanOrEqual(0);
      expect(t[key] - k[key]).toBeLessThan(1);
    }
  });
});
