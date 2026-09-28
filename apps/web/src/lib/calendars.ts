// ─────────────────────────────────────────────────────────────────────────────
// Calendars & Bengali formatting: Bangla (বঙ্গাব্দ, 2019 Bangladesh reform),
// Hijri (Intl Umm al-Qura + Kuwaiti arithmetic fallback with admin ±1 adjust),
// Bengali numerals, Bengali clock periods, date-string helpers.
// ─────────────────────────────────────────────────────────────────────────────

const BN_DIGITS = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];

/** Convert any number/numeric string to Bengali digits. */
export function toBn(value: number | string): string {
  return String(value).replace(/[0-9]/g, (d) => BN_DIGITS[Number(d)]);
}

/** Local YYYY-MM-DD key (no timezone drift). */
export function dateKey(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function parseKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function addDays(key: string, days: number): string {
  const d = parseKey(key);
  d.setDate(d.getDate() + days);
  return dateKey(d);
}

// ── Gregorian (Bengali labels) ───────────────────────────────────────────────

export const GREG_MONTHS_BN = [
  "জানুয়ারি", "ফেব্রুয়ারি", "মার্চ", "এপ্রিল", "মে", "জুন",
  "জুলাই", "আগস্ট", "সেপ্টেম্বর", "অক্টোবর", "নভেম্বর", "ডিসেম্বর",
];
export const WEEKDAYS_BN = ["রবিবার", "সোমবার", "মঙ্গলবার", "বুধবার", "বৃহস্পতিবার", "শুক্রবার", "শনিবার"];
export const WEEKDAYS_SHORT_BN = ["রবি", "সোম", "মঙ্গল", "বুধ", "বৃহঃ", "শুক্র", "শনি"];

export function gregorianBn(d: Date = new Date()): string {
  return `${toBn(d.getDate())} ${GREG_MONTHS_BN[d.getMonth()]} ${toBn(d.getFullYear())}`;
}

export function weekdayBn(d: Date = new Date()): string {
  return WEEKDAYS_BN[d.getDay()];
}

// ── Bangla calendar (বঙ্গাব্দ) — Bangladesh 2019 revised calendar ─────────────
// Boishakh 1 = April 14 every year. Month lengths: 31,31,31,31,31,30,30,30,30,30,29|30,30.
// Falgun has 30 days iff the Gregorian year containing it is a leap year.

export const BANGLA_MONTHS_BN = [
  "বৈশাখ", "জ্যৈষ্ঠ", "আষাঢ়", "শ্রাবণ", "ভাদ্র", "আশ্বিন",
  "কার্তিক", "অগ্রহায়ণ", "পৌষ", "মাঘ", "ফাল্গুন", "চৈত্র",
];

function isLeapGreg(y: number): boolean {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

export interface BanglaDate {
  year: number;
  monthIndex: number; // 0-11
  day: number;
  formatted: string; // "১৫ আষাঢ় ১৪৩২"
}

export function banglaDate(d: Date = new Date()): BanglaDate {
  const gy = d.getFullYear();
  // If on/after April 14 → Bangla year started this Greg year; else previous.
  const startYear = new Date(gy, 3, 14).getTime() <= d.getTime() ? gy : gy - 1;
  const epoch = new Date(startYear, 3, 14); // Boishakh 1
  let days = Math.floor((d.getTime() - epoch.getTime()) / 86400000);
  const banglaYear = startYear - 593;

  const lengths = [31, 31, 31, 31, 31, 30, 30, 30, 30, 30, isLeapGreg(startYear) ? 30 : 29, 30];
  let monthIndex = 0;
  while (monthIndex < 12 && days >= lengths[monthIndex]) {
    days -= lengths[monthIndex];
    monthIndex++;
  }
  if (monthIndex > 11) monthIndex = 11; // guard
  const day = Math.max(0, days) + 1;

  return {
    year: banglaYear,
    monthIndex,
    day,
    formatted: `${toBn(day)} ${BANGLA_MONTHS_BN[Math.min(monthIndex, 11)]} ${toBn(banglaYear)}`,
  };
}

// ── Hijri calendar ──────────────────────────────────────────────────────────

export const HIJRI_MONTHS_BN = [
  "মুহাররম", "সফর", "রবিউল আউয়াল", "রবিউস সানি", "জমাদিউল আউয়াল", "জমাদিউস সানি",
  "রজব", "শাবান", "রমজান", "শাওয়াল", "জিলকদ", "জিলহজ",
];

export interface HijriDate {
  year: number;
  monthIndex: number; // 0-11
  day: number;
  formatted: string; // "১০ জিলহজ ১৪৪৬"
  /** YYYY-M-D machine form */
  iso: string;
}

/** Kuwaiti arithmetic fallback (when Intl lacks islamic-umalqura). */
function hijriArithmetic(d: Date): { year: number; monthIndex: number; day: number } {
  const jd = Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000) + 2440588;
  let l = jd - 1948440 + 10632;
  const n = Math.floor((l - 1) / 10631);
  l = l - 10631 * n + 354;
  const j =
    Math.floor((10985 - l) / 5316) * Math.floor((50 * l) / 17719) +
    Math.floor(l / 5670) * Math.floor((43 * l) / 15238);
  l =
    l -
    Math.floor((30 - j) / 15) * Math.floor((17719 * j) / 50) -
    Math.floor(j / 16) * Math.floor((15238 * j) / 43) +
    29;
  const month = Math.floor((24 * l) / 709);
  const day = l - Math.floor((709 * month) / 24);
  const year = 30 * n + j - 30;
  return { year, monthIndex: month - 1, day };
}

let umalquraFmt: Intl.DateTimeFormat | null = null;
function hijriIntl(d: Date): { year: number; monthIndex: number; day: number } | null {
  try {
    if (!umalquraFmt) {
      umalquraFmt = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
        day: "numeric",
        month: "numeric",
        year: "numeric",
        timeZone: "UTC",
      });
    }
    const parts = umalquraFmt.formatToParts(
      new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    );
    const get = (t: string) => Number(parts.find((p) => p.type === t)?.value?.replace(/\D/g, ""));
    const day = get("day");
    const monthIndex = get("month") - 1;
    const year = get("year");
    if (day && monthIndex >= 0 && year) return { year, monthIndex, day };
    return null;
  } catch {
    return null;
  }
}

