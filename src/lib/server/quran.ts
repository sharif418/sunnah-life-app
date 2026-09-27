import "server-only";
import { promises as fs } from "fs";
import path from "path";

const CONTENT_DIR = path.join(process.cwd(), "content");

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
  const raw = JSON.parse(await fs.readFile(path.join(CONTENT_DIR, "quran-uthmani.json"), "utf8")) as {
    data: { surahs: RawSurah[] };
  };
  const rawBn = JSON.parse(await fs.readFile(path.join(CONTENT_DIR, "quran-bn.json"), "utf8")) as {
    data: { surahs: { number: number; ayahs: { numberInSurah: number; text: string }[] }[] };
  };
  const bnBySurah = new Map<number, string[]>();
  for (const s of rawBn.data.surahs) {
    bnBySurah.set(s.number, s.ayahs.map((a) => a.text));
  }
  let bnNames: Record<number, string> | null = null;
  try {
    const meta = JSON.parse(await fs.readFile(path.join(CONTENT_DIR, "quran-meta-bn.json"), "utf8")) as {
      surahs: { number: number; nameBn: string }[];
    };
    bnNames = Object.fromEntries(meta.surahs.map((s) => [s.number, s.nameBn]));
  } catch {
    bnNames = null;
  }
  g.quranCache = { surahs: raw.data.surahs, bnBySurah, bnNames, loadedAt: Date.now() };
  return g.quranCache;
}
