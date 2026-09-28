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
  tz: string;
  calcMethod: string;
};

/**
 * DB user row → domain User. Explicit field list (NOT a spread): keeps the
 * API response contract pinned and guarantees internal-only columns (the
 * social Provider/sub ids, future internal fields) can never leak to clients.
 */
export function toDomainUser(u: UserRow): User {
  return {
    id: u.id,
    phone: u.phone ?? null,
    email: u.email ?? null,
    name: u.name,
    photoUrl: u.photoUrl ?? null,
    gender: u.gender as User["gender"],
    role: u.role as User["role"],
    category: u.category as User["category"],
    memberCode: u.memberCode ?? null,
    referredById: u.referredById ?? null,
    usrahId: u.usrahId ?? null,
    level: u.level as User["level"],
    levelStartedAt: u.levelStartedAt?.toISOString() ?? null,
    district: u.district ?? null,
    workplace: u.workplace ?? null,
    department: u.department ?? null,
    language: u.language as User["language"],
    madhhab: u.madhhab as User["madhhab"],
    tz: u.tz ?? "Asia/Dhaka",
    calcMethod: u.calcMethod as User["calcMethod"],
    lat: u.lat ?? null,
    lng: u.lng ?? null,
    city: u.city ?? null,
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
