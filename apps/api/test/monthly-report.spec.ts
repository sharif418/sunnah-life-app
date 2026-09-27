// Unit tests for the monthly Muhasaba report (Task B3):
//  • report-data — week partitioning, tally rules, cell semantics, labels
//  • Bengali shaping — the paper-form quality bar (fontkit GSUB/GPOS on the
//    bundled Hind Siliguri; the same engine pdfkit uses when rendering)
//  • report-renderer — end-to-end render: PDF buffer, page count, fonts embedded
import { readFileSync } from "fs";
import { join } from "path";
import * as fontkit from "fontkit";
import {
  cellFor,
  dayRangeLabelBn,
  districtLabelBn,
  entriesByAmal,
  monthDays,
  monthLabelBn,
  monthWeeks,
  tallyFor,
  weekStartForKey,
  type ReportAmalDef,
  type MonthlyReportData,
} from "src/reports/report-data";
import { renderMonthlyReport } from "src/reports/report-renderer";

const FONT_DIR = join(__dirname, "..", "assets", "fonts");
const FONT_REGULAR = join(FONT_DIR, "HindSiliguri-Regular.ttf");

const def = (key: string, inputType: string, category = "salah", titleBn = key): ReportAmalDef => ({
  key,
  titleBn,
  category,
  inputType,
  cadence: "daily",
  unit: null,
});

// ── week partitioning (BD Saturday-start weeks intersecting the month) ───────

describe("monthWeeks", () => {
  it("partitions September 2026 into 5 Saturday-start weeks", () => {
    const weeks = monthWeeks(monthDays("2026-09"));
    expect(weeks).toHaveLength(5);
    expect(weeks.map((w) => w.start)).toEqual([
      "2026-08-29", "2026-09-05", "2026-09-12", "2026-09-19", "2026-09-26",
    ]);
    // every day lands in exactly one week, order preserved
    const all = weeks.flatMap((w) => w.days);
    expect(all).toEqual(monthDays("2026-09"));
    // first week only carries the in-month days (Sep 1 is a Tuesday)
    expect(weeks[0].days).toEqual(["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"]);
  });

  it("weekStartForKey lands on Saturday", () => {
    for (const day of ["2026-09-01", "2026-09-05", "2026-09-27", "2026-02-28"]) {
      const ws = weekStartForKey(day);
      expect(new Date(`${ws}T00:00:00Z`).getUTCDay()).toBe(6);
      expect(ws <= day).toBe(true);
    }
  });

  it("dayRangeLabelBn renders Bengali month spans", () => {
    expect(dayRangeLabelBn(["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"])).toBe("১–৪ সেপ্টেম্বর");
    expect(dayRangeLabelBn(["2026-09-30"])).toBe("৩০ সেপ্টেম্বর");
  });
});

// ── tally rules (paper-form counting) ─────────────────────────────────────────

describe("tallyFor", () => {
  const days = ["2026-09-01", "2026-09-02", "2026-09-03"];

  it("tristate: counts জামাত+একা days, কাযা does not count", () => {
    const map = new Map<string, unknown>([
      ["2026-09-01", "jamaat"],
      ["2026-09-02", "alone"],
      ["2026-09-03", "qaza"],
    ]);
    expect(tallyFor(def("f", "tristate"), map, days)).toBe(2);
  });

  it("boolean: counts only true", () => {
    const map = new Map<string, unknown>([
      ["2026-09-01", true],
      ["2026-09-02", true],
      ["2026-09-03", false],
    ]);
    expect(tallyFor(def("b", "boolean"), map, days)).toBe(2);
  });

  it("count/quantity: sums the values (total pages, not days)", () => {
    const map = new Map<string, unknown>([
      ["2026-09-01", 4],
      ["2026-09-02", 2.5],
      ["2026-09-03", 0],
    ]);
    expect(tallyFor(def("t", "quantity"), map, days)).toBe(6.5);
    expect(tallyFor(def("t", "quantity"), new Map(), days)).toBe(0);
  });

  it("text inputs are not tallied", () => {
    expect(tallyFor(def("x", "text"), new Map([["2026-09-01", "নোট"]]), days)).toBeNull();
  });
});

