// Bengali-typo-tolerant fuzzy search (the Meilisearch stand-in for this workspace).

function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[\u0964\u0965।,.!?;:'"()\[\]{}\-–—_\/\\]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function bigrams(s: string): Set<string> {
  const t = normalize(s).replace(/ /g, "");
  const out = new Set<string>();
  for (let i = 0; i < t.length - 1; i++) out.add(t.slice(i, i + 2));
  return out;
}

/** 0..1 similarity with substring bonus + bigram overlap (typo tolerant). */
export function fuzzyScore(query: string, target: string): number {
  const q = normalize(query);
  const t = normalize(target);
  if (!q) return 0;
  if (!t) return 0;
  if (t === q) return 1;
  if (t.includes(q)) return 0.9;
  if (q.length <= 2) return t.startsWith(q) ? 0.6 : 0;

  const qBigrams = bigrams(q);
  const tBigrams = bigrams(t);
  let hits = 0;
  for (const b of qBigrams) if (tBigrams.has(b)) hits++;
  const overlap = hits / qBigrams.size;

  // whole-word containment bonus
  const qWords = q.split(" ").filter((w) => w.length > 1);
  const tWords = new Set(t.split(" "));
  const wordHits = qWords.filter((w) => tWords.has(w)).length;
  const wordScore = qWords.length ? wordHits / qWords.length : 0;

  return Math.min(1, overlap * 0.6 + wordScore * 0.4);
}

/** Filter + rank a list by the best fuzzy score across the given fields. */
export function searchList<T>(
  query: string,
  items: T[],
  fields: (item: T) => (string | undefined)[],
  limit = 30
): T[] {
  if (!query.trim()) return items.slice(0, limit);
  const scored: { item: T; score: number }[] = [];
  for (const item of items) {
    let best = 0;
    for (const f of fields(item)) {
      if (!f) continue;
      best = Math.max(best, fuzzyScore(query, f));
    }
    if (best > 0.28) scored.push({ item, score: best });
  }
  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((s) => s.item);
}
