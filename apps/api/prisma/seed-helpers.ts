// Shared pure helpers of the seed scripts (demo history generation).
// Kept module-local to prisma/ — no runtime code imports these.
const _BN_DIGITS = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];
export function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
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
export function weekStartOfSafe(d: Date): string {
  const diff = (d.getDay() + 1) % 7; // Sat → 0, Sun → 1, … Fri → 6
  return dateKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() - diff));
}
export function hijriArithmetic(d: Date): { year: number; monthIndex: number; day: number } {
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
export function hijriIso(d: Date): string {
  const h = hijriArithmetic(d);
  return `${h.year}-${h.monthIndex + 1}-${h.day}`;
}
export function isAyyamBeez(d: Date): boolean {
  const day = hijriArithmetic(d).day;
  return day === 13 || day === 14 || day === 15;
}

// deterministic PRNG so reseeding always produces the same history
export function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export function hashStr(s: string): number {
  let h = 2166136261;
  for (const c of s) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return h >>> 0;
}

export interface DefShape {
  key: string;
  titleBn: string;
  titleEn: string;
  category: string;
  inputType: string;
  cadence: string;
  targetJson?: Record<string, number> | null;
  unit?: string | null;
  minLevel?: string;
  sortOrder?: number;
  autoSource?: string | null;
}

