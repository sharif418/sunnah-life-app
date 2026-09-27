import "server-only";
import { cookies } from "next/headers";
import { db } from "@/lib/db";
import type { User } from "@/types/domain";

export const SESSION_COOKIE = "sl_session";
const SESSION_DAYS = 30;

export async function createSession(userId: string): Promise<string> {
  const token = crypto.randomUUID() + crypto.randomUUID().replace(/-/g, "");
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 86400_000);
  await db.session.create({ data: { id: token, userId, expiresAt } });
  const jar = await cookies();
  jar.set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_DAYS * 86400,
  });
  return token;
}

export async function destroySession(): Promise<void> {
  const jar = await cookies();
  const token = jar.get(SESSION_COOKIE)?.value;
  if (token) {
    await db.session.deleteMany({ where: { id: token } });
  }
  jar.delete(SESSION_COOKIE);
}

export async function getSessionUser(): Promise<User | null> {
  const jar = await cookies();
  const token = jar.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const session = await db.session.findUnique({ where: { id: token }, include: { user: true } });
  if (!session || session.expiresAt < new Date()) return null;
  return toDomainUser(session.user);
}

export function toDomainUser(u: {
  id: string; phone: string | null; email: string | null; name: string; photoUrl: string | null;
  gender: string; role: string; category: string; memberCode: string | null; referredById: string | null;
  usrahId: string | null; level: string; levelStartedAt: Date | null; district: string | null;
  workplace: string | null; department: string | null; language: string; madhhab: string; calcMethod: string;
  lat: number | null; lng: number | null; city: string | null; createdAt: Date; lastActiveAt: Date;
}): User {
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

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function requireUser(): Promise<User> {
  const user = await getSessionUser();
  if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");
  return user;
}

export async function requireRole(...roles: User["role"][]): Promise<User> {
  const user = await requireUser();
  if (!roles.includes(user.role)) throw new ApiError(403, "এই কাজের অনুমতি নেই");
  return user;
}

export async function audit(
  actorId: string | null,
  action: string,
  targetType: string,
  targetId?: string | null,
  meta?: Record<string, unknown>
): Promise<void> {
  await db.auditLog.create({
    data: {
      actorId,
      action,
      targetType,
      targetId: targetId ?? null,
      metaJson: meta ? JSON.stringify(meta) : null,
    },
  });
}
