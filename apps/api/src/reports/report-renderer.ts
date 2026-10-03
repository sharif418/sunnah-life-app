// ─────────────────────────────────────────────────────────────────────────────
// Monthly Muhasaba report — the PDF renderer (the paper form, digital).
//
// BENGALI TEXT SHAPING — the critical bit, verified end-to-end:
//   pdfkit delegates text shaping to fontkit's OpenType layout engine (the
//   same class of engine as HarfBuzz: GSUB/GPOS with the Universal Shaping
//   Engine covering Bengali). Verified on this repo's Hind Siliguri build:
//     • "সুন্নাহ" (7 chars) → 5 glyphs — the ন্ন conjunct ligature is formed;
//     • "ক্ত"/"স্ট" (3 chars) → 1 ligature glyph each;
//     • pre-base matra reordering (ি before its consonant) applies;
//     • zero .notdef glyphs across the whole report vocabulary;
//     • pdfkit applies fontkit's GPOS xOffset/yOffset per glyph (mark anchoring).
//   Proven programmatically in test/monthly-report.spec.ts — visual sign-off
//   (conjuncts look right to a human reader) still belongs to a reviewer.
//
// PAPER-FORM MARK CONVENTION (salat cells), drawn as vector strokes — Hind
// Siliguri has no ✔/□ codepoints, and hand-drawn marks are what the physical
// diary uses:
//   ✔  জামাত    ⁄  একা    □  কাযা    (blank) বাদ/এন্ট্রি নেই
//
// All text is drawn with manual positioning at an explicit BASELINE
// (`baseline: "alphabetic"` — pdfkit's default y is the TOP of the line box,
// which drew every label ~one line low, under the next row's fill, until
// 2026-10-03) and `lineBreak: false` — no wrapper, no pdfkit alignment;
// widths/centring are computed with widthOfString (which itself runs the
// shaped layout).
// ─────────────────────────────────────────────────────────────────────────────

import PDFDocument from "pdfkit";
import { join } from "path";
import { AMAL_CATEGORY_LABELS_BN } from "../shared/domain";
import { BD_TZ_HOURS } from "../shared/amal";
import { formatTimeBn, gregorianBn, toBn } from "../shared/calendars";
import {
  bdDateKey,
  cellFor,
  cellForDay,
  dayRangeLabelBn,
  districtLabelBn,
  entriesByAmal,
  monthLabelBn,
  monthLabelEn,
  monthWeeks,
  resolvePaperLayout,
  tallyFor,
  type CellMark,
  type MonthlyReportData,
  type ReportAmalDef,
  type ResolvedPaperGroup,
} from "./report-data";

// Fonts resolve identically from src/ (bun run / jest) and dist/ (node):
//   src/reports/../../assets  and  dist/reports/../../assets  both → apps/api/assets.
const FONT_DIR = join(__dirname, "..", "..", "assets", "fonts");
const FONT_REGULAR = join(FONT_DIR, "HindSiliguri-Regular.ttf");
const FONT_BOLD = join(FONT_DIR, "HindSiliguri-Bold.ttf");

// A4 landscape.
const PAGE_W = 841.89;
const PAGE_H = 595.28;
const MARGIN = 24;
const USABLE_W = PAGE_W - 2 * MARGIN;

// Design tokens (repo palette: deep green / gold / cream).
const GREEN = "#1F4D3D";
const GREEN_LIGHT = "#E7EFE9";
const GOLD = "#C99A3B";
const LINE = "#B9C6BE";
const INK = "#20302A";
const MUTED = "#5B6B63";
const MISS = "#B93527";

const NAME_COL_W = 138;

