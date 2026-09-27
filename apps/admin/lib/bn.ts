// Bengali-first formatting helpers (mirrors src/lib/calendars.ts of the web app).

const BN_DIGITS = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];

/** 123 → ১২৩ */
export function toBn(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return "";
  return String(value).replace(/[0-9]/g, (d) => BN_DIGITS[Number(d)]);
}

export const BN_MONTHS = [
  "জানুয়ারি",
  "ফেব্রুয়ারি",
  "মার্চ",
  "এপ্রিল",
  "মে",
  "জুন",
  "জুলাই",
  "আগস্ট",
  "সেপ্টেম্বর",
  "অক্টোবর",
  "নভেম্বর",
  "ডিসেম্বর",
] as const;

export const BN_WEEKDAYS = [
  "রবিবার",
  "সোমবার",
  "মঙ্গলবার",
  "বুধবার",
  "বৃহস্পতিবার",
  "শুক্রবার",
  "শনিবার",
] as const;

/** Single Bengali weekday letter (compact grid header). Sat-first program week. */
const BN_WEEKDAY_LETTERS: Record<number, string> = {
  0: "র",
  1: "সো",
  2: "ম",
  3: "বু",
  4: "বৃ",
  5: "শু",
  6: "শ",
};

export function weekdayLetter(date: Date): string {
  return BN_WEEKDAY_LETTERS[date.getDay()] ?? "";
}

export function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate()
  ).padStart(2, "0")}`;
}

export function parseKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

export function addDays(key: string, days: number): string {
  const d = parseKey(key);
  d.setDate(d.getDate() + days);
  return dateKey(d);
}

/** "2026-09" → "সেপ্টেম্বর ২০২৬" */
export function monthLabel(month: string): string {
  const [y, m] = month.split("-").map(Number);
  return `${BN_MONTHS[(m ?? 1) - 1]} ${toBn(y)}`;
}

/** YYYY-MM-DD → "২৭ সেপ্টেম্বর ২০২৬" */
export function dateLabelBn(key: string): string {
  const d = parseKey(key);
  return `${toBn(d.getDate())} ${BN_MONTHS[d.getMonth()]} ${toBn(d.getFullYear())}`;
}

/** Full today line: "রবিবার, ২৭ সেপ্টেম্বর ২০২৬" */
export function todayLineBn(d = new Date()): string {
  return `${BN_WEEKDAYS[d.getDay()]}, ${toBn(d.getDate())} ${BN_MONTHS[d.getMonth()]} ${toBn(
    d.getFullYear()
  )}`;
}

/** ISO datetime → "২৭ সেপ্টেম্বর, ১০:৪৮" (12h with ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত) */
export function dateTimeBn(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  const h24 = d.getHours();
  const part =
    h24 < 4 ? "রাত" : h24 < 6 ? "ভোর" : h24 < 12 ? "সকাল" : h24 < 16 ? "দুপুর" : h24 < 18 ? "বিকাল" : h24 < 19 ? "সন্ধ্যা" : "রাত";
  let h = h24 % 12;
  if (h === 0) h = 12;
  return `${toBn(d.getDate())} ${BN_MONTHS[d.getMonth()]}, ${part} ${toBn(h)}:${String(
    d.getMinutes()
  ).padStart(2, "0").replace(/[0-9]/g, (x) => BN_DIGITS[Number(x)])}`;
}

/** Relative Bengali time: এইমাত্র / X মিনিট আগে / আজ / গতকাল / X দিন আগে / X মাস আগে */
export function relativeBn(iso: string): string {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "—";
  const diffMs = Date.now() - t;
  const min = Math.floor(diffMs / 60_000);
  if (min < 1) return "এইমাত্র";
  if (min < 60) return `${toBn(min)} মিনিট আগে`;
  const hours = Math.floor(min / 60);
  if (hours < 24) return `${toBn(hours)} ঘণ্টা আগে`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "গতকাল";
  if (days < 30) return `${toBn(days)} দিন আগে`;
  const months = Math.floor(days / 30.44);
  if (months < 12) return `${toBn(months)} মাস আগে`;
  return `${toBn(Math.floor(months / 12))} বছর আগে`;
}

/** Saturday week-start (BD convention) for a date — "2026-09-26". */
export function weekStartOf(d = new Date()): string {
  const day = d.getDay(); // 0=Sun … 6=Sat
  const back = (day + 1) % 7; // Sat→0, Sun→1 … Fri→6
  const s = new Date(d);
  s.setDate(s.getDate() - back);
  return dateKey(s);
}

/** Hijri day for a date via the umalqura calendar (ayyam-e-beez = 13–15). */
export function hijriDay(key: string): number | null {
  try {
    const fmt = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
      day: "numeric",
      timeZone: "UTC",
    });
    const d = parseKey(key);
    const utc = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const n = Number(fmt.format(utc));
    return Number.isFinite(n) ? n : null;
  } catch {
    return null;
  }
}

/** Is the amal expected on this date for its cadence? */
export function cadenceApplies(cadence: string, key: string): boolean {
  const d = parseKey(key);
  const wd = d.getDay(); // 0=Sun … 6=Sat
  switch (cadence) {
    case "daily":
      return true;
    case "weekly:any":
      return true;
    case "weekly:fri":
      return wd === 5;
    case "weekly:mon_thu":
      return wd === 1 || wd === 4;
    case "monthly:ayyam_beez": {
      const h = hijriDay(key);
      return h !== null && h >= 13 && h <= 15;
    }
    default:
      return true;
  }
}

/** Client mirror of the API's amalPoints (apps/api/src/shared/amal.ts). */
export function amalPoints(
  value: unknown,
  def: { inputType: string; target: Record<string, number> | null },
  userCategory: string
): number {
  if (def.inputType === "tristate") return value === "jamaat" || value === "alone" ? 1 : 0;
  if (def.inputType === "boolean") return value === true ? 1 : 0;
  if (def.inputType === "count" || def.inputType === "quantity") {
    const n = typeof value === "number" ? value : Number(value);
    if (!isFinite(n) || n <= 0) return 0;
    const target = def.target?.[userCategory] ?? def.target?.["general"] ?? 1;
    return n >= target ? 1 : 0.5;
  }
  if (def.inputType === "text") {
    return typeof value === "string" && value.trim().length > 0 ? 1 : 0;
  }
  return 0;
}

/** Client mirror of completionPctFromEntries for the last `days` days. */
export function completionPct(
  entries: { amalKey: string; value: unknown }[],
  dailyDefs: { key: string; inputType: string; target: Record<string, number> | null }[],
  userCategory: string,
  days: string[]
): number {
  const defMap = new Map(dailyDefs.map((d) => [d.key, d]));
  let points = 0;
  for (const e of entries) {
    const def = defMap.get(e.amalKey);
    if (!def) continue;
    points += amalPoints(e.value, def, userCategory);
  }
  const expected = dailyDefs.length * Math.max(days.length, 1);
  if (expected <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((100 * points) / expected)));
}

/** Today in Bangladesh (UTC+6, no DST) as YYYY-MM-DD. */
export function bdToday(): string {
  const shifted = new Date(Date.now() + 6 * 3_600_000);
  return shifted.toISOString().slice(0, 10);
}

/** Current month YYYY-MM in Bangladesh. */
export function bdMonth(): string {
  return bdToday().slice(0, 7);
}
