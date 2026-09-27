import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { createSession, toDomainUser } from "@/lib/server/auth";
import { json, errorResponse } from "@/lib/server/guard";
import type { AmalEntry } from "@/types/domain";

const VERIFY_MAX_ATTEMPTS = 5;

export async function POST(req: NextRequest) {
  try {
    const { phone, code, name, gender, referredByCode, guestEntries } = (await req.json()) as {
      phone?: string;
      code?: string;
      name?: string;
      gender?: "M" | "F";
      referredByCode?: string;
      guestEntries?: AmalEntry[];
    };
    const normalized = (phone ?? "").replace(/[^\d+]/g, "");
    if (!normalized || !code) return json({ error: "নম্বর ও কোড দিন" }, 400);

    const otp = await db.otpCode.findFirst({
      where: { phone: normalized, expiresAt: { gte: new Date() } },
      orderBy: { createdAt: "desc" },
    });
    if (!otp) return json({ error: "কোডের সময় শেষ — আবার পাঠান" }, 400);
    if (otp.attempts >= VERIFY_MAX_ATTEMPTS) {
      return json({ error: "অনেকবার ভুল কোড — নতুন কোড নিন" }, 429);
    }
    if (otp.code !== code.trim()) {
      await db.otpCode.update({ where: { id: otp.id }, data: { attempts: otp.attempts + 1 } });
      return json({ error: "ভুল কোড" }, 400);
    }
    await db.otpCode.deleteMany({ where: { phone: normalized } });

    // find or create the user
    let user = await db.user.findUnique({ where: { phone: normalized } });

    if (!user) {
      // referral resolution
      let referredById: string | null = null;
      if (referredByCode) {
        const inviter = await db.user.findUnique({ where: { memberCode: referredByCode.toUpperCase() } });
        referredById = inviter?.id ?? null;
      }
      const created = await db.user.create({
        data: {
          phone: normalized,
          name: name?.trim() || "ব্যবহারকারী",
          gender: gender === "F" ? "F" : "M", // set once at onboarding; admin-only change later
          referredById,
        },
      });
      user = created;
      // build the referral closure (ancestor paths of inviter + self)
      if (referredById) {
        const inviterRows = await db.referralClosure.findMany({ where: { descendantId: referredById } });
        await db.referralClosure.createMany({
          data: [
            ...inviterRows.map((r) => ({ ancestorId: r.ancestorId, descendantId: created.id, depth: r.depth + 1 })),
            { ancestorId: referredById, descendantId: created.id, depth: 1 },
          ],
        });
      }
    } else if (name?.trim()) {
      user = await db.user.update({ where: { id: user.id }, data: { name: name.trim() } });
    }

    await createSession(user.id);

    // guest → account data merge (local amal diary entries).
    // Natural key (userId, amalKey, date); latest clientUpdatedAt wins (offline-sync rule).
    if (guestEntries?.length) {
      for (const e of guestEntries.slice(0, 500)) {
        const incoming = new Date(e.clientUpdatedAt);
        const existing = await db.amalEntry.findUnique({
          where: { userId_amalKey_date: { userId: user.id, amalKey: e.amalKey, date: e.date } },
        });
        if (!existing || existing.clientUpdatedAt < incoming) {
          await db.amalEntry.upsert({
            where: { userId_amalKey_date: { userId: user.id, amalKey: e.amalKey, date: e.date } },
            create: {
              userId: user.id,
              amalKey: e.amalKey,
              date: e.date,
              valueJson: JSON.stringify(e.value),
              source: e.source ?? "manual",
              clientUpdatedAt: incoming,
            },
            update: {
              valueJson: JSON.stringify(e.value),
              source: e.source ?? "manual",
              clientUpdatedAt: incoming,
            },
          });
        }
      }
    }

    return json({ user: toDomainUser(user) });
  } catch (e) {
    return errorResponse(e);
  }
}
