import { Injectable, Logger } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { createHash, randomInt, randomUUID } from "crypto";
import type { Prisma } from "../common/prisma-client";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import { toDomainUser } from "../common/mappers";
import type { User } from "../shared/domain";
import type { GuestEntryDto } from "./dto/auth.dto";
import { SmsService } from "./sms/sms.service";
import { socialConfig } from "./social/social.config";
import { tokenEmail, verifyIdToken } from "./social/jwks";

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

export type SocialProvider = "google" | "apple";

/** Row + whether this sign-in created the account (gender is only honored
 *  at creation — the GENDER RULE shared by OTP and social sign-in). */
interface FindOrCreateResult {
  row: UserRow;
  created: boolean;
}

type UserRow = Parameters<typeof toDomainUser>[0];

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
    // crypto.randomInt — unbiased 6-digit code (Math.random was predictable
    // enough to matter for a login credential).
    const code = String(randomInt(100000, 1000000));
    // The DATABASE never sees the plaintext: sha256(phone:code).
    await this.rls.system((tx) =>
      tx.otpCode.create({
        data: {
          phone: normalized,
          codeHash: sha256(`${normalized}:${code}`),
          expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60000),
        },
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
    // Exhausted codes are dead even for the CORRECT value: the counter
    // limits verification attempts, not just wrong ones.
    if (otp.attempts >= VERIFY_MAX_ATTEMPTS) {
      throw new ApiError(429, "অনেকবার ভুল কোড — নতুন কোড নিন");
    }

    if (otp.codeHash !== sha256(`${normalized}:${code.trim()}`)) {
      // ATOMIC attempt counter: the conditional updateMany increments ONLY
      // while attempts < MAX, so two racing wrong codes cannot both slip past
      // the limit (0 rows updated ⇒ already exhausted ⇒ 429).
      const bumped = await this.rls.system((tx) =>
        tx.otpCode.updateMany({
          where: { id: otp.id, attempts: { lt: VERIFY_MAX_ATTEMPTS } },
          data: { attempts: { increment: 1 } },
        })
      );
      if (bumped.count === 0) {
        throw new ApiError(429, "অনেকবার ভুল কোড — নতুন কোড নিন");
      }
      throw new ApiError(400, "ভুল কোড");
    }

    // ATOMIC consume: the deleteMany IS the lock — exactly one concurrent
    // verify can pass (count ≥ 1); everyone else gets "code expired".
    const consumed = await this.rls.system((tx) =>
      tx.otpCode.deleteMany({ where: { phone: normalized } })
    );
    if (consumed.count === 0) {
      throw new ApiError(400, "কোডটি ইতিমধ্যে ব্যবহৃত হয়েছে — আবার পাঠান");
    }

    // find or create the user (bootstrap context: pre-auth)
    const user = await this.rls.system(async (tx) => {
      let row = await tx.user.findUnique({ where: { phone: normalized } });

      if (!row) {
        const referredById = await AuthService.resolveInviterId(tx, referredByCode);
        row = await tx.user.create({
          data: {
            phone: normalized,
            name: name?.trim() || "ব্যবহারকারী",
            gender: gender === "F" ? "F" : "M", // set once at onboarding; admin-only change later
            referredById,
          },
        });
        // build the referral closure (ancestor paths of inviter + self)
        await AuthService.createReferralClosure(tx, row.id, referredById);
      } else if (name?.trim()) {
        row = await tx.user.update({ where: { id: row.id }, data: { name: name.trim() } });
      }
      return row;
    });

    const domain = toDomainUser(user as never);

    // guest → account data merge (local amal diary entries), run with the new
    // user's own RLS context (shared with social sign-in).
    await this.importGuestEntries(domain, guestEntries);

    const tokens = await this.issueTokens(user.id);
    return { user: domain, tokens };
  }

  // ── Social sign-in (Google + Apple — Task B5) ──────────────────────────────

  /** GET /api/auth/providers — which sign-in buttons the clients should show. */
  providersStatus(): { google: boolean; apple: boolean } {
    return {
      google: socialConfig("google")!.enabled,
      apple: socialConfig("apple")!.enabled,
    };
  }

  /**
   * POST /api/auth/social — verify a provider id_token (JWKS + WebCrypto),
   * then link or create the account.
   *
   * LINKING RULES (the security core):
   *   1. Provider subject id (sub) — strongest link: same IdP identity,
   *      survives email changes and Apple's email-only-on-first-auth.
   *   2. Verified email — the documented link: google requires
   *      email + email_verified=true; Apple only ever returns real verified
   *      addresses. Stored/searched lowercase; one account per email (DB
   *      partial unique index on lower(email)).
   *   3. No match → CREATE: phone = null, email set, role "user", memberCode
   *      null (assigned at daee promotion, exactly like OTP-created users).
   *
   * GENDER RULE (same as OTP): gender comes ONLY from onboarding — the payload
   * may carry it at account CREATION; for an existing account it is IGNORED.
   * A social-created account without gender is stored as "unspecified" and
   * completes the one-time onboarding step via PATCH /api/me (locked after).
   */
  async socialSignIn(
    provider: SocialProvider,
    idToken: string,
    name?: string,
    gender?: "M" | "F",
    referredByCode?: string,
    guestEntries?: GuestEntryDto[]
  ): Promise<VerifyResult> {
    const cfg = socialConfig(provider);
    if (!cfg) {
      throw new ApiError(400, "সঠিক সাইন-ইন পদ্ধতি দিন");
    }
    if (!cfg.enabled) {
      // Provider not configured — the feature is off (env empty ⇒ disabled).
      throw new ApiError(400, "এই সাইন-ইন পদ্ধতি এখন চালু নেই");
    }
    if (!idToken || typeof idToken !== "string") {
      throw new ApiError(400, "সাইন-ইন টোকেন দিন");
    }

    const payload = await verifyIdToken({
      idToken,
      jwksUrl: cfg.jwksUrl,
      alg: cfg.alg,
      issuers: cfg.issuers,
      audiences: cfg.audiences,
    });

    const email = tokenEmail(payload);
    if (provider === "google") {
      if (!email) {
        throw new ApiError(400, "Google অ্যাকাউন্টে ইমেইল নেই — অন্য অ্যাকাউন্ট দিয়ে চেষ্টা করুন");
      }
      if (payload.email_verified !== true) {
        throw new ApiError(400, "Google ইমেইল যাচাই হয়নি — আগে Google-এ ইমেইল নিশ্চিত করুন");
      }
    }
    const sub = typeof payload.sub === "string" && payload.sub ? payload.sub : null;
    if (!email && !sub) {
      // Apple second-auth without a stored identity: nothing to link by.
      throw new ApiError(400, "অ্যাপল অ্যাকাউন্টের ইমেইল পাওয়া যায়নি — অন্য উপায়ে সাইন ইন করুন");
    }
    const tokenName =
      typeof payload.name === "string" && payload.name.trim() ? payload.name.trim() : undefined;

    const { row } = await this.findOrCreateSocialUser({
      provider,
      sub,
      email,
      name: name?.trim() || tokenName,
      gender: gender === "F" ? "F" : gender === "M" ? "M" : "unspecified",
      referredByCode,
    });

    const domain = toDomainUser(row as never);
    await this.importGuestEntries(domain, guestEntries);

    const tokens = await this.issueTokens(row.id);
    return { user: domain, tokens };
  }

  /** Link-or-create under the system (auth bootstrap) context. */
  private async findOrCreateSocialUser(input: {
    provider: SocialProvider;
    sub: string | null;
    email: string | null;
    name?: string;
    gender: string;
    referredByCode?: string;
  }): Promise<FindOrCreateResult> {
    const attempt = async (): Promise<FindOrCreateResult> =>
      this.rls.system(async (tx) => {
        // 1) Same provider identity (sub) — the stable key.
        let row = input.sub
          ? await tx.user.findFirst({
              where: { socialProvider: input.provider, socialSub: input.sub },
            })
          : null;

        if (!row) {
          // Linking rule: an account is only ever CREATED from a verified
          // email (phone stays null, email set). An Apple token with no email
          // AND no previously-stored sub (e.g. server DB loss) cannot create
          // one — the user must sign in another way first.
          if (!input.email) {
            throw new ApiError(400, "অ্যাপল অ্যাকাউন্টের ইমেইল পাওয়া যায়নি — অন্য উপায়ে সাইন ইন করুন");
          }
          // 2) Verified email (stored lowercase — one account per email).
          row = await tx.user.findFirst({ where: { email: input.email } });
          if (!row) {
            // 3) Create. GENDER RULE: only honored here, at creation.
            const referredById = await AuthService.resolveInviterId(tx, input.referredByCode);
            row = await tx.user.create({
              data: {
                phone: null,
                email: input.email,
                socialProvider: input.provider,
                socialSub: input.sub,
                name: input.name || "ব্যবহারকারী",
                gender: input.gender,
                referredById,
              },
            });
            await AuthService.createReferralClosure(tx, row.id, referredById);
            return { row: row as unknown as UserRow, created: true };
          }
        }

        // Existing account: stamp the social identity (and the email when it
        // was still empty) so future sign-ins link directly. A gender in the
        // payload is deliberately IGNORED (locked after creation).
        const patch: { email?: string; socialProvider?: string; socialSub?: string } = {};
        if (input.sub && (row.socialSub !== input.sub || row.socialProvider !== input.provider)) {
          patch.socialProvider = input.provider;
          patch.socialSub = input.sub;
        }
        if (input.email && !row.email) {
          patch.email = input.email;
        }
        if (Object.keys(patch).length) {
          row = await tx.user.update({ where: { id: row.id }, data: patch });
        }
        return { row: row as unknown as UserRow, created: false };
      });

    const result = await attempt().catch((err: { code?: string }) => {
      // Concurrent sign-in race: the partial unique indexes fired — the
      // account exists now, so the retry finds it and links instead.
      if (err && err.code === "P2002") {
        return attempt();
      }
      throw err;
    });
    return result;
  }

  // ── Shared helpers (OTP + social) ───────────────────────────────────────────

  /** referredByCode (DS-XXXXXX) → inviter user id, null when unknown/absent. */
  private static async resolveInviterId(
    tx: Prisma.TransactionClient,
    referredByCode?: string
  ): Promise<string | null> {
    if (!referredByCode) return null;
    const inviter = await tx.user.findUnique({
      where: { memberCode: referredByCode.toUpperCase() },
    });
    return inviter?.id ?? null;
  }

  /** ReferralClosure rows for a new user: inviter's ancestor paths + the
   *  direct (depth 1) edge — shared by OTP and social sign-in. */
  private static async createReferralClosure(
    tx: Prisma.TransactionClient,
    createdId: string,
    referredById: string | null
  ): Promise<void> {
    if (!referredById) return;
    const inviterRows = await tx.referralClosure.findMany({ where: { descendantId: referredById } });
    await tx.referralClosure.createMany({
      data: [
        ...inviterRows.map((r) => ({
          ancestorId: r.ancestorId,
          descendantId: createdId,
          depth: r.depth + 1,
        })),
        { ancestorId: referredById, descendantId: createdId, depth: 1 },
      ],
    });
  }

  /**
   * Guest → account data merge (local amal diary entries), run with the new
   * user's own RLS context. Natural key (userId, amalKey, date); latest
   * clientUpdatedAt wins (offline-sync rule). Shared by OTP + social sign-in.
   */
  private async importGuestEntries(
    domain: User,
    guestEntries?: GuestEntryDto[]
  ): Promise<void> {
    if (!guestEntries?.length) return;
    await this.rls.run(domain, async (tx) => {
      for (const e of guestEntries.slice(0, 500)) {
        const incoming = new Date(e.clientUpdatedAt);
        if (isNaN(incoming.getTime())) continue;
        const existing = await tx.amalEntry.findUnique({
          where: { userId_amalKey_date: { userId: domain.id, amalKey: e.amalKey, date: e.date } },
        });
        if (!existing || existing.clientUpdatedAt < incoming) {
          await tx.amalEntry.upsert({
            where: { userId_amalKey_date: { userId: domain.id, amalKey: e.amalKey, date: e.date } },
            create: {
              userId: domain.id,
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


  // ── Token issuance / rotation ─────────────────────────────────────────────

  private async signAccess(userId: string): Promise<string> {
    return this.jwt.signAsync(
      // typ separates access from refresh credentials: the auth guard
      // refuses refresh tokens presented as access tokens (Phase C/W2c).
      { sub: userId, typ: "access" },
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

    // ROTATE ATOMICALLY: the conditional updateMany IS the lock — two racing
    // refresh() calls with the same token cannot both win; the loser sees
    // 0 rows and the flow above already treats a used token as family-reuse
    // (revoking the whole family). [Phase C/W2c]
    const burned = await this.rls.system((tx) =>
      tx.refreshToken.updateMany({
        where: { id: row.id, usedAt: null, revokedAt: null },
        data: { usedAt: new Date() },
      })
    );
    if (burned.count === 0) {
      // lost the race — someone else consumed it between the read and the
      // burn. Same response as any reuse: family revoked.
      await this.rls.system((tx) =>
        tx.refreshToken.updateMany({
          where: { familyId: row.familyId, revokedAt: null },
          data: { revokedAt: new Date() },
        })
      );
      this.logger.warn(`Refresh rotation race — family revoked (user ${row.userId.slice(0, 6)}…)`);
      throw new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার সাইন ইন করুন");
    }
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
