// ─────────────────────────────────────────────────────────────────────────────
// Monthly Muhasaba report — pure data shaping (no I/O, no PDF).
//
// Everything here is unit-testable: week partitioning (BD Saturday-start
// weeks intersecting the month), the per-amal tally rules and the cell-value
// map the renderer draws. The paper-form conventions are documented inline.
// ─────────────────────────────────────────────────────────────────────────────

import { addDays, GREG_MONTHS_BN, toBn } from "../shared/calendars";

/** The 31-column grid's amal row shape (catalog order preserved by caller). */
export interface ReportAmalDef {
  key: string;
  titleBn: string;
  category: string;
  inputType: string; // tristate | boolean | count | quantity | text
  cadence: string;
  unit: string | null;
}

export interface ReportEntry {
  amalKey: string;
  date: string; // YYYY-MM-DD
  value: unknown; // "jamaat"|"alone"|"qaza" | boolean | number | string
}

export interface ReportWeekComment {
  weekLabel: string; // e.g. "সপ্তাহ ১ (০১–০৫ সেপ্টেম্বর)"
  reviewerName: string | null;
  comment: string | null;
  rating: number | null;
  nextGoals: string | null;
}

export interface MonthlyReportData {
  reportId: string;
  member: {
    name: string;
    memberCode: string | null;
    district: string | null;
    usrahName: string | null;
    /** BD date the account was created — no ✗ before the member existed. */
    joinedOn?: string;
  };
  month: string; // YYYY-MM
  days: string[]; // every YYYY-MM-DD of the month
  definitions: ReportAmalDef[]; // catalog order
  entries: ReportEntry[];
  reviews: ReportWeekComment[];
  generatedAt: Date;
  /** The paper monthly sheet's groups/rows (diary-instructions.json
   *  paperLayout). When present, page 1 mirrors the paper exactly and every
   *  other active amal moves to an "অতিরিক্ত আমল" page. */
  paperLayout?: PaperGroup[];
}

/** One row of the paper monthly sheet; the first key with a value fills it. */
export interface PaperRow {
  labelBn: string;
  amalKeys: string[];
}

export interface PaperGroup {
  groupBn: string;
  noteBn?: string;
  rows: PaperRow[];
}

/** A paper row bound to the active catalog definitions it reads from. */
export interface ResolvedPaperRow {
  labelBn: string;
  defs: ReportAmalDef[];
}

export interface ResolvedPaperGroup {
  groupBn: string;
  noteBn?: string;
  rows: ResolvedPaperRow[];
}

/**
 * Bind the paper layout to the ACTIVE definitions: rows whose keys are all
 * inactive drop out (and empty groups with them); every active definition
 * the paper does not name is returned as an extra, in catalog order.
 */
export function resolvePaperLayout(
  layout: PaperGroup[],
  defs: ReportAmalDef[]
): { groups: ResolvedPaperGroup[]; extras: ReportAmalDef[] } {
  const byKey = new Map(defs.map((d) => [d.key, d]));
  const used = new Set<string>();
  const groups: ResolvedPaperGroup[] = [];
  for (const g of layout) {
    const rows: ResolvedPaperRow[] = [];
    for (const r of g.rows) {
      const rowDefs = r.amalKeys.map((k) => byKey.get(k)).filter((d): d is ReportAmalDef => !!d);
      if (!rowDefs.length) continue;
      rowDefs.forEach((d) => used.add(d.key));
      rows.push({ labelBn: r.labelBn, defs: rowDefs });
    }
    if (rows.length) groups.push({ groupBn: g.groupBn, noteBn: g.noteBn, rows });
  }
  return { groups, extras: defs.filter((d) => !used.has(d.key)) };
}

/** Bangladesh calendar date (YYYY-MM-DD) of an instant. */
export function bdDateKey(at: Date): string {
  return new Date(at.getTime() + 6 * 3_600_000).toISOString().slice(0, 10);
}

/** One Saturday-start week that intersects the month. */
export interface MonthWeek {
  index: number; // 1..5
  start: string; // weekStart (Saturday) YYYY-MM-DD — may precede the month
  end: string; // start + 6
  days: string[]; // only the days that fall inside THIS month
}

/** Most recent Saturday on/before `key` (BD week convention — same as reviews). */
export function weekStartForKey(key: string): string {
  const [y, m, d] = key.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const dow = date.getUTCDay(); // 0 Sun … 6 Sat
  const diff = (dow + 1) % 7; // Sat → 0, Sun → 1, … Fri → 6
  return addDays(key, -diff);
}

/**
 * Partition the month's days into the Saturday-start weeks that intersect it
 * (up to 5). Each day belongs to exactly one week; weeks are numbered by
 * order of appearance, mirroring the paper form's "সপ্তাহ ১..৫" tally rows.
 */
export function monthWeeks(days: string[]): MonthWeek[] {
  const weeks: MonthWeek[] = [];
  for (const day of days) {
    const start = weekStartForKey(day);
    let week = weeks.find((w) => w.start === start);
    if (!week) {
      week = { index: weeks.length + 1, start, end: addDays(start, 6), days: [] };
      weeks.push(week);
    }
    week.days.push(day);
  }
  return weeks;
}