/** Hijri date with admin-set ±N day Bangladesh moon-sighting adjustment. */
export function hijriDate(d: Date = new Date(), adjustDays = 0): HijriDate {
  const adj = new Date(d.getTime() + adjustDays * 86400000);
  const h = hijriIntl(adj) ?? hijriArithmetic(adj);
  const mi = Math.min(11, Math.max(0, h.monthIndex));
  return {
    year: h.year,
    monthIndex: mi,
    day: h.day,
    formatted: `${toBn(h.day)} ${HIJRI_MONTHS_BN[mi]} ${toBn(h.year)}`,
    iso: `${h.year}-${mi + 1}-${h.day}`,
  };
}

/** Ayyam-e-Beez: Hijri 13–15 of any lunar month (white days). */
export function isAyyamBeez(d: Date = new Date(), adjustDays = 0): boolean {
  const day = hijriDate(d, adjustDays).day;
  return day === 13 || day === 14 || day === 15;
}

// ── Bengali clock ───────────────────────────────────────────────────────────

export function timePeriodBn(hour: number): string {
  if (hour < 4) return "রাত";
  if (hour < 6) return "ভোর";
  if (hour < 12) return "সকাল";
  if (hour < 16) return "দুপুর";
  if (hour < 18) return "বিকাল";
  if (hour < 19) return "সন্ধ্যা";
  return "রাত";
}

/** Format minutes-from-midnight as a Bengali clock string, e.g. "ভোর ৩:৪৩". */
export function formatTimeBn(minutes: number): string {
  const m = ((minutes % 1440) + 1440) % 1440;
  const h24 = Math.floor(m / 60);
  const mm = Math.round(m % 60);
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${timePeriodBn(h24)} ${toBn(h12)}:${toBn(String(mm).padStart(2, "0"))}`;
}

/** English format: "3:43 AM". */
export function formatTimeEn(minutes: number): string {
  const m = ((minutes % 1440) + 1440) % 1440;
  const h24 = Math.floor(m / 60);
  const mm = Math.round(m % 60);
  const ampm = h24 < 12 ? "AM" : "PM";
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h12}:${String(mm).padStart(2, "0")} ${ampm}`;
}

export function formatTime(minutes: number, lang: "bn" | "en" | "ar" = "bn"): string {
  return lang === "bn" ? formatTimeBn(minutes) : formatTimeEn(minutes);
}

/** "১৫ জুন, রবিবার" style. */
export function formatDayHeaderBn(d: Date): string {
  return `${toBn(d.getDate())} ${GREG_MONTHS_BN[d.getMonth()]}, ${weekdayBn(d)}`;
}

/** Duration in Bengali: "২ ঘ ১৫ মি" */
export function formatDurationBn(totalMinutes: number): string {
  const h = Math.floor(totalMinutes / 60);
  const m = Math.round(totalMinutes % 60);
  if (h <= 0) return `${toBn(m)} মি`;
  return `${toBn(h)} ঘ ${toBn(m)} মি`;
}
