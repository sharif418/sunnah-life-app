import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { json, errorResponse } from "@/lib/server/guard";
import type { Level } from "@/types/domain";

// Referral landing: /?join=DS-000123 → public minimal info about the inviter.
export async function GET(req: NextRequest) {
  try {
    const code = req.nextUrl.searchParams.get("code");
    if (!code) return json({ error: "কোড দেওয়া হয়নি" }, 400);
    const inviter = await db.user.findUnique({ where: { memberCode: code.toUpperCase() } });
    if (!inviter) return json({ error: "কোডটি সঠিক নয়" }, 404);
    return json({
      inviterName: inviter.name,
      inviterLevel: inviter.level as Level,
    });
  } catch (e) {
    return errorResponse(e);
  }
}
