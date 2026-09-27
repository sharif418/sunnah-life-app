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

const loaders = {
  duas: () => import("../../content/duas.json") as Promise<{ default: DuaPack }>,
  adhkar: () => import("../../content/adhkar.json") as Promise<{ default: AdhkarPack }>,
  names99: () => import("../../content/names99.json") as Promise<{ default: Names99Pack }>,
  islamicNames: () => import("../../content/islamic-names.json") as Promise<{ default: IslamicNamesPack }>,
  imanBranches: () => import("../../content/iman-branches.json") as Promise<{ default: ImanBranchesPack }>,
  sunnahs: () => import("../../content/sunnahs.json") as Promise<{ default: SunnahsPack }>,
  articles: () => import("../../content/articles.json") as Promise<{ default: ArticlesPack }>,
  courses: () => import("../../content/courses.json") as Promise<{ default: CoursesPack }>,
  quizzes: () => import("../../content/quizzes.json") as Promise<{ default: QuizzesPack }>,
  mosques: () => import("../../content/mosques.json") as Promise<{ default: MosquesPack }>,
  faq: () => import("../../content/faq.json") as Promise<{ default: FaqPack }>,
} as const;

export type PackKey = keyof typeof loaders;

const cache: Partial<Record<PackKey, unknown>> = {};

export async function getPack<K extends PackKey>(key: K): Promise<ReturnType<(typeof loaders)[K]>["default"]> {
  if (cache[key]) return cache[key] as never;
  const mod = await loaders[key]();
  cache[key] = mod.default;
  return mod.default;
}

/** Rotating "daily sunnah" index derived from the day-of-year. */
export function dailyIndex(listLength: number, offset = 0): number {
  if (listLength === 0) return 0;
  const doy = Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0).getTime()) / 86400000);
  return (doy + offset) % listLength;
}