/** Render the full monthly report PDF and resolve with the buffered bytes. */
export function renderMonthlyReport(data: MonthlyReportData): Promise<Buffer> {
  const doc = new PDFDocument({
    size: [PAGE_W, PAGE_H],
    margins: { top: MARGIN, bottom: MARGIN, left: MARGIN, right: MARGIN },
    bufferPages: true, // keep pages switchable for the footer pass
    info: {
      Title: `মাসিক মুহাসাবা রিপোর্ট — ${monthLabelBn(data.month)}`,
      Author: "Sunnah Life",
      Subject: `Muhasaba monthly report ${data.month} (${data.member.memberCode ?? data.member.name})`,
    },
  });
  const chunks: Buffer[] = [];
  doc.on("data", (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on("end", () => resolve(Buffer.concat(chunks))));

  doc.registerFont("bn", FONT_REGULAR);
  doc.registerFont("bn-bold", FONT_BOLD);

  if (data.paperLayout?.length) {
    // Page 1 mirrors the paper monthly sheet (its groups, rows and order);
    // whatever the app tracks beyond the paper follows on its own page.
    const { groups, extras } = resolvePaperLayout(data.paperLayout, data.definitions);
    drawPaperSheet(doc, data, groups);
    if (extras.length) {
      doc.addPage();
      doc.fillColor(GREEN).font("bn-bold").fontSize(12);
      drawAt(doc, "অ্যাপের অতিরিক্ত আমল (কাগজের ডায়েরির বাইরে)", MARGIN, MARGIN + 12);
      drawGrid(doc, data, extras, MARGIN + 24);
    }
  } else {
    drawHeader(doc, data);
    drawLegend(doc);
    drawGrid(doc, data, data.definitions, MARGIN + 80);
  }

  // Next page: the weekly/monthly tally table.
  doc.addPage();
  drawTallies(doc, data);

  // Page 3: reviewer comments + signature lines (the paper form's back
  // page). ensureSpace keeps pathological months from breaking signatures.
  doc.addPage();
  let y = drawReviews(doc, data, MARGIN + 12);
  drawSignatures(doc, y);

  drawFooters(doc, data);
  doc.end();
  return done;
}

// ── page 1: header + the 31-column day grid ──────────────────────────────────

function drawHeader(doc: PDFKit.PDFDocument, data: MonthlyReportData): void {
  const cx = PAGE_W / 2;
  doc.fillColor(GREEN).font("bn-bold").fontSize(15);
  drawCentered(doc, "সুন্নাহ লাইফ — মাসিক মুহাসাবা রিপোর্ট", cx, MARGIN + 14);

  const bits = [
    `নাম: ${data.member.name}`,
    data.member.memberCode ? `কোড: ${data.member.memberCode}` : null,
    data.member.district ? `জেলা: ${districtLabelBn(data.member.district)}` : null,
    data.member.usrahName ? `উসরা: ${data.member.usrahName}` : null,
  ].filter((s): s is string => !!s);
  doc.fillColor(INK).font("bn").fontSize(9.5);
  drawCentered(doc, bits.join("  ·  "), cx, MARGIN + 36);

  doc.font("bn-bold").fontSize(10.5);
  drawCentered(doc, `মাস: ${monthLabelBn(data.month)}  (${monthLabelEn(data.month)})`, cx, MARGIN + 53);
}

function drawLegend(doc: PDFKit.PDFDocument): void {
  // Left: the paper-form mark legend with the vector-drawn marks.
  let x = MARGIN + 2;
  const cy = MARGIN + 70;

  doc.font("bn").fontSize(7.5).fillColor(MUTED);
  x = drawMark(doc, "jamaat", x, cy) + 3;
  x = drawAt(doc, "জামাত", x, cy) + 8;
  x = drawMark(doc, "alone", x, cy) + 3;
  x = drawAt(doc, "একা", x, cy) + 8;
  x = drawMark(doc, "qaza", x, cy) + 3;
  x = drawAt(doc, "কাযা", x, cy) + 8;
  x = drawMark(doc, "missed", x, cy) + 3;
  x = drawAt(doc, "অসম্পন্ন", x, cy) + 8;
  drawAt(doc, "· খালি ঘর = এখনো সময় হয়নি / প্রযোজ্য নয়", x, cy);

  // Right: numeric-cell hint.
  doc.font("bn").fontSize(7).fillColor(MUTED);
  const hint = "সংখ্যার ঘর = সেদিনের পরিমাণ (পৃষ্ঠা/টি)";
  drawAt(doc, hint, PAGE_W - MARGIN - doc.widthOfString(hint) - 2, cy);
}

function drawGrid(doc: PDFKit.PDFDocument, data: MonthlyReportData, defs: ReportAmalDef[], gridTop: number): void {
  const days = data.days;
  const dayColW = (USABLE_W - NAME_COL_W) / days.length;
  const todayKey = bdDateKey(data.generatedAt);

  const groups = groupByCategory(defs);
  const byAmal = entriesByAmal(data.entries);

  // ── day header row (Friday columns gold — the weekly-cadence anchor) ────────
  let y = gridTop;
  const headerH = 13;
  drawCellBox(doc, MARGIN, y, NAME_COL_W, headerH, GREEN);
  doc.font("bn-bold").fontSize(7.5).fillColor("#FFFFFF");
  drawCentered(doc, "আমল", MARGIN + NAME_COL_W / 2, y + 8);

  days.forEach((day, i) => {
    const x = MARGIN + NAME_COL_W + i * dayColW;
    const dow = new Date(`${day}T00:00:00Z`).getUTCDay();
    drawCellBox(doc, x, y, dayColW, headerH, dow === 5 ? GOLD : GREEN);
    doc.font("bn-bold").fontSize(7.5).fillColor("#FFFFFF");
    drawCentered(doc, toBn(i + 1), x + dayColW / 2, y + 8);
  });
  y += headerH;

  // ── rows ──────────────────────────────────────────────────────────────────
  const CAT_H = 12;
  const ROW_H = 11.6;

  for (const group of groups) {
    // category header row
    drawCellBox(doc, MARGIN, y, USABLE_W, CAT_H, GREEN_LIGHT);
    doc.font("bn-bold").fontSize(8).fillColor(GREEN);
    drawAt(doc, categoryLabel(group.category), MARGIN + 4, y + 8);
    y += CAT_H;

    for (const def of group.defs) {
      drawCellBox(doc, MARGIN, y, NAME_COL_W, ROW_H, "#FFFFFF");
      doc.font("bn").fontSize(7.2).fillColor(INK);
      drawAt(doc, fitText(doc, def.titleBn, NAME_COL_W - 8), MARGIN + 4, y + 7.8);

      const daysMap = byAmal.get(def.key) ?? new Map<string, unknown>();
      days.forEach((day, i) => {
        const x = MARGIN + NAME_COL_W + i * dayColW;
        drawCellBox(doc, x, y, dayColW, ROW_H, "#FFFFFF");
        drawCellContent(doc, cellForDay(def, daysMap.get(day), day, todayKey, data.member.joinedOn), x, y, dayColW, ROW_H);
      });
      y += ROW_H;
    }
  }

  // closing edge of the grid
  doc.moveTo(MARGIN, y).lineTo(PAGE_W - MARGIN, y).lineWidth(0.7).strokeColor(LINE).stroke();
}

// ── page 1 (paper layout): the paper monthly sheet, row for row ─────────────

const PAPER_GROUP_W = 76;
const PAPER_LABEL_W = 160;

/**
 * "…… মাসের মুহাসাবা রিপোর্ট" exactly as the paper sheet: বিভাগ (spanning
 * its rows) · আমলের বিষয় · one column per day, then the
 * দায়িত্বশীলের স্বাক্ষর ও তারিখ / মন্তব্য line. Row height adapts so every
 * paper row fits on ONE page (the old 35-row grid ran past the page edge).
 */
function drawPaperSheet(doc: PDFKit.PDFDocument, data: MonthlyReportData, groups: ResolvedPaperGroup[]): void {
  const cx = PAGE_W / 2;
  doc.fillColor(GREEN).font("bn-bold").fontSize(14);
  drawCentered(doc, `${monthLabelBn(data.month)} মাসের মুহাসাবা রিপোর্ট`, cx, MARGIN + 12);

  const bits = [
    `নাম: ${data.member.name}`,
    data.member.memberCode ? `সদস্য আইডি: ${data.member.memberCode}` : null,
    data.member.district ? `জেলা: ${districtLabelBn(data.member.district)}` : null,
    data.member.usrahName ? `উসরা: ${data.member.usrahName}` : null,
  ].filter((s): s is string => !!s);
  doc.fillColor(INK).font("bn").fontSize(9);
  drawCentered(doc, bits.join("  ·  "), cx, MARGIN + 29);

  // mark legend
  let lx = MARGIN + 2;
  const ly = MARGIN + 44;
  doc.font("bn").fontSize(7.5).fillColor(MUTED);
  lx = drawMark(doc, "jamaat", lx, ly) + 3;
  lx = drawAt(doc, "জামাতে / সম্পন্ন", lx, ly + 2.5) + 9;
  lx = drawMark(doc, "alone", lx, ly) + 3;
  lx = drawAt(doc, "একাকী", lx, ly + 2.5) + 9;
  lx = drawMark(doc, "qaza", lx, ly) + 3;
  lx = drawAt(doc, "কাযা", lx, ly + 2.5) + 9;
  lx = drawMark(doc, "missed", lx, ly) + 3;
  lx = drawAt(doc, "অসম্পন্ন", lx, ly + 2.5) + 9;
  drawAt(doc, "· সংখ্যা = পরিমাণ (মিনিট/পৃষ্ঠা) · খালি = এখনো সময় হয়নি বা প্রযোজ্য নয়", lx, ly + 2.5);

  const days = data.days;
  const todayKey = bdDateKey(data.generatedAt);
  const byAmal = entriesByAmal(data.entries);
  const dayX0 = MARGIN + PAPER_GROUP_W + PAPER_LABEL_W;
  const dayW = (USABLE_W - PAPER_GROUP_W - PAPER_LABEL_W) / days.length;

  let y = MARGIN + 54;
  const HEAD_H = 16;
  drawCellBox(doc, MARGIN, y, PAPER_GROUP_W, HEAD_H, GREEN);
  drawCellBox(doc, MARGIN + PAPER_GROUP_W, y, PAPER_LABEL_W, HEAD_H, GREEN);
  doc.font("bn-bold").fontSize(8).fillColor("#FFFFFF");
  drawCentered(doc, "বিভাগ", MARGIN + PAPER_GROUP_W / 2, y + 10.5);
  drawCentered(doc, "আমলের বিষয়", MARGIN + PAPER_GROUP_W + PAPER_LABEL_W / 2, y + 10.5);
  days.forEach((day, i) => {
    const x = dayX0 + i * dayW;
    const dow = new Date(`${day}T00:00:00Z`).getUTCDay();
    drawCellBox(doc, x, y, dayW, HEAD_H, dow === 5 ? GOLD : GREEN);
    doc.font("bn-bold").fontSize(7.5).fillColor("#FFFFFF");
    drawCentered(doc, toBn(i + 1), x + dayW / 2, y + 10.5);
  });
  y += HEAD_H;

  // rows share what is left above the sign-off line and the footer
  const rowCount = groups.reduce((n, g) => n + g.rows.length, 0);
  const bottom = PAGE_H - MARGIN - 16 - 30;
  const ROW_H = Math.min(21, (bottom - y) / Math.max(rowCount, 1));

  for (const group of groups) {
    const groupH = ROW_H * group.rows.length;
    drawCellBox(doc, MARGIN, y, PAPER_GROUP_W, groupH, GREEN_LIGHT);
    doc.font("bn-bold").fontSize(7.6);
    const title = wrapBn(doc, group.groupBn, PAPER_GROUP_W - 8, 3);
    // (the group's noteBn is not printed: it uses ✔/□, which Hind Siliguri
    // lacks — the vector-drawn legend above the grid explains the marks)
    let ty = y + (groupH - title.length * 9.5) / 2 + 7.5;
    doc.fillColor(GREEN);
    for (const line of title) {
      drawCentered(doc, line, MARGIN + PAPER_GROUP_W / 2, ty);
      ty += 9.5;
    }

    for (const row of group.rows) {
      drawCellBox(doc, MARGIN + PAPER_GROUP_W, y, PAPER_LABEL_W, ROW_H, "#FFFFFF");
      doc.font("bn").fontSize(7.2).fillColor(INK);
      const lines = wrapBn(doc, row.labelBn, PAPER_LABEL_W - 8, ROW_H >= 18 ? 2 : 1);
      const lineH = 8.6;
      let by = y + (ROW_H - lines.length * lineH) / 2 + 6.6;
      for (const line of lines) {
        drawAt(doc, line, MARGIN + PAPER_GROUP_W + 4, by);
        by += lineH;
      }

      const primary = row.defs[0];
      days.forEach((day, i) => {
        const x = dayX0 + i * dayW;
        drawCellBox(doc, x, y, dayW, ROW_H, "#FFFFFF");
        // the first of the row's amal keys with a value fills the cell
        let cell: CellMark = { kind: "empty" };
        for (const def of row.defs) {
          cell = cellFor(def, byAmal.get(def.key)?.get(day));
          if (cell.kind !== "empty") break;
        }
        if (cell.kind === "empty") cell = cellForDay(primary, undefined, day, todayKey, data.member.joinedOn);
        drawCellContent(doc, cell, x, y, dayW, ROW_H);
      });
      y += ROW_H;
    }
  }

  // the paper sheet's own sign-off line
  const sy = y + 22;
  doc.font("bn-bold").fontSize(8.5).fillColor(INK);
  let sx = drawAt(doc, "দায়িত্বশীলের স্বাক্ষর ও তারিখ :", MARGIN, sy) + 6;
  doc.moveTo(sx, sy + 2).lineTo(sx + 170, sy + 2).lineWidth(0.6).strokeColor(LINE).stroke();
  sx = MARGIN + USABLE_W / 2;
  sx = drawAt(doc, "মন্তব্য:", sx, sy) + 6;
  doc.moveTo(sx, sy + 2).lineTo(PAGE_W - MARGIN, sy + 2).lineWidth(0.6).strokeColor(LINE).stroke();
}

function drawCellContent(doc: PDFKit.PDFDocument, cell: CellMark, x: number, y: number, w: number, h: number): void {
  if (cell.kind === "empty") return;
  if (cell.kind === "mark") {
    drawMark(doc, cell.mark, x + w / 2, y + h / 2 + 1);
    return;
  }
  doc.font("bn").fontSize(7).fillColor(INK);
  drawCentered(doc, cell.text, x + w / 2, y + h / 2 + 2.4);
}

/** Vector-drawn paper-form marks. Returns the x after the mark. */
function drawMark(
  doc: PDFKit.PDFDocument,
  mark: "jamaat" | "alone" | "qaza" | "done" | "missed",
  cx: number,
  cy: number
): number {
  doc.save();
  doc.lineWidth(1.1).lineCap("round");
  switch (mark) {
    case "jamaat":
    case "done": // ✔ check — জামাত / boolean done
      doc.strokeColor(GREEN);
      doc.moveTo(cx - 2.6, cy + 0.3).lineTo(cx - 0.8, cy + 2.2).lineTo(cx + 2.9, cy - 2.5).stroke();
      return cx + 4.5;
    case "alone": // ⁄ slash — একা
      doc.strokeColor(INK);
      doc.moveTo(cx - 1.5, cy + 2.7).lineTo(cx + 1.5, cy - 2.7).stroke();
      return cx + 3;
    case "qaza": // □ empty square — কাযা
      doc.strokeColor("#8A6D1F");
      doc.rect(cx - 2.3, cy - 2.3, 4.6, 4.6).stroke();
      return cx + 4.5;
    case "missed": // ✗ cross — অসম্পন্ন (paper instruction ১)
      doc.strokeColor(MISS);
      doc.moveTo(cx - 2.1, cy - 2.1).lineTo(cx + 2.1, cy + 2.1).stroke();
      doc.moveTo(cx - 2.1, cy + 2.1).lineTo(cx + 2.1, cy - 2.1).stroke();
      return cx + 4.5;
  }
}

// ── page 2: weekly + monthly tallies (returns final y) ──────────────────────

function drawTallies(doc: PDFKit.PDFDocument, data: MonthlyReportData): number {
  const weeks = monthWeeks(data.days);
  const byAmal = entriesByAmal(data.entries);

  const nameW = 170;
  const totalW = 96;
  const weekW = (USABLE_W - nameW - totalW) / weeks.length;

  let y = MARGIN + 12;
  doc.font("bn-bold").fontSize(12).fillColor(GREEN);
  drawAt(doc, "সাপ্তাহিক ও মাসিক হিসাব", MARGIN, y);
  y += 20;

  // header row
  drawCellBox(doc, MARGIN, y, nameW, 14, GREEN);
  doc.font("bn-bold").fontSize(8).fillColor("#FFFFFF");
  drawCentered(doc, "আমল", MARGIN + nameW / 2, y + 9.5);

  weeks.forEach((week, i) => {
    const x = MARGIN + nameW + i * weekW;
    drawCellBox(doc, x, y, weekW, 14, GREEN);
    doc.font("bn-bold").fontSize(7.5).fillColor("#FFFFFF");
    drawCentered(doc, `সপ্তাহ ${toBn(week.index)}`, x + weekW / 2, y + 9.5);
  });
  drawCellBox(doc, MARGIN + nameW + weeks.length * weekW, y, totalW, 14, GOLD);
  doc.font("bn-bold").fontSize(8).fillColor("#FFFFFF");
  drawCentered(doc, "মাসিক মোট", MARGIN + nameW + weeks.length * weekW + totalW / 2, y + 9.5);
  y += 14;

  // week range sub-label row (Bengali day spans)
  weeks.forEach((week, i) => {
    const x = MARGIN + nameW + i * weekW;
    doc.font("bn").fontSize(6.3).fillColor(MUTED);
    drawCentered(doc, dayRangeLabelBn(week.days), x + weekW / 2, y + 6.5);
  });
  y += 11;

  const ROW_H = 10.6;
  const CAT_H = 10.6;

  for (const group of groupByCategory(data.definitions)) {
    drawCellBox(doc, MARGIN, y, USABLE_W, CAT_H, GREEN_LIGHT);
    doc.font("bn-bold").fontSize(7).fillColor(GREEN);
    drawAt(doc, categoryLabel(group.category), MARGIN + 4, y + 7);
    y += CAT_H;

    for (const def of group.defs) {
      drawCellBox(doc, MARGIN, y, USABLE_W, ROW_H, "#FFFFFF");
      doc.font("bn").fontSize(6.8).fillColor(INK);
      drawAt(doc, fitText(doc, def.titleBn, nameW - 10), MARGIN + 4, y + 7);

      const daysMap = byAmal.get(def.key) ?? new Map<string, unknown>();
      let monthTotal: number | null = null;
      weeks.forEach((week, i) => {
        const value = tallyFor(def, daysMap, week.days);
        if (value === null) return;
        if (monthTotal === null) monthTotal = 0;
        monthTotal += value;
        if (value !== 0) {
          const x = MARGIN + nameW + i * weekW;
          doc.font("bn").fontSize(7).fillColor(INK);
          drawCentered(doc, toBn(value), x + weekW / 2, y + 7);
        }
      });
      if (monthTotal !== null && monthTotal !== 0) {
        const x = MARGIN + nameW + weeks.length * weekW;
        doc.font("bn-bold").fontSize(7.2).fillColor(GREEN);
        drawCentered(doc, toBn(Math.round(monthTotal * 10) / 10), x + totalW / 2, y + 7);
      }
      y += ROW_H;
    }
  }
  return y + 6;
}

// ── page 2 (flow): reviewer comments ─────────────────────────────────────────

function drawReviews(doc: PDFKit.PDFDocument, data: MonthlyReportData, yStart: number): number {
  let y = ensureSpace(doc, yStart + 18, 60);
  doc.font("bn-bold").fontSize(12).fillColor(GREEN);
  drawAt(doc, "উসরা প্রধানের সাপ্তাহিক মন্তব্য", MARGIN, y);
  y += 16;

  const withContent = data.reviews.filter((r) => (r.comment ?? "").trim() || (r.nextGoals ?? "").trim());
  if (!withContent.length) {
    doc.font("bn").fontSize(8).fillColor(MUTED);
    drawAt(doc, "এই মাসে কোনো রিভিউ মন্তব্য জমা হয়নি।", MARGIN, y + 9);
    return y + 22;
  }

  for (const review of withContent) {
    y = ensureSpace(doc, y, 44);
    doc.font("bn-bold").fontSize(8.2).fillColor(INK);
    const by = review.reviewerName ? ` — ${review.reviewerName}` : "";
    const rating = review.rating != null ? ` (রেটিং: ${toBn(review.rating)}/৫)` : "";
    drawAt(doc, `${review.weekLabel}${by}${rating}`, MARGIN, y + 8);
    y += 13;

    doc.font("bn").fontSize(8).fillColor(INK);
    for (const line of wrapBn(doc, review.comment ?? "", USABLE_W - 8, 3)) {
      y = ensureSpace(doc, y, 30);
      drawAt(doc, line, MARGIN + 4, y + 8);
      y += 11;
    }
    if ((review.nextGoals ?? "").trim()) {
      doc.font("bn").fontSize(7.5).fillColor(MUTED);
      for (const line of wrapBn(doc, `পরবর্তী লক্ষ্য: ${review.nextGoals}`, USABLE_W - 8, 2)) {
        y = ensureSpace(doc, y, 28);
        drawAt(doc, line, MARGIN + 4, y + 7.5);
        y += 10.5;
      }
    }
    y += 6;
  }
  return y + 10;
}

// ── page 2 (flow): signature lines ───────────────────────────────────────────

function drawSignatures(doc: PDFKit.PDFDocument, yStart: number): number {
  const y = ensureSpace(doc, yStart + 46, 72);
  const lineY = y + 30;
  const colW = (USABLE_W - 40) / 2;

  signatureBlock(doc, MARGIN, y, colW, lineY, "সদস্যের স্বাক্ষর", "তারিখ");
  signatureBlock(doc, MARGIN + colW + 40, y, colW, lineY, "উসরা প্রধানের স্বাক্ষর", "তারিখ");
  return lineY + 20;
}

function signatureBlock(
  doc: PDFKit.PDFDocument,
  x: number,
  top: number,
  w: number,
  lineY: number,
  label: string,
  dateLabel: string
): void {
  doc.font("bn").fontSize(8.5).fillColor(INK);
  const labelW = doc.widthOfString(label);
  drawAt(doc, label, x, top);
  const dateX = x + w - 150;
  drawAt(doc, dateLabel, dateX, top);

  doc.moveTo(x + labelW + 10, lineY).lineTo(x + w - 170, lineY)
    .lineWidth(0.8).strokeColor(INK).stroke();
  doc.moveTo(dateX + doc.widthOfString(dateLabel) + 10, lineY).lineTo(x + w, lineY)
    .lineWidth(0.8).strokeColor(INK).stroke();
}

// ── shared drawing helpers ────────────────────────────────────────────────────

/** Filled cell + hairline border (the paper form's ruled grid). */
function drawCellBox(
  doc: PDFKit.PDFDocument,
  x: number,
  y: number,
  w: number,
  h: number,
  fill: string,
  border = LINE
): void {
  doc.rect(x, y, w, h).lineWidth(0.6).fillAndStroke(fill, border);
}

/** Draw a single line at an explicit baseline (no wrapping, no alignment). */
function drawAt(doc: PDFKit.PDFDocument, s: string, x: number, baseline: number): number {
  doc.text(s, x, baseline, { lineBreak: false, baseline: "alphabetic" });
  return x + doc.widthOfString(s);
}

/** Draw centered around cx (manual centring via the shaped width). */
function drawCentered(doc: PDFKit.PDFDocument, s: string, cx: number, baseline: number): void {
  doc.text(s, cx - doc.widthOfString(s) / 2, baseline, { lineBreak: false, baseline: "alphabetic" });
}

/** Start a new page when `endY` can't fit; returns the effective y to use. */
function ensureSpace(doc: PDFKit.PDFDocument, endY: number, _need: number): number {
  if (endY > PAGE_H - MARGIN - 16) {
    doc.addPage();
    return MARGIN + 12;
  }
  return endY;
}

/**
 * Truncate to `maxW` on grapheme-cluster boundaries (a Bengali cluster =
 * base char + combining marks — never split a matra from its consonant).
 */
function fitText(doc: PDFKit.PDFDocument, s: string, maxW: number): string {
  if (doc.widthOfString(s) <= maxW) return s;
  const clusters = s.match(/\P{M}\p{M}*/gu) ?? [s];
  let out = "";
  for (const c of clusters) {
    if (doc.widthOfString(`${out}${c}…`) > maxW) break;
    out += c;
  }
  return `${out}…`;
}

/** Greedy word wrap measured with the CURRENT font/size (shaped widths). */
function wrapBn(doc: PDFKit.PDFDocument, s: string, maxW: number, maxLines: number): string[] {
  const words = s.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (doc.widthOfString(candidate) <= maxW || !line) {
      line = candidate;
    } else {
      lines.push(line);
      line = word;
      if (lines.length === maxLines) break;
    }
  }
  if (lines.length < maxLines && line) lines.push(line);
  if (lines.length === maxLines && words.join(" ").length > lines.join(" ").length) {
    let last = lines[maxLines - 1];
    while (doc.widthOfString(`${last}…`) > maxW && last.includes(" ")) {
      last = last.slice(0, last.lastIndexOf(" "));
    }
    lines[maxLines - 1] = `${last}…`;
  }
  return lines;
}