/** "সেপ্টেম্বর ২০২৬" for a YYYY-MM key. */
export function monthLabelBn(month: string): string {
  const [y, m] = month.split("-").map(Number);
  return `${GREG_MONTHS_BN[m - 1]} ${toBn(y)}`;
}

/** Gregorian (English) equivalent for the header, e.g. "September 2026". */
export function monthLabelEn(month: string): string {
  const [y, m] = month.split("-").map(Number);
  return `${new Date(Date.UTC(y, m - 1, 1)).toLocaleString("en-US", { month: "long" })} ${y}`;
}

/** Short Bengali range label "১২–১৮ সেপ্টেম্বর" for a week's in-month days. */
export function dayRangeLabelBn(days: string[]): string {
  if (!days.length) return "";
  const first = days[0];
  const last = days[days.length - 1];
  const [, m1, d1] = first.split("-").map(Number);
  const [, m2, d2] = last.split("-").map(Number);
  if (first === last) return `${toBn(d1)} ${GREG_MONTHS_BN[m1 - 1]}`;
  if (m1 === m2) return `${toBn(d1)}–${toBn(d2)} ${GREG_MONTHS_BN[m1 - 1]}`;
  return `${toBn(d1)} ${GREG_MONTHS_BN[m1 - 1]}–${toBn(d2)} ${GREG_MONTHS_BN[m2 - 1]}`;
}

// The 64 Bangladesh districts (slug → Bengali), same source as the web/mobile
// district pickers (apps/web/src/lib/cities.ts). Profile districts store the
// English slug; the report prints the Bengali label.
export const DISTRICT_LABELS_BN: Record<string, string> = {
  dhaka: "ঢাকা",
  gazipur: "গাজীপুর",
  narayanganj: "নারায়ণগঞ্জ",
  narsingdi: "নরসিংদী",
  manikganj: "মানিকগঞ্জ",
  munshiganj: "মুন্সিগঞ্জ",
  tangail: "টাঙ্গাইল",
  kishoreganj: "কিশোরগঞ্জ",
  faridpur: "ফরিদপুর",
  madaripur: "মাদারীপুর",
  shariatpur: "শরীয়তপুর",
  rajbari: "রাজবাড়ী",
  gopalganj: "গোপালগঞ্জ",
  chattogram: "চট্টগ্রাম",
  "cox's bazar": "কক্সবাজার",
  cumilla: "কুমিল্লা",
  brahmanbaria: "ব্রাহ্মণবাড়িয়া",
  noakhali: "নোয়াখালী",
  feni: "ফেনী",
  chandpur: "চাঁদপুর",
  lakshmipur: "লক্ষ্মীপুর",
  rangamati: "রাঙামাটি",
  khagrachhari: "খাগড়াছড়ি",
  bandarban: "বান্দরবান",
  sylhet: "সিলেট",
  habiganj: "হবিগঞ্জ",
  mymensingh: "ময়মনসিংহ",
  jamalpur: "জামালপুর",
  netrokona: "নেত্রকোণা",
  sherpur: "শেরপুর",
  rajshahi: "রাজশাহী",
  pabna: "পাবনা",
  bogura: "বগুড়া",
  joypurhat: "জয়পুরহাট",
  naogaon: "নওগাঁ",
  natore: "নাটোর",
  chapainawabganj: "চাঁপাইনবাবগঞ্জ",
  sirajganj: "সিরাজগঞ্জ",
  rangpur: "রংপুর",
  dinajpur: "দিনাজপুর",
  kurigram: "কুড়িগ্রাম",
  gaibandha: "গাইবান্ধা",
  thakurgaon: "ঠাকুরগাঁও",
  panchagarh: "পঞ্চগড়",
  nilphamari: "নীলফামারী",
  lalmonirhat: "লালমনিরহাট",
  khulna: "খুলনা",
  jashore: "যশোর",
  jhenaidah: "ঝিনাইদহ",
  chuadanga: "চুয়াডাঙ্গা",
  kushtia: "কুষ্টিয়া",
  magura: "মাগুরা",
  meherpur: "মেহেরপুর",
  bagerhat: "বাগেরহাট",
  satkhira: "সাতক্ষীরা",
  narail: "নড়াইল",
  barishal: "বরিশাল",
  bhola: "ভোলা",
  pirojpur: "পিরোজপুর",
  patuakhali: "পটুয়াখালী",
  barguna: "বরগুনা",
  jhalokati: "ঝালকাঠি",
};

/** Bengali district label for a profile slug (falls back to the raw value). */
export function districtLabelBn(district: string | null): string | null {
  if (!district) return null;
  return DISTRICT_LABELS_BN[district.toLowerCase()] ?? district;
}

