// ─────────────────────────────────────────────────────────────────────────────
// SearchService [W4j] — the Meilisearch query side of the content packs.
//
//   GET /api/search?q=…&limit=20   (public — guests can search)
//
// Design decisions (documented on purpose):
//   · short-q rule: a trimmed query under 2 code points answers 200 with an
//     EMPTY result list, never a 400 — a single Bengali character is usually
//     a half-typed conjunct and the client debounces anyway; an empty list is
//     the honest answer for a fragment.
//   · Meilisearch is the ONLY engine. When MEILI_HOST is unset or the query
//     fails (network/timeout/5xx) the endpoint answers 503 with a Bengali
//     message — no half-baked server-side substring fallback. The mobile app
//     carries its OWN offline fallback over the bundled packs (smaller blast
//     radius: the fallback lives with the same content it serves offline),
//     and the web surfaces the same Bengali error state. The whole corpus is
//     ~210 docs, so a server fallback would be cheap — honesty was chosen
//     over a second, weaker matcher drifting from meili's behavior.
//   · One POST /multi-search round trip: one query per index, results grouped
//     by kind in the display order dua → dhikr → name99 → islamic_name →
//     article (relevance order is preserved inside each kind).
// ─────────────────────────────────────────────────────────────────────────────
import { Injectable, Logger } from "@nestjs/common";
import { ApiError } from "../common/api-error";

export type SearchKind = "dua" | "dhikr" | "name99" | "article" | "islamic_name";

/** One grouped search result row (the wire contract for web + mobile). */
export interface SearchHit {
  kind: SearchKind;
  id: string;
  title: string;
  subtitle?: string;
  kindLabelBn: string;
}

export interface SearchResponse {
  query: string;
  results: SearchHit[];
}

/** ASCII → Bengali digits (the adhkar subtitle reports item counts in bn). */
const BN_DIGITS = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];
const toBn = (n: number): string => String(n).replace(/\d/g, (d) => BN_DIGITS[Number(d)]);

const asText = (v: unknown): string => (typeof v === "string" ? v : "");

/** Per-index hit → grouped row mapping. Order = the grouping order. */
const INDEXES: {
  uid: string;
  kind: SearchKind;
  kindLabelBn: string;
  title: (hit: Record<string, unknown>) => string;
  subtitle: (hit: Record<string, unknown>) => string | undefined;
}[] = [
  {
    uid: "duas",
    kind: "dua",
    kindLabelBn: "দোয়া",
    title: (h) => asText(h.titleBn),
    subtitle: (h) => asText(h.translationBn) || undefined,
  },
  {
    uid: "adhkar",
    kind: "dhikr",
    kindLabelBn: "আযকার",
    title: (h) => asText(h.titleBn),
    // sets carry their items inline — "৯টি আযকার" reads better than the
    // period key the title already states in Bengali
    subtitle: (h) => (Array.isArray(h.items) ? `${toBn(h.items.length)}টি আযকার` : undefined),
  },
  {
    uid: "names99",
    kind: "name99",
    kindLabelBn: "আল্লাহর নাম",
    title: (h) => asText(h.translitBn) || asText(h.arabic),
    subtitle: (h) => asText(h.meaningBn) || undefined,
  },
  {
    uid: "islamic-names",
    kind: "islamic_name",
    kindLabelBn: "ইসলামিক নাম",
    title: (h) => asText(h.name),
    subtitle: (h) => asText(h.meaningBn) || undefined,
  },
  {
    uid: "articles",
    kind: "article",
    kindLabelBn: "আর্টিকেল",
    title: (h) => asText(h.titleBn),
    subtitle: (h) => asText(h.excerptBn) || undefined,
  },
];

const SEARCH_DOWN = "অনুসন্ধান সেবা এখন অনুপলব্ধ — কিছুক্ষণ পরে আবার চেষ্টা করুন";

@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);

  async search(rawQ: string | undefined, rawLimit?: number | string): Promise<SearchResponse> {
    const q = (rawQ ?? "").trim();
    // limit rule: garbage or ≤0 → the default 20; >50 → clamped to 50
    const parsed = Number(rawLimit);
    const limit = Math.min(Math.max(Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 20, 1), 50);
    if (q.length < 2) return { query: q, results: [] };

    const host = process.env.MEILI_HOST;
    if (!host) throw new ApiError(503, SEARCH_DOWN);

    let results: unknown[];
    try {
      const res = await fetch(`${host}/multi-search`, {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({
          queries: INDEXES.map((ix) => ({ indexUid: ix.uid, q, limit })),
        }),
        signal: AbortSignal.timeout(3000),
      });
      if (!res.ok) throw new Error(`meili multi-search → ${res.status}`);
      const body = (await res.json()) as { results?: unknown[] };
      results = Array.isArray(body.results) ? body.results : [];
    } catch (e) {
      this.logger.warn(`search "${q.slice(0, 40)}" failed: ${e instanceof Error ? e.message : e}`);
      throw new ApiError(503, SEARCH_DOWN);
    }

    // Group by kind in the INDEXES display order; relevance order survives
    // inside each kind (meili's per-query hit order).
    const rows: SearchHit[] = [];
    for (let i = 0; i < INDEXES.length; i++) {
      const perIndex = results[i];
      const hits = perIndex && typeof perIndex === "object" ? (perIndex as { hits?: unknown[] }).hits ?? [] : [];
      for (const hit of Array.isArray(hits) ? hits : []) {
        if (!hit || typeof hit !== "object") continue;
        const h = hit as Record<string, unknown>;
        const ix = INDEXES[i];
        const id = h.id;
        if (id === undefined || id === null) continue; // meili always returns the primary key
        const title = ix.title(h).trim();
        if (!title) continue;
        rows.push({
          kind: ix.kind,
          id: String(id),
          title,
          subtitle: ix.subtitle(h),
          kindLabelBn: ix.kindLabelBn,
        });
      }
    }
    return { query: q, results: rows.slice(0, limit) };
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (process.env.MEILI_KEY) h.Authorization = `Bearer ${process.env.MEILI_KEY}`;
    return h;
  }
}
