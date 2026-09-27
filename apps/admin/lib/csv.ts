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
