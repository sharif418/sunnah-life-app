"use client";

// Versioned content packs, fetched from the NestJS API (single backend —
// GET /api/content/:pack). Cached in memory after the first load so a tab
// only pays the network cost once per pack.

import { apiUrl } from "@/lib/api-base";
import type {
  ArticleItem,
  Course,
  DhikrSet,
  DuaItem,
  ImanBranch,
  IslamicName,
  MosqueInfo,
  NameOfAllah,
  Quiz,
  SunnahItem,
} from "@/types/domain";

export interface DuaPack {
  items: DuaItem[];
  categories?: { key: string; labelBn: string }[];
}
export interface AdhkarPack {
  sets: DhikrSet[];
}
export interface Names99Pack {
  names: NameOfAllah[];
}
export interface IslamicNamesPack {
  names: IslamicName[];
}
export interface ImanBranchesPack {
  branches: ImanBranch[];
}
export interface SunnahsPack {
  items: SunnahItem[];
}
export interface ArticlesPack {
  items: ArticleItem[];
}
export interface CoursesPack {
  courses: Course[];
}
export interface QuizzesPack {
  quizzes: Quiz[];
}
export interface MosquesPack {
  mosques: MosqueInfo[];
}
export interface FaqPack {
  items: { q: string; a: string }[];
}

// Promise-wrapped default-export module per pack; kept as an internal shape
// so the per-key types below stay exact while the loader fetches JSON.
type PackModule<P> = { default: P };

/** Web pack key → API pack key (only the kebab-cased ones differ). */
const API_KEYS = {
  duas: "duas",
  adhkar: "adhkar",
  names99: "names99",
  islamicNames: "islamic-names",
  imanBranches: "iman-branches",
  sunnahs: "sunnahs",
  articles: "articles",
  courses: "courses",
  quizzes: "quizzes",
  mosques: "mosques",
  faq: "faq",
} as const;

async function fetchPack<P>(key: string): Promise<PackModule<P>> {
  const res = await fetch(apiUrl(`/api/content/${key}`), { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`কন্টেন্ট লোড করা যায়নি (${key}, ${res.status})`);
  const json = (await res.json()) as { data: P };
  return { default: json.data };
}

const loaders = {
  duas: () => fetchPack<DuaPack>(API_KEYS.duas),
  adhkar: () => fetchPack<AdhkarPack>(API_KEYS.adhkar),
  names99: () => fetchPack<Names99Pack>(API_KEYS.names99),
  islamicNames: () => fetchPack<IslamicNamesPack>(API_KEYS.islamicNames),
  imanBranches: () => fetchPack<ImanBranchesPack>(API_KEYS.imanBranches),
  sunnahs: () => fetchPack<SunnahsPack>(API_KEYS.sunnahs),
  articles: () => fetchPack<ArticlesPack>(API_KEYS.articles),
  courses: () => fetchPack<CoursesPack>(API_KEYS.courses),
  quizzes: () => fetchPack<QuizzesPack>(API_KEYS.quizzes),
  mosques: () => fetchPack<MosquesPack>(API_KEYS.mosques),
  faq: () => fetchPack<FaqPack>(API_KEYS.faq),
} as const;

// Exact pack type per key — the single source of truth for getPack's return.
interface PackMap {
  duas: DuaPack;
  adhkar: AdhkarPack;
  names99: Names99Pack;
  islamicNames: IslamicNamesPack;
  imanBranches: ImanBranchesPack;
  sunnahs: SunnahsPack;
  articles: ArticlesPack;
  courses: CoursesPack;
  quizzes: QuizzesPack;
  mosques: MosquesPack;
  faq: FaqPack;
}

export type PackKey = keyof PackMap;

const cache: Partial<PackMap> = {};

export async function getPack<K extends PackKey>(key: K): Promise<PackMap[K]> {
  if (cache[key] !== undefined) return cache[key] as PackMap[K];
  const mod = await loaders[key]();
  cache[key] = mod.default as PackMap[K];
  return mod.default as PackMap[K];
}

/** Rotating "daily sunnah" index derived from the day-of-year. */
export function dailyIndex(listLength: number, offset = 0): number {
  if (listLength === 0) return 0;
  const doy = Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0).getTime()) / 86400000);
  return (doy + offset) % listLength;
}
