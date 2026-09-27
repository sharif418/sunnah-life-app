// ─────────────────────────────────────────────────────────────────────────────
// On-device prayer time engine (no external API) — mirrors `adhan_dart` role.
// Solar-position algorithm per PrayTimes.org (Jean Meeus approximations),
// angle-based fajr/isha + shadow-factor Asr (Hanafi = 2, Shafi'i = 1),
// night-middle high-latitude adjustment with polar NaN guards.
// ─────────────────────────────────────────────────────────────────────────────

import type { CalcMethodKey, Madhhab, PrayerConfig, PrayerKey, PrayerTimes } from "./domain";

const DEG = Math.PI / 180;
const sin = (d: number) => Math.sin(d * DEG);
const cos = (d: number) => Math.cos(d * DEG);
const tan = (d: number) => Math.tan(d * DEG);
const arcsin = (x: number) => Math.asin(x) / DEG;
const arccos = (x: number) => Math.acos(x) / DEG;
const arctan2 = (y: number, x: number) => Math.atan2(y, x) / DEG;
const arccot = (x: number) => Math.atan(1 / x) / DEG;
const fixAngle = (a: number) => ((a % 360) + 360) % 360;
const fixHour = (h: number) => ((h % 24) + 24) % 24;

export const CALC_METHODS: Record<
  CalcMethodKey,
  { labelBn: string; labelEn: string; fajr: number; isha: number; ishaMinutes?: number }
> = {
  karachi: { labelBn: "করাচি (বাংলাদেশ ডিফল্ট)", labelEn: "Karachi / Univ. of Islamic Sciences", fajr: 18, isha: 18 },
  mwl: { labelBn: "মুসলিম ওয়ার্ল্ড লীগ", labelEn: "Muslim World League", fajr: 18, isha: 17 },
  isna: { labelBn: "ইসনা (উত্তর আমেরিকা)", labelEn: "ISNA", fajr: 15, isha: 15 },
  egypt: { labelBn: "মিসরীয় সাধারণ সংস্থা", labelEn: "Egyptian General Authority", fajr: 19.5, isha: 17.5 },
  makkah: { labelBn: "উম্মুল কুরা, মক্কা", labelEn: "Umm al-Qura, Makkah", fajr: 18.5, isha: 0, ishaMinutes: 90 },
  dubai: { labelBn: "দুবাই", labelEn: "Dubai", fajr: 18.2, isha: 18.2 },
};

/** Ishraq begins ~20 min after sunrise (documented assumption, PLAN.md §9). */
export const ISHRAQ_AFTER_SUNRISE_MIN = 20;
/** Bangladesh convention: a small safety added to sunset for Maghrib (configurable). */
export const MAGHRIB_SAFETY_MIN = 3;

/** Sun declination + equation of time (hours) for a Julian date. */
function sunPosition(jd: number): { declination: number; equation: number } {
  const D = jd - 2451545.0;
  const g = fixAngle(357.529 + 0.98560028 * D);
  const q = fixAngle(280.459 + 0.98564736 * D);
  const L = fixAngle(q + 1.915 * sin(g) + 0.02 * sin(2 * g));
  const e = 23.439 - 0.00000036 * D;
  const RA = arctan2(cos(e) * sin(L), cos(L)) / 15;
  const declination = arcsin(sin(e) * sin(L));
  const equation = q / 15 - fixHour(RA);
  return { declination, equation };
}

/** Julian day at 00:00 UTC of the given civil date. */
function julianDay(y: number, m: number, d: number): number {
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  const A = Math.floor(y / 100);
  const B = 2 - A + Math.floor(A / 4);
  return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d + B - 1524.5;
}

/** Hour angle (hours from solar noon) at which the sun reaches altitude `angle`. */
function sunAngleTime(angle: number, lat: number, decl: number, direction: "ccw" | "cw"): number {
  const numerator = -sin(angle) - sin(lat) * sin(decl);
  const denominator = cos(lat) * cos(decl);
  if (Math.abs(denominator) < 1e-9) return NaN;
  const ratio = Math.min(1, Math.max(-1, numerator / denominator)); // polar guard
  const t = arccos(ratio) / 15;
  return direction === "ccw" ? -t : t;
}

/** Asr hour angle: shadow length = factor × object height. */
function asrTime(factor: number, lat: number, decl: number): number {
  const angle = -arccot(factor + tan(Math.abs(lat - decl)));
  return sunAngleTime(angle, lat, decl, "cw");
}

/**
 * Compute all prayer times for a civil date at a location.
 * @param dateParts {y, m, d} in the *local* calendar
 * @returns minutes from local midnight (floats)
 */
