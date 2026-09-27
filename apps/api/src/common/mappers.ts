// Domain mappers — DB rows (Json columns already parsed) → src/types/domain shapes.
import type { User } from "../shared/domain";

type UserRow = Omit<User, "levelStartedAt" | "createdAt" | "lastActiveAt" | "gender" | "role" | "category" | "language" | "madhhab" | "calcMethod"> & {
  levelStartedAt: Date | null;
  createdAt: Date;
  lastActiveAt: Date;
  gender: string;
  role: string;
  category: string;
  language: string;
  madhhab: string;
  calcMethod: string;
};

export function toDomainUser(u: UserRow): User {
  return {
    ...u,
    gender: u.gender as User["gender"],
    role: u.role as User["role"],
    category: u.category as User["category"],
    level: u.level as User["level"],
    language: u.language as User["language"],
    madhhab: u.madhhab as User["madhhab"],
    calcMethod: u.calcMethod as User["calcMethod"],
    levelStartedAt: u.levelStartedAt?.toISOString() ?? null,
    createdAt: u.createdAt.toISOString(),
    lastActiveAt: u.lastActiveAt.toISOString(),
  };
}

export function parseJsonField<T>(raw: unknown, fallback: T): T {
  if (raw === null || raw === undefined) return fallback;
  if (typeof raw === "string") {
    try {
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }
  return raw as T;
}
