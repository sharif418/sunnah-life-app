// CSV export helpers — client-side generation, UTF-8 BOM so Excel renders
// Bengali text correctly.

function escapeCell(v: string | number | null | undefined): string {
  const s = v === null || v === undefined ? "" : String(v);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function toCsv(headers: string[], rows: (string | number | null | undefined)[][]): string {
  const lines = [headers.map(escapeCell).join(","), ...rows.map((r) => r.map(escapeCell).join(","))];
  return "\uFEFF" + lines.join("\r\n");
}

export function downloadCsv(filename: string, csv: string): void {
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2_000);
}

export function downloadCsvSafe(filename: string, headers: string[], rows: (string | number | null | undefined)[][]): void {
  downloadCsv(filename, toCsv(headers, rows));
}

/**
 * Parse CSV text (Excel "CSV UTF-8" export or Google Sheets download) into
 * header → value rows. Handles the BOM, quoted cells with commas / newlines /
 * doubled quotes, CRLF, and skips blank lines.
 */
export function parseCsv(text: string): { headers: string[]; rows: Record<string, string>[] } {
  const src = text.replace(/^﻿/, "");
  const records: string[][] = [];
  let cell = "";
  let row: string[] = [];
  let quoted = false;
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"') {
        if (src[i + 1] === '"') {
          cell += '"';
          i++;
        } else quoted = false;
      } else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && src[i + 1] === "\n") i++;
      row.push(cell);
      records.push(row);
      row = [];
      cell = "";
    } else cell += ch;
  }
  if (cell !== "" || row.length) {
    row.push(cell);
    records.push(row);
  }
  const nonEmpty = records.filter((r) => r.some((c) => c.trim() !== ""));
  const [head = [], ...body] = nonEmpty;
  const headers = head.map((h) => h.trim());
  return {
    headers,
    rows: body.map((r) => Object.fromEntries(headers.map((h, i) => [h, (r[i] ?? "").trim()]))),
  };
}