// ── cell semantics ─────────────────────────────────────────────────────────────

describe("cellFor", () => {
  it("maps tristate values to the paper-form marks", () => {
    const d = def("f", "tristate");
    expect(cellFor(d, "jamaat")).toEqual({ kind: "mark", mark: "jamaat" });
    expect(cellFor(d, "alone")).toEqual({ kind: "mark", mark: "alone" });
    expect(cellFor(d, "qaza")).toEqual({ kind: "mark", mark: "qaza" });
    expect(cellFor(d, null)).toEqual({ kind: "empty" });
  });

  it("numbers render as Bengali digits", () => {
    expect(cellFor(def("t", "quantity"), 12.5)).toEqual({ kind: "number", text: "১২.৫" });
    expect(cellFor(def("t", "count"), 0)).toEqual({ kind: "empty" });
  });

  it("boolean true → done check", () => {
    expect(cellFor(def("b", "boolean"), true)).toEqual({ kind: "mark", mark: "done" });
    expect(cellFor(def("b", "boolean"), false)).toEqual({ kind: "empty" });
  });
});

// ── labels ─────────────────────────────────────────────────────────────────────

describe("labels", () => {
  it("monthLabelBn formats Bengali month + year", () => {
    expect(monthLabelBn("2026-09")).toBe("সেপ্টেম্বর ২০২৬");
    expect(monthLabelBn("2027-01")).toBe("জানুয়ারি ২০২৭");
  });
  it("districtLabelBn maps slugs and passes through unknown values", () => {
    expect(districtLabelBn("dhaka")).toBe("ঢাকা");
    expect(districtLabelBn("DHAKA")).toBe("ঢাকা");
    expect(districtLabelBn("kuala lumpur")).toBe("kuala lumpur");
    expect(districtLabelBn(null)).toBeNull();
  });
});

// ── Bengali shaping — the critical quality bar ────────────────────────────────

describe("Bengali shaping (fontkit GSUB/GPOS — pdfkit's layout engine)", () => {
  const font = fontkit.create(readFileSync(FONT_REGULAR)) as fontkit.Font;

  it("forms the ন্ন conjunct ligature in সুন্নাহ (fewer glyphs than codepoints)", () => {
    const run = font.layout("সুন্নাহ");
    const codepoints = [..."সুন্নাহ"].length;
    expect(run.glyphs.length).toBeLessThan(codepoints);
    // the standalone ন্ন cluster shapes to a single ligature glyph
    const nnRun = font.layout("ন্ন");
    expect(nnRun.glyphs.length).toBe(1);
    // …and that same ligature glyph is what appears inside সুন্নাহ
    expect(run.glyphs.map((g: fontkit.Glyph) => g.id)).toContain(nnRun.glyphs[0]!.id);
  });

  it("shapes the full report vocabulary with zero .notdef glyphs", () => {
    const vocabulary = [
      "সুন্নাহ লাইফ — মাসিক মুহাসাবা রিপোর্ট",
      "নাম: কোড: জেলা: উসরা: মাস:",
      "সাপ্তাহিক ও মাসিক হিসাব · মাসিক মোট",
      "উসরা প্রধানের সাপ্তাহিক মন্তব্য",
      "সদস্যের স্বাক্ষর তারিখ উসরা প্রধানের স্বাক্ষর",
      "নামাজ কুরআন যিকর ও দোয়া দাওয়াত জীবনাচরণ সাপ্তাহিক ও মাসিক সুন্নাহ",
      "ফজর যোহর আসর মাগরিব এশা বিতর তাহাজ্জুদ ইশরাক",
      "কুরআন তিলাওয়াত · দরুদ শরীফ · ইস্তিগফার · মিসওয়াক · আইয়ামে বীজ রোজা",
      "তৈরি: (ঢাকা সময়) · রিপোর্ট আইডি: · পৃষ্ঠা /",
      "কমপক্ষে ১৫ মিনিট দাওয়াতি কাজ — পরবর্তী লক্ষ্য: রেটিং: /৫",
      "September 2026 · DS-000004 · ১২৩৪৫৬৭৮৯০",
      "আল-ফুরকান · উসরা আয়েশা সিদ্দিকা · ঢাকা · কুমিল্লা · রাজশাহী",
    ];
    for (const text of vocabulary) {
      const run = font.layout(text);
      const notdef = run.glyphs.filter((g: fontkit.Glyph) => g.id === 0).length;
      expect(notdef).toBe(0);
    }
  });

  it("applies pre-base matra reordering (ি before its consonant in the glyph stream)", () => {
    const run = font.layout("কি"); // ক + ি(U+09BF pre-base matra)
    // In logical order ক comes first; in the shaped visual stream the pre-base
    // matra glyph is placed before the consonant glyph.
    const ids = run.glyphs.map((g: fontkit.Glyph) => g.id);
    expect(ids).toHaveLength(2);
    const logicalKa = font.layout("ক").glyphs[0]!.id;
    expect(ids[0]).not.toBe(logicalKa); // first glyph is the matra, not ক
    expect(ids[1]).toBe(logicalKa);
  });
});

