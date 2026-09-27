import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { json, errorResponse } from "@/lib/server/guard";

// Mock SMS gateway adapter seam — production swaps this for SSL Wireless /
// Infobip. In this workspace the code is returned to the client (devCode).
const OTP_TTL_MIN = 5;
const SEND_WINDOW_MS = 10 * 60 * 1000;
const MAX_SENDS_PER_WINDOW = 3;

export async function POST(req: NextRequest) {
  try {
    const { phone } = (await req.json()) as { phone?: string };
    const normalized = (phone ?? "").replace(/[^\d+]/g, "");
    if (!/^\+?\d{10,15}$/.test(normalized)) {
      return json({ error: "সঠিক মোবাইল নম্বর দিন" }, 400);
    }
    const recent = await db.otpCode.count({
      where: { phone: normalized, createdAt: { gte: new Date(Date.now() - SEND_WINDOW_MS) } },
    });
    if (recent >= MAX_SENDS_PER_WINDOW) {
      return json({ error: "অনেকবার চেষ্টা করেছেন — কিছুক্ষণ পর আবার চেষ্টা করুন" }, 429);
    }
    const code = String(Math.floor(100000 + Math.random() * 900000));
    await db.otpCode.create({
      data: {
        phone: normalized,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60000),
      },
    });
    // ── SMS provider adapter seam ──
    // await smsProvider.send(normalized, `সুন্নাহ লাইফ যাচাইকরণ কোড: ${code}`)
    return json({ ok: true, devCode: code });
  } catch (e) {
    return errorResponse(e);
  }
}
