"use client";

// W4j — the OFFLINE search fallback (web side): a local matcher over the
// same content packs the ilm screens render (getPack — memory-cached, and
// served by the service worker's pack cache after the first visit).
//
// This is a PORT of the mobile's lib/features/ilm/search_offline.dart,
// deliberately identical in behavior so both platforms answer the same
// query with the same rows offline:
//   · NORMALIZED SUBSTRING matcher: lowercase + strip zero-width
//     joiners/spaces + collapse whitespace, then substring over the same
//     fields the server's meili indexes rank (title/translation/meaning).
//   · NOT typo-tolerant (no edit distance) — a misspelled query that
//     meili would rescue finds nothing here. The gold strip in the search
//     UI tells the user the saved content answered, not the search engine.
//   · adhkar granularity matches the server: set-level, subtitle "Nটি আযকার".
//   · grouping order = the server's: dua → dhikr → name99 → islamic_name
//     → article; limit caps the TOTAL rows (take from the grouped list).

import { getPack, type AdhkarPack, type ArticlesPack, type DuaPack, type IslamicNamesPack, type Names99Pack, type PackKey } from "@/lib/content";
import { toBn } from "@/lib/calendars";

export type SearchKind = "dua" | "dhikr" | "name99" | "article" | "islamic_name";

/** One grouped search result row (the wire contract of GET /api/search). */
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

const KIND_LABELS: Record<SearchKind, string> = {
  dua: "দোয়া",
  dhikr: "আযকার",
  name99: "আল্লাহর নাম",
  islamic_name: "ইসলামিক নাম",
  article: "আর্টিকেল",
};

/** Zero-width joiners/spaces + whitespace collapse + lowercase (islamic
 *  names are Latin script; Bengali has no case) — the mobile's normalizeSearch. */
export function normalizeSearchText(s: string): string {
  return s
    .replace(/[\u200b\u200c\u200d]/g, "")
    .replace(/\s+/g, " ")
    .toLowerCase()
    .trim();
}

function hit(fields: (string | undefined)[], nq: string): boolean {
  return fields.some((f) => f != null && normalizeSearchText(f).includes(nq));
}

/** Best-effort pack load: a pack that was never fetched (and is not in the
 *  SW cache) rejects offline — the other packs still answer. The gold strip
 *  in the UI already tells the user the SAVED content answered. */
async function tryPack<K extends PackKey>(key: K): Promise<PackValue<K> | null> {
  try {
    return (await getPack(key)) as PackValue<K>;
  } catch {
    return null;
  }
}

type PackValue<K extends PackKey> = Awaited<ReturnType<typeof getPack<K>>>;

/** Search the (cached) content packs. The short-q rule mirrors the API: a
 *  trimmed query under 2 code points answers an empty list. */
export async function searchBundledPacks(q: string, limit = 20): Promise<SearchHit[]> {
  const nq = normalizeSearchText(q);
  if (nq.length < 2) return [];

  const rows: SearchHit[] = [];

  // 1. দোয়া — title / translation / transliteration
  const duas = await tryPack("duas");
  for (const d of duas?.items ?? []) {
    if (hit([d.titleBn, d.translationBn, d.translitBn], nq)) {
      rows.push({
        kind: "dua",
        id: d.id,
        title: d.titleBn,
        subtitle: d.translationBn,
        kindLabelBn: KIND_LABELS.dua,
      });
    }
  }

  // 2. আযকার — set-level (mirrors the server's pack granularity); items'
  //    translation/transliteration participate, subtitle = item count.
  const adhkar = await tryPack("adhkar");
  for (const s of adhkar?.sets ?? []) {
    const itemText = (s.items ?? []).flatMap((i) => [i.translationBn, i.translitBn]);
    if (hit([s.titleBn, ...itemText], nq)) {
      rows.push({
        kind: "dhikr",
        id: s.id,
        title: s.titleBn,
        subtitle: `${toBn(s.items?.length ?? 0)}টি আযকার`,
        kindLabelBn: KIND_LABELS.dhikr,
      });
    }
  }

  // 3. আল্লাহর ৯৯ নাম — transliteration / meaning
  const names99 = await tryPack("names99");
  for (const n of names99?.names ?? []) {
    if (hit([n.translitBn, n.meaningBn], nq)) {
      rows.push({
        kind: "name99",
        id: String(n.id),
        title: n.translitBn,
        subtitle: n.meaningBn,
        kindLabelBn: KIND_LABELS.name99,
      });
    }
  }

  // 4. ইসলামিক নাম — name / meaning
  const islamic = await tryPack("islamicNames");
  for (const n of islamic?.names ?? []) {
    if (hit([n.name, n.meaningBn], nq)) {
      rows.push({
        kind: "islamic_name",
        id: String(n.id),
        title: n.name,
        subtitle: n.meaningBn,
        kindLabelBn: KIND_LABELS.islamic_name,
      });
    }
  }

  // 5. আর্টিকেল — title / excerpt
  const articles = await tryPack("articles");
  for (const a of articles?.items ?? []) {
    if (hit([a.titleBn, a.excerptBn], nq)) {
      rows.push({
        kind: "article",
        id: a.id,
        title: a.titleBn,
        subtitle: a.excerptBn,
        kindLabelBn: KIND_LABELS.article,
      });
    }
  }

  return rows.slice(0, limit);
}