function groupByCategory(defs: ReportAmalDef[]): { category: string; defs: ReportAmalDef[] }[] {
  const groups: { category: string; defs: ReportAmalDef[] }[] = [];
  for (const def of defs) {
    const last = groups[groups.length - 1];
    if (last && last.category === def.category) last.defs.push(def);
    else groups.push({ category: def.category, defs: [def] });
  }
  return groups;
}

function categoryLabel(category: string): string {
  return AMAL_CATEGORY_LABELS_BN[category as keyof typeof AMAL_CATEGORY_LABELS_BN] ?? category;
}

/** Footer on every page: generated stamp + report id + page number. */
function drawFooters(doc: PDFKit.PDFDocument, data: MonthlyReportData): void {
  const dhaka = new Date(data.generatedAt.getTime() + BD_TZ_HOURS * 3_600_000);
  const minutes = dhaka.getUTCHours() * 60 + dhaka.getUTCMinutes();
  const stamp = `${gregorianBn(dhaka)}, ${formatTimeBn(minutes)} (ঢাকা সময়)`;

  const range = doc.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i += 1) {
    doc.switchToPage(i);
    const y = PAGE_H - MARGIN + 6;
    doc.font("bn").fontSize(6.8).fillColor(MUTED);
    drawAt(doc, `তৈরি: ${stamp}  ·  রিপোর্ট আইডি: ${data.reportId}`, MARGIN, y);
    const label = `পৃষ্ঠা ${toBn(i + 1)}/${toBn(range.count)}`;
    drawAt(doc, label, PAGE_W - MARGIN - doc.widthOfString(label), y);
  }
}
