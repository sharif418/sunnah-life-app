// How the salawat mark after the Prophet's name is shown in Bengali text —
// the same rule as the app (apps/mobile/lib/core/honorific.dart). The content
// keeps ﷺ as written; at body size the one-glyph ligature is unreadable micro
// text in SolaimanLipi, so Bengali sentences show "(সা.)". Arabic text keeps
// the ligature. Decided 2026-10-09 pending the Foundation's word — to show
// the full phrase or the symbol instead, change HONORIFIC_BN only.

export const HONORIFIC_BN = "(সা.)";

const BENGALI = /[ঀ-৿]/;
const MARK = /\s*ﷺ/g;

/** "নবীজি ﷺ বলেছেন" → "নবীজি (সা.) বলেছেন"; Arabic-only text unchanged. */
export function honorificText(s: string): string {
  if (!s.includes("ﷺ") || !BENGALI.test(s)) return s;
  return s.replace(MARK, ` ${HONORIFIC_BN}`).trimStart();
}

/** honorificText over every string of a decoded JSON document. */
export function withHonorific<T>(v: T): T {
  if (typeof v === "string") return honorificText(v) as T;
  if (Array.isArray(v)) return v.map((x) => withHonorific(x)) as T;
  if (v && typeof v === "object") {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, withHonorific(x)])) as T;
  }
  return v;
}
