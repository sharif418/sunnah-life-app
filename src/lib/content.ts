"use client";

// Versioned content packs (the `packages/content` role) loaded client-side
// as async chunks so the app works offline after first load.

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

// Promise-wrapped default-export module per pack; the JSON import shape is
// stable ({ default: <pack> }), so a single cast keeps TS happy while the
// per-key types below stay exact.
type PackModule<P> = { default: P };

const loaders = {
  duas: () => import("../../content/duas.json") as unknown as Promise<PackModule<DuaPack>>,
  adhkar: () => import("../../content/adhkar.json") as unknown as Promise<PackModule<AdhkarPack>>,
  names99: () => import("../../content/names99.json") as unknown as Promise<PackModule<Names99Pack>>,
  islamicNames: () => import("../../content/islamic-names.json") as unknown as Promise<PackModule<IslamicNamesPack>>,
  imanBranches: () => import("../../content/iman-branches.json") as unknown as Promise<PackModule<ImanBranchesPack>>,
  sunnahs: () => import("../../content/sunnahs.json") as unknown as Promise<PackModule<SunnahsPack>>,
  articles: () => import("../../content/articles.json") as unknown as Promise<PackModule<ArticlesPack>>,
  courses: () => import("../../content/courses.json") as unknown as Promise<PackModule<CoursesPack>>,
  quizzes: () => import("../../content/quizzes.json") as unknown as Promise<PackModule<QuizzesPack>>,
  mosques: () => import("../../content/mosques.json") as unknown as Promise<PackModule<MosquesPack>>,
  faq: () => import("../../content/faq.json") as unknown as Promise<PackModule<FaqPack>>,
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