export function computePrayerTimes(
  dateParts: { y: number; m: number; d: number },
  cfg: Pick<PrayerConfig, "lat" | "lng" | "tzOffsetHours" | "method" | "madhhab">
): PrayerTimes {
  const method = CALC_METHODS[cfg.method] ?? CALC_METHODS.karachi;
  const asrFactor = cfg.madhhab === "shafii" ? 1 : 2; // Hanafi = 2
  const jd = julianDay(dateParts.y, dateParts.m, dateParts.d) - cfg.lng / (15 * 24);
  const { declination: decl, equation } = sunPosition(jd);

  // Solar hours, then shifted into local civil time.
  const tzShift = cfg.tzOffsetHours - cfg.lng / 15;
  const dhuhrH = fixHour(12 - equation) + tzShift;
  const sunriseH = dhuhrH + sunAngleTime(0.833, cfg.lat, decl, "ccw");
  const sunsetH = dhuhrH + sunAngleTime(0.833, cfg.lat, decl, "cw");

  const fajrRawH = dhuhrH + sunAngleTime(method.fajr, cfg.lat, decl, "ccw");
  const ishaRawH =
    method.ishaMinutes != null
      ? sunsetH + method.ishaMinutes / 60
      : dhuhrH + sunAngleTime(method.isha, cfg.lat, decl, "cw");
  const asrH = dhuhrH + asrTime(asrFactor, cfg.lat, decl);

  // Convert to minutes-from-local-midnight domain.
  const toMin = (h: number) => fixHour(h) * 60;
  const dhuhr = toMin(dhuhrH);
  const sunrise = toMin(sunriseH);
  const sunset = toMin(sunsetH);
  const fajrRaw = toMin(fajrRawH);
  const ishaRaw = toMin(ishaRawH);
  const asr = toMin(asrH);

  // Night-middle high-latitude adjustment (continuous domain):
  //   night N runs today-sunset → tomorrow-sunrise (approx by today's sunrise + 1440).
  //   fajr must not be before mid-night; isha must not be after mid-night.
  const N = sunrise + 1440 - sunset; // night duration in minutes
  const midNight = sunset + N / 2; // continuous, typically ≈ 1440
  let fajr = fajrRaw + 1440; // tomorrow-morning domain
  if (!isFinite(fajr)) fajr = midNight;
  if (fajr < midNight) fajr = midNight;
  fajr = fajr - 1440; // back to today display domain
  let isha = ishaRaw;
  if (!isFinite(isha)) isha = midNight;
  if (isha > midNight) isha = midNight;

  const maghrib = sunset + MAGHRIB_SAFETY_MIN;

  // Derived blessed times
  const ishraq = sunrise + ISHRAQ_AFTER_SUNRISE_MIN;
  const duha = sunrise + (dhuhr - sunrise) / 4; // sun a quarter way to zenith
  // Last third of the night (tahajjud window begins) — early next morning.
  const tahajjudCont = sunset + (2 * N) / 3;
  const tahajjud = tahajjudCont >= 1440 ? tahajjudCont - 1440 : tahajjudCont;

  return {
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
  };
}

/** Compute prayer times for a JS Date in local time. */
export function computePrayerTimesForDate(date: Date, cfg: PrayerConfig): PrayerTimes {
  return computePrayerTimes(
    { y: date.getFullYear(), m: date.getMonth() + 1, d: date.getDate() },
    cfg
  );
}

export interface NextPrayerInfo {
  key: PrayerKey;
  /** Date object of the next prayer occurrence */
  at: Date;
  /** currently active waqt (the one whose time has begun) among the 5 fard */
  current: PrayerKey;
  /** minutes until next prayer (from `now`) */
  minutesUntil: number;
}

/** The five fard prayers in order, used for countdown/current waqt. */
export function nextPrayer(now: Date, cfg: PrayerConfig): NextPrayerInfo {
  const today = computePrayerTimesForDate(now, cfg);
  const tomorrow = computePrayerTimesForDate(new Date(now.getTime() + 86400000), cfg);
  const nowMin = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;

  const order: PrayerKey[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];
  const todays = order.map((k) => ({ key: k, min: today[k] }));

  let current: PrayerKey = "isha";
  for (const p of todays) {
    if (nowMin >= p.min) current = p.key;
  }
  const nextToday = todays.find((p) => p.min > nowMin);
  if (nextToday) {
    return {
      key: nextToday.key,
      at: minsToDate(now, nextToday.min),
      current,
      minutesUntil: nextToday.min - nowMin,
    };
  }
  // next fajr tomorrow
  return {
    key: "fajr",
    at: minsToDate(now, tomorrow.fajr + 24 * 60),
    current,
    minutesUntil: tomorrow.fajr + 24 * 60 - nowMin,
  };
}

function minsToDate(now: Date, minutesFromMidnightTonight: number): Date {
  const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  return new Date(midnight + minutesFromMidnightTonight * 60000);
}

// ── Forbidden (makruh) salat windows ────────────────────────────────────────
// Exact ranges derived from the day's times; constants documented in PLAN.md §9.

export interface ForbiddenWindow {
  key: "sunrise" | "zawal" | "sunset";
  labelBn: string;
  from: number; // minutes
  to: number;
}

export function forbiddenWindows(t: PrayerTimes): ForbiddenWindow[] {
  return [
    { key: "sunrise", labelBn: "সূর্যোদয়ের নিষিদ্ধ সময়", from: t.sunrise - 15, to: t.sunrise + 20 },
    { key: "zawal", labelBn: "জওয়াল (সূর্য মাথার উপরে)", from: t.dhuhr - 10, to: t.dhuhr + 5 },
    { key: "sunset", labelBn: "সূর্যাস্তের নিষিদ্ধ সময়", from: t.sunset - 15, to: t.sunset + 5 },
  ];
}

export function isWithinForbidden(nowMin: number, t: PrayerTimes): ForbiddenWindow | null {
  return forbiddenWindows(t).find((w) => nowMin >= w.from && nowMin <= w.to) ?? null;
}
