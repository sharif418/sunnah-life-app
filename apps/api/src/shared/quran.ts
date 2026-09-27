// ─────────────────────────────────────────────────────────────────────────────
// Qur'an + content pack loader (cached, file-based — same data files the web
// workspace serves). Ported from src/lib/server/quran.ts + src/lib/content.ts.
// ─────────────────────────────────────────────────────────────────────────────

import { promises as fs } from "fs";
import path from "path";
import { contentDir } from "./levels";

export interface RawSurah {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  revelationType: string;
  ayahs: { number: number; text: string; numberInSurah: number; juz: number; page: number }[];
}

export interface QuranCache {
  surahs: RawSurah[];
  bnBySurah: Map<number, string[]>;
  bnNames: Record<number, string> | null;
  loadedAt: number;
}

const g = globalThis as unknown as { quranCache?: QuranCache };
const TTL = 60 * 60 * 1000;

export async function loadQuran(): Promise<QuranCache> {
  if (g.quranCache && Date.now() - g.quranCache.loadedAt < TTL) return g.quranCache;
  const dir = contentDir();
  const raw = JSON.parse(await fs.readFile(path.join(dir, "quran-uthmani.json"), "utf8")) as {
    data: { surahs: RawSurah[] };
  };
  const rawBn = JSON.parse(await fs.readFile(path.join(dir, "quran-bn.json"), "utf8")) as {
    data: { surahs: { number: number; ayahs: { numberInSurah: number; text: string }[] }[] };
  };
  const bnBySurah = new Map<number, string[]>();
  for (const s of rawBn.data.surahs) {
    bnBySurah.set(s.number, s.ayahs.map((a) => a.text));
  }
  let bnNames: Record<number, string> | null = null;
  try {
    const meta = JSON.parse(await fs.readFile(path.join(dir, "quran-meta-bn.json"), "utf8")) as {
      surahs: { number: number; nameBn: string }[];
    };
    bnNames = Object.fromEntries(meta.surahs.map((s) => [s.number, s.nameBn]));
  } catch {
    bnNames = null;
  }
  g.quranCache = { surahs: raw.data.surahs, bnBySurah, bnNames, loadedAt: Date.now() };
  return g.quranCache;
}

// ── Content packs (static JSON served as packs) ────────────────────────────

export type PackKey =
  | "duas"
  | "adhkar"
  | "names99"
  | "islamic-names"
  | "iman-branches"
  | "sunnahs"
  | "articles"
  | "courses"
  | "quizzes"
  | "mosques"
  | "faq";

const PACK_FILES: Record<PackKey, string> = {
  duas: "duas.json",
  adhkar: "adhkar.json",
  names99: "names99.json",
  "islamic-names": "islamic-names.json",
  "iman-branches": "iman-branches.json",
  sunnahs: "sunnahs.json",
  articles: "articles.json",
  courses: "courses.json",
  quizzes: "quizzes.json",
  mosques: "mosques.json",
  faq: "faq.json",
};

export const PACK_KEYS = Object.keys(PACK_FILES) as PackKey[];

const packCache = new Map<string, { at: number; data: unknown }>();
const PACK_TTL = 5 * 60 * 1000;

export async function loadPack(key: string): Promise<unknown | null> {
  const file = PACK_FILES[key as PackKey];
  if (!file) return null;
  const hit = packCache.get(key);
  if (hit && Date.now() - hit.at < PACK_TTL) return hit.data;
  try {
    const data = JSON.parse(await fs.readFile(path.join(contentDir(), file), "utf8"));
    packCache.set(key, { at: Date.now(), data });
    return data;
  } catch {
    return null;
  }
}

/** Documents of a pack for Meilisearch indexing (id field required). */
export function packDocuments(data: unknown): Record<string, unknown>[] {
  if (Array.isArray(data)) return data.filter((x) => x && typeof x === "object" && "id" in (x as object));
  if (data && typeof data === "object") {
    const obj = data as Record<string, unknown>;
    for (const v of Object.values(obj)) {
      if (Array.isArray(v)) {
        return v.filter((x): x is Record<string, unknown> => !!x && typeof x === "object" && "id" in (x as object));
      }
    }
  }
  return [];
}
