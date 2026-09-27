import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { getSessionUser, toDomainUser, ApiError } from "@/lib/server/auth";
import { json, errorResponse } from "@/lib/server/guard";

export async function GET() {
  try {
    const user = await getSessionUser();
    if (user) {
      await db.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } }).catch(() => null);
    }
    return json({ user });
  } catch (e) {
    return errorResponse(e);
  }
}

const ALLOWED_FIELDS = [
  "name", "language", "madhhab", "calcMethod", "lat", "lng", "city",
  "district", "workplace", "department", "category",
] as const;

export async function PATCH(req: NextRequest) {
  try {
    const user = await getSessionUser();
    if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");
    const body = (await req.json()) as Record<string, unknown>;
    const data: Record<string, unknown> = {};
    for (const f of ALLOWED_FIELDS) {
      if (f in body) data[f] = body[f];
    }
    if (Object.keys(data).length === 0) return json({ error: "কিছু পরিবর্তন দেওয়া হয়নি" }, 400);
    const updated = await db.user.update({ where: { id: user.id }, data });
    return json({ user: toDomainUser(updated) });
  } catch (e) {
    return errorResponse(e);
  }
}
