import { Injectable, Logger } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { createHash, randomUUID } from "crypto";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { toDomainUser } from "../common/mappers";
import type { User } from "../shared/domain";
import type { GuestEntryDto } from "./dto/auth.dto";
import { SmsService } from "./sms/sms.service";

const OTP_TTL_MIN = 5;
const SEND_WINDOW_MS = 10 * 60 * 1000;
const MAX_SENDS_PER_WINDOW = 3;
const VERIFY_MAX_ATTEMPTS = 5;

const ACCESS_TTL_SEC = () => Number(process.env.ACCESS_TOKEN_TTL_MIN || 15) * 60;
const REFRESH_TTL_SEC = () => Number(process.env.REFRESH_TOKEN_TTL_DAYS || 7) * 86400;
/** Refresh tokens are signed with their own secret (falls back to JWT_SECRET). */
const REFRESH_SECRET = () => process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET || "dev-only-secret-change-me-in-production";

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  tokenType: "Bearer";
  expiresIn: number;
}

export interface VerifyResult {
  user: ReturnType<typeof toDomainUser>;
  tokens: TokenPair;
}

function sha256(s: string): string {
  return createHash("sha256").update(s).digest("hex");
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly rls: RlsService,
    private readonly jwt: JwtService,
    private readonly sms: SmsService
  ) {}

  // ── OTP request ───────────────────────────────────────────────────────────

  async requestOtp(rawPhone: string): Promise<{ ok: true; devCode?: string }> {
    const normalized = (rawPhone ?? "").replace(/[^\d+]/g, "");
    if (!/^\+?\d{10,15}$/.test(normalized)) {
      throw new ApiError(400, "সঠিক মোবাইল নম্বর দিন");
    }
    // per-phone send-window rate limit (DB-backed, same rule as the web API:
    // max 3 sends per 10 minutes). OtpCode is RLS-exempt.
    const recent = await this.rls.system((tx) =>
      tx.otpCode.count({
        where: { phone: normalized, createdAt: { gte: new Date(Date.now() - SEND_WINDOW_MS) } },
      })
    );
    if (recent >= MAX_SENDS_PER_WINDOW) {
      throw new ApiError(429, "অনেকবার চেষ্টা করেছেন — কিছুক্ষণ পর আবার চেষ্টা করুন");
    }
    const code = String(Math.floor(100000 + Math.random() * 900000));
    await this.rls.system((tx) =>
      tx.otpCode.create({
        data: { phone: normalized, code, expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60000) },
      })
    );
    const { devCode } = await this.sms.sendOtp(normalized, code);
    return { ok: true, ...(devCode ? { devCode } : {}) };
  }

  // ── OTP verify (find-or-create + referral closure + guest merge) ──────────

  async verifyOtp(
    phone: string,
    code: string,
    name?: string,
    gender?: "M" | "F",
    referredByCode?: string,
    guestEntries?: GuestEntryDto[]
  ): Promise<VerifyResult> {
    const normalized = (phone ?? "").replace(/[^\d+]/g, "");
    if (!normalized || !code) throw new ApiError(400, "নম্বর ও কোড দিন");

    const otp = await this.rls.system((tx) =>
      tx.otpCode.findFirst({
        where: { phone: normalized, expiresAt: { gte: new Date() } },
        orderBy: { createdAt: "desc" },
      })
    );
    if (!otp) throw new ApiError(400, "কোডের সময় শেষ — আবার পাঠান");
    if (otp.attempts >= VERIFY_MAX_ATTEMPTS) {
      throw new ApiError(429, "অনেকবার ভুল কোড — নতুন কোড নিন");
    }
    if (otp.code !== code.trim()) {
      await this.rls.system((tx) =>
        tx.otpCode.update({ where: { id: otp.id }, data: { attempts: otp.attempts + 1 } })
      );
      throw new ApiError(400, "ভুল কোড");
    }
    await this.rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: normalized } }));

    // find or create the user (bootstrap context: pre-auth)
    const user = await this.rls.system(async (tx) => {
      let row = await tx.user.findUnique({ where: { phone: normalized } });

      if (!row) {
        let referredById: string | null = null;
        if (referredByCode) {
          const inviter = await tx.user.findUnique({ where: { memberCode: referredByCode.toUpperCase() } });
          referredById = inviter?.id ?? null;
        }
        row = await tx.user.create({
          data: {
            phone: normalized,
            name: name?.trim() || "ব্যবহারকারী",
            gender: gender === "F" ? "F" : "M", // set once at onboarding; admin-only change later
            referredById,
          },
        });
        // build the referral closure (ancestor paths of inviter + self)
        if (referredById && row) {
          const createdId: string = row.id;
          const inviterRows = await tx.referralClosure.findMany({ where: { descendantId: referredById } });
          await tx.referralClosure.createMany({
            data: [
              ...inviterRows.map((r) => ({ ancestorId: r.ancestorId, descendantId: createdId, depth: r.depth + 1 })),
              { ancestorId: referredById, descendantId: createdId, depth: 1 },
            ],
          });
        }
      } else if (name?.trim()) {
        row = await tx.user.update({ where: { id: row.id }, data: { name: name.trim() } });
      }
      return row;
    });

    const domain = toDomainUser(user as never);

    // guest → account data merge (local amal diary entries), run with the new
    // user's own RLS context. Natural key (userId, amalKey, date); latest
    // clientUpdatedAt wins (offline-sync rule).
    if (guestEntries?.length) {
      await this.rls.run(domain, async (tx) => {
        for (const e of guestEntries.slice(0, 500)) {
          const incoming = new Date(e.clientUpdatedAt);
          if (isNaN(incoming.getTime())) continue;
          const existing = await tx.amalEntry.findUnique({
            where: { userId_amalKey_date: { userId: user.id, amalKey: e.amalKey, date: e.date } },
          });
          if (!existing || existing.clientUpdatedAt < incoming) {
            await tx.amalEntry.upsert({
              where: { userId_amalKey_date: { userId: user.id, amalKey: e.amalKey, date: e.date } },
              create: {
                userId: user.id,
                amalKey: e.amalKey,
                date: e.date,
                valueJson: e.value as never,
                source: e.source ?? "manual",
                clientUpdatedAt: incoming,
              },
              update: {
                valueJson: e.value as never,
                source: e.source ?? "manual",
                clientUpdatedAt: incoming,
              },
            });
          }
        }
      });
    }

    const tokens = await this.issueTokens(user.id);
    return { user: domain, tokens };
  }

  // ── Token issuance / rotation ─────────────────────────────────────────────

  private async signAccess(userId: string): Promise<string> {
    return this.jwt.signAsync(
      { sub: userId },
      { secret: process.env.JWT_SECRET, expiresIn: ACCESS_TTL_SEC() }
    );
  }

  private async issueTokens(userId: string): Promise<TokenPair> {
    const accessToken = await this.signAccess(userId);
    const familyId = randomUUID();
    const jti = randomUUID();
    const refreshToken = await this.jwt.signAsync(
      { sub: userId, jti, fam: familyId, typ: "refresh" },
      { secret: REFRESH_SECRET(), expiresIn: REFRESH_TTL_SEC() }
    );
    await this.rls.system((tx) =>
      tx.refreshToken.create({
        data: {
          userId,
          familyId,
          tokenHash: sha256(refreshToken),
          expiresAt: new Date(Date.now() + REFRESH_TTL_SEC() * 1000),
        },
      })
    );
    return { accessToken, refreshToken, tokenType: "Bearer", expiresIn: ACCESS_TTL_SEC() };
  }

  /**
   * Rotating refresh: each refresh token is single-use. Presenting an
   * already-used token is a replay → the ENTIRE token family is revoked
   * (reuse detection) and the caller must re-authenticate.
   */
  async refresh(refreshToken: string): Promise<{ user: User; tokens: TokenPair }> {
    let payload: { sub: string; jti: string; fam: string; typ?: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, { secret: REFRESH_SECRET() });
    } catch {
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }
    if (payload.typ !== "refresh") {
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }

    const hash = sha256(refreshToken);
    const row = await this.rls.system((tx) =>
      tx.refreshToken.findUnique({ where: { tokenHash: hash } })
    );
    if (!row) {
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }
    if (row.revokedAt || row.usedAt) {
      // REUSE DETECTED → revoke the whole family.
      await this.rls.system((tx) =>
        tx.refreshToken.updateMany({
          where: { familyId: row.familyId, revokedAt: null },
          data: { revokedAt: new Date() },
        })
      );
      this.logger.warn(`Refresh token reuse detected — family revoked (user ${row.userId.slice(0, 6)}…)`);
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }
    if (row.expiresAt < new Date()) {
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }

    const user = await this.rls.system((tx) => tx.user.findUnique({ where: { id: payload.sub } }));
    if (!user) {
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }

    // rotate: burn the old token, mint a new one in the same family
    await this.rls.system((tx) =>
      tx.refreshToken.update({ where: { id: row.id }, data: { usedAt: new Date() } })
    );
    const accessToken = await this.signAccess(user.id);
    const jti = randomUUID();
    const nextRefresh = await this.jwt.signAsync(
      { sub: user.id, jti, fam: row.familyId, typ: "refresh" },
      { secret: REFRESH_SECRET(), expiresIn: REFRESH_TTL_SEC() }
    );
    await this.rls.system((tx) =>
      tx.refreshToken.create({
        data: {
          userId: user.id,
          familyId: row.familyId,
          tokenHash: sha256(nextRefresh),
          expiresAt: new Date(Date.now() + REFRESH_TTL_SEC() * 1000),
        },
      })
    );

    return {
      user: toDomainUser(user as never),
      tokens: { accessToken, refreshToken: nextRefresh, tokenType: "Bearer", expiresIn: ACCESS_TTL_SEC() },
    };
  }

  /** Logout — revoke the presented token's family (access tokens expire in 15m). */
  async logout(refreshToken?: string): Promise<{ ok: true }> {
    if (refreshToken) {
      const hash = sha256(refreshToken);
      const row = await this.rls.system((tx) =>
        tx.refreshToken.findUnique({ where: { tokenHash: hash } })
      );
      if (row) {
        await this.rls.system((tx) =>
          tx.refreshToken.updateMany({
            where: { familyId: row.familyId, revokedAt: null },
            data: { revokedAt: new Date() },
          })
        );
      }
    }
    return { ok: true };
  }
}
