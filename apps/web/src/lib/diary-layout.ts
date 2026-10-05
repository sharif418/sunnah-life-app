// The Foundation's paper muhasaba diary — group order, row labels and the
// back-cover নির্দেশনাবলী — read straight from packages/content (the same
// source the mobile app and the monthly PDF use), so the web diary can never
// drift from the printed form members are trained on.

import pack from "../../../../packages/content/diary-instructions.json";

export interface PaperRow {
  labelBn: string;
  amalKeys: string[];
}

export interface PaperGroup {
  groupBn: string;
  noteBn?: string;
  rows: PaperRow[];
}

export const PAPER_LAYOUT: PaperGroup[] = (pack as { paperLayout: PaperGroup[] }).paperLayout;

export const DIARY_INSTRUCTIONS: string[] = (pack as { instructions: { textBn: string }[] }).instructions.map(
  (i) => i.textBn
);

export const DIARY_COVER = {
  ar: (pack as { coverQuoteAr?: string }).coverQuoteAr ?? "",
  bn: (pack as { coverQuoteBn?: string }).coverQuoteBn ?? "",
};

/** Every catalog key that appears on the paper. */
export const PAPER_KEYS = new Set(PAPER_LAYOUT.flatMap((g) => g.rows.flatMap((r) => r.amalKeys)));
