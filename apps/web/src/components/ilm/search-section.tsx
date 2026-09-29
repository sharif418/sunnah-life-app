"use client";

// W4j — অনুসন্ধান (web): the Ilm tab's unified content search, the web
// client of GET /api/search (public — guests can search). Debounced
// queries; results grouped by kind (chip + title + subtitle); a tap deep
// links the pack's own screen (duas even highlights the exact item).
//
// OFFLINE FALLBACK — the mobile parity path: when the network is down
// (fetch rejects) or the server's search engine is unavailable (503), the
// same content packs the ilm screens render answer locally
// (lib/search-offline.ts — normalized substring, NO typo tolerance; the
// gold strip says exactly that). The packs are memory-cached by getPack
// after the first visit and served by the service worker's pack cache
// (SWR — see public/sw.js), so the fallback is real after first use.

import * as React from "react";
import { Search, WifiOff } from "lucide-react";
import { apiUrl } from "@/lib/api-base";
import { translate } from "@/lib/i18n";
import { useApp } from "@/lib/store";
import { searchBundledPacks, type SearchHit, type SearchKind } from "@/lib/search-offline";
import { EmptyState, ErrorState, SkeletonRows } from "./parts";

class SearchFail extends Error {
  constructor(
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

export function SearchSection({ query, onResultTap }: { query: string; onResultTap?: () => void }) {
  const lang = useApp((s) => s.profile.language);
  const nav = useApp((s) => s.nav);
  const t = (k: string) => translate(lang, k);

  const [rows, setRows] = React.useState<SearchHit[]>([]);
  const [busy, setBusy] = React.useState(true);
  const [offline, setOffline] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [nonce, setNonce] = React.useState(0);
  const seq = React.useRef(0);

  /** Where a result row navigates — the pack's own screen (duas + articles
   *  deep link the exact item: both views support a highlight id).
 *  onResultTap clears the field so the destination actually shows (the
   *  search swap would otherwise keep the results on screen). */
  const navFor = (kind: SearchKind, id: string) => {
    onResultTap?.();
    switch (kind) {
      case "dua":
        nav("ilm", "dua", { id });
        break;
      case "dhikr":
        nav("ilm", "adhkar");
        break;
      case "name99":
        nav("ilm", "names99");
        break;
      case "islamic_name":
        nav("ilm", "islamic-names");
        break;
      case "article":
        nav("ilm", "articles", { id });
        break;
    }
  };

  const run = React.useCallback(
    async (q: string) => {
      const mine = ++seq.current;
      setBusy(true);
      setError(null);
      setOffline(false);
      try {
        const res = await fetch(apiUrl(`/api/search?q=${encodeURIComponent(q)}&limit=20`), {
          headers: { Accept: "application/json" },
        });
        if (!res.ok) throw new SearchFail(`অনুসন্ধান ব্যর্থ (${res.status})`, res.status);
        const json = (await res.json()) as { results?: SearchHit[] };
        if (mine !== seq.current) return; // a newer keystroke won the race
        setRows(json.results ?? []);
        setBusy(false);
      } catch (e) {
        const status = e instanceof SearchFail ? e.status : 0; // fetch reject = network down
        // Offline (0) or the server's search engine unavailable (503) —
        // the saved packs answer locally (mobile parity).
        if (status === 0 || status === 503) {
          try {
            const local = await searchBundledPacks(q);
            if (mine !== seq.current) return;
            setRows(local);
            setOffline(true);
            setBusy(false);
            return;
          } catch {
            // fall through to the error state
          }
        }
        if (mine !== seq.current) return;
        setError(e instanceof Error ? e.message : "অনুসন্ধান ব্যর্থ");
        setBusy(false);
      }
    },
    []
  );

  React.useEffect(() => {
    const id = window.setTimeout(() => run(query), 350);
    return () => window.clearTimeout(id);
  }, [query, nonce, run]);

  return (
    <div>
      {offline ? (
        <div className="mb-3 flex items-center gap-2 rounded-xl bg-gold-soft px-3.5 py-2.5 text-xs font-semibold text-gold-text">
          <WifiOff className="size-4 shrink-0" />
          <span>{t("search.offlineNote")}</span>
        </div>
      ) : null}

      {busy ? (
        <SkeletonRows count={5} className="h-16" />
      ) : error ? (
        <ErrorState message={error} onRetry={() => setNonce((n) => n + 1)} />
      ) : rows.length === 0 ? (
        <EmptyState icon={Search} title={t("search.noResults")} />
      ) : (
        <ul className="space-y-2.5">
          {rows.map((hit) => (
            <li key={`${hit.kind}:${hit.id}`}>
              <button
                onClick={() => navFor(hit.kind, hit.id)}
                className="tap-target block w-full rounded-xl border border-border bg-card p-4 text-start shadow-card transition-colors hover:bg-muted/50"
              >
                <span className="inline-block rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary">
                  {hit.kindLabelBn}
                </span>
                <h3 className="mt-2 text-[15px] font-bold leading-snug">{hit.title}</h3>
                {hit.subtitle ? (
                  <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-muted-foreground">{hit.subtitle}</p>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