// ── Cell semantics (paper-form conventions) ───────────────────────────────────
//
// Tri-state salat cells use the paper diary's mark convention:
//   ✔  জামাত  (drawn check)
//   ⁄  একা    (drawn slash)
//   □  কাযা   (drawn empty square)
//   (blank)   বাদ / no entry — the Ishraq day-lock means locked/empty days
//             simply have no rows in the DB; we render what exists.
// Count/quantity cells show the recorded number in Bengali digits; boolean
// cells show a ✔ when true. Weekly-cadence amals mark their due day only.
//   ✗  অসম্পন্ন — the paper's instruction ১: "অসম্পন্ন থাকলে ক্রস (✗) দিন".
//      Drawn on a PAST day the amal was due (daily, or the Friday of a
//      Friday amal) with nothing recorded; today and future days stay blank,
//      and flexible-day amals (any day of the week / ayyam al-beez) never ✗.

export type CellMark =
  | { kind: "mark"; mark: "jamaat" | "alone" | "qaza" | "done" | "missed" }
  | { kind: "number"; text: string }
  | { kind: "empty" };

/** Whether an amal is due on a given day (drives the ✗ for misses). */
export function isDueOn(def: ReportAmalDef, day: string): boolean {
  if (def.cadence === "daily") return true;
  if (def.cadence === "weekly:fri") {
    const [y, m, d] = day.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, d)).getUTCDay() === 5;
  }
  return false;
}

/** The cell for one row on one day, with ✗ for a past, due, unrecorded day. */
export function cellForDay(
  def: ReportAmalDef,
  value: unknown,
  day: string,
  todayKey: string,
  joinedOn = ""
): CellMark {
  const cell = cellFor(def, value);
  if (cell.kind !== "empty") return cell;
  if (day < todayKey && day >= joinedOn && isDueOn(def, day) && def.inputType !== "text") {
    return { kind: "mark", mark: "missed" };
  }
  return cell;
}

/** Map one entry value to its grid cell rendering. */
export function cellFor(def: ReportAmalDef, value: unknown): CellMark {
  if (value === null || value === undefined || value === "") return { kind: "empty" };
  switch (def.inputType) {
    case "tristate":
      if (value === "jamaat") return { kind: "mark", mark: "jamaat" };
      if (value === "alone") return { kind: "mark", mark: "alone" };
      if (value === "qaza") return { kind: "mark", mark: "qaza" };
      return { kind: "empty" };
    case "boolean":
      return value === true ? { kind: "mark", mark: "done" } : { kind: "empty" };
    case "count":
    case "quantity": {
      const n = typeof value === "number" ? value : Number(value);
      if (!isFinite(n) || n <= 0) return { kind: "empty" };
      return { kind: "number", text: toBn(Number.isInteger(n) ? String(n) : n.toFixed(1)) };
    }
    default:
      return { kind: "empty" };
  }
}

// ── Tally rules (weekly + monthly) ────────────────────────────────────────────
//
// Mirrors how the amal engine counts completions (amalPoints) with the paper
// form's quantity semantics:
//   • tristate / boolean → NUMBER OF DAYS completed (জামাত+একা count as done,
//     কাযা does not — same as amalPoints; boolean true counts)
//   • count / quantity    → SUM of the recorded values (total pages, total
//     durood, …) — the paper diary's tally row totals the quantity column.
// The monthly total applies the same rule over the whole month.

/** Tally one amal over a set of days. Returns null for non-tallied types. */
export function tallyFor(
  def: ReportAmalDef,
  entriesByDay: Map<string, unknown>, // date → value for THIS amalKey
  days: string[]
): number | null {
  if (def.inputType === "tristate" || def.inputType === "boolean") {
    let count = 0;
    for (const day of days) {
      const v = entriesByDay.get(day);
      if (def.inputType === "tristate" && (v === "jamaat" || v === "alone")) count++;
      else if (def.inputType === "boolean" && v === true) count++;
    }
    return count;
  }
  if (def.inputType === "count" || def.inputType === "quantity") {
    let sum = 0;
    let seen = false;
    for (const day of days) {
      const v = entriesByDay.get(day);
      const n = typeof v === "number" ? v : typeof v === "string" && v !== "" ? Number(v) : NaN;
      if (isFinite(n) && n > 0) {
        sum += n;
        seen = true;
      }
    }
    return seen ? Math.round(sum * 10) / 10 : 0;
  }
  return null; // text inputs are not tallied
}

/** Group raw entries into per-amalKey day→value maps. */
export function entriesByAmal(
  entries: ReportEntry[]
): Map<string, Map<string, unknown>> {
  const map = new Map<string, Map<string, unknown>>();
  for (const e of entries) {
    let days = map.get(e.amalKey);
    if (!days) {
      days = new Map<string, unknown>();
      map.set(e.amalKey, days);
    }
    days.set(e.date, e.value);
  }
  return map;
}

/** All days of the month (YYYY-MM) ascending. */
export function monthDays(month: string): string[] {
  const [y, m] = month.split("-").map(Number);
  const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return Array.from({ length: lastDay }, (_, i) => `${month}-${String(i + 1).padStart(2, "0")}`);
}