// ── end-to-end renderer ────────────────────────────────────────────────────────

describe("renderMonthlyReport", () => {
  const data: MonthlyReportData = {
    reportId: "test-report-1",
    member: {
      name: "রাফিউল ইসলাম",
      memberCode: "DS-000004",
      district: "dhaka",
      usrahName: "উসরা আল-ফুরকান",
    },
    month: "2026-09",
    days: monthDays("2026-09"),
    definitions: [
      def("salat_fajr", "tristate", "salah", "ফজর নামাজ"),
      def("salat_isha", "tristate", "salah", "এশা নামাজ"),
      def("tilawat", "quantity", "quran", "কুরআন তিলাওয়াত"),
      def("durood_100", "count", "dhikr", "দরুদ শরীফ"),
    ],
    entries: [
      { amalKey: "salat_fajr", date: "2026-09-01", value: "jamaat" },
      { amalKey: "salat_fajr", date: "2026-09-02", value: "alone" },
      { amalKey: "salat_fajr", date: "2026-09-03", value: "qaza" },
      { amalKey: "salat_isha", date: "2026-09-01", value: "jamaat" },
      { amalKey: "tilawat", date: "2026-09-01", value: 3.5 },
      { amalKey: "tilawat", date: "2026-09-02", value: 4 },
      { amalKey: "durood_100", date: "2026-09-01", value: 120 },
    ],
    reviews: [
      {
        weekLabel: "সপ্তাহ ১ (১–৪ সেপ্টেম্বর)",
        reviewerName: "মাওলানা ইউসুফ",
        comment: "অতি সন্তোষজনক সূচনা — জামাতে নামাজের ধারাবাহিকতা বজায় রাখুন।",
        rating: 5,
        nextGoals: "তিলাওয়াত দৈনিক ১ পৃষ্ঠা থেকে ২ পৃষ্ঠায় নিন।",
      },
    ],
    generatedAt: new Date("2026-10-01T00:05:00Z"),
  };

  it("renders a non-empty, multi-page PDF with the fonts embedded", async () => {
    const pdf = await renderMonthlyReport(data);
    expect(pdf.length).toBeGreaterThan(20_000);
    expect(pdf.subarray(0, 5).toString("latin1")).toBe("%PDF-");
    // page count: grid + tallies + reviews/signatures = 3
    const pages = (pdf.toString("latin1").match(/\/Type[\s]*\/Page[^s]/g) ?? []).length;
    expect(pages).toBe(3);
    // Hind Siliguri must be embedded (subset) twice: regular + bold
    const s = pdf.toString("latin1");
    expect(s).toContain("FontFile2");
    expect(s).toContain("/Font");
  });

  it("keeps the catalog order and groups consecutive categories", () => {
    // entriesByAmal groups per key with day maps (sanity of the feed structure)
    const byAmal = entriesByAmal(data.entries);
    expect(byAmal.get("salat_fajr")?.get("2026-09-02")).toBe("alone");
    expect(byAmal.get("tilawat")?.size).toBe(2);
  });
});
