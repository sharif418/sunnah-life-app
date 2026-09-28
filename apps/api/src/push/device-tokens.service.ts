// ─────────────────────────────────────────────────────────────────────────────
// Device-token registration service (Task B2).
//
// POST /api/push/token  — upsert (userId, token), refresh lastSeenAt, cap the
// per-user device list (MAX_TOKENS_PER_USER); a token registered by a new user
// is first taken over from every other user (system context — FCM delivers
// to the device, so stale previous-owner rows would leak notifications across
// accounts). DELETE — unregister on logout.
//
// All writes run through RlsService.run(user): PostgreSQL RLS on DeviceToken
// only ever allows a user to touch their OWN rows (WITH CHECK), so a stolen
// token cannot be transplanted onto another account.
// ─────────────────────────────────────────────────────────────────────────────
import { Injectable } from "@nestjs/common";
import { ApiError } from "../common/api-error";
import { RlsService } from "../common/rls.service";
import type { User } from "../shared/domain";

/** Keep at most this many devices per user (oldest lastSeenAt evicted). */
export const MAX_TOKENS_PER_USER = 5;

const PLATFORMS = ["android", "ios"] as const;
type Platform = (typeof PLATFORMS)[number];

export interface RegisterTokenInput {
  token: string;
  platform: string;
}

/**
 * Pure helper (unit-tested): given a user's token rows, return the ids that
 * must be DELETED to honor the cap — everything beyond the newest `cap`
 * rows by lastSeenAt (ties broken by id for determinism).
 */
export function selectTokensToEvict(
  rows: { id: string; lastSeenAt: Date }[],
  cap: number = MAX_TOKENS_PER_USER
): string[] {
  const sorted = [...rows].sort(
    (a, b) => b.lastSeenAt.getTime() - a.lastSeenAt.getTime() || (a.id < b.id ? -1 : 1)
  );
  return sorted.slice(Math.max(0, cap)).map((r) => r.id);
}

@Injectable()
export class DeviceTokensService {
  constructor(private readonly rls: RlsService) {}

  /** Upsert the (user, token) pair + enforce the device cap. Auth required. */
  async register(user: User | null, input: RegisterTokenInput): Promise<{ ok: true }> {
    if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");

    const token = (input.token ?? "").toString().trim();
    // FCM registration tokens are opaque 140–250ish-char strings; the bounds
    // just reject obvious garbage without coupling to Google's format.
    if (token.length < 64 || token.length > 512) {
      throw new ApiError(400, "ডিভাইস টোকেনটি সঠিক নয়");
    }
    const platform = (PLATFORMS as readonly string[]).includes(input.platform)
      ? (input.platform as Platform)
      : "android";
    if (!PLATFORMS.includes(platform)) throw new ApiError(400, "প্ল্যাটফর্ম সঠিক নয়");

    // A device switching accounts takes its token with it: FCM delivers to
    // the DEVICE, so a leftover previous-owner row would leak their
    // notifications to the new account. Cross-user deletes are impossible
    // under the user's own RLS context (by design) — a maintenance write,
    // so it runs in the system context (the PushService.pruneTokens pattern).
    await this.rls.system((tx) =>
      tx.deviceToken.deleteMany({ where: { token, userId: { not: user.id } } })
    );
    const now = new Date();
    await this.rls.run(user, async (tx) => {
      await tx.deviceToken.upsert({
        where: { userId_token: { userId: user.id, token } },
        create: { userId: user.id, token, platform, lastSeenAt: now, updatedAt: now },
        update: { platform, lastSeenAt: now, updatedAt: now },
      });
      const rows = await tx.deviceToken.findMany({
        where: { userId: user.id },
        select: { id: true, lastSeenAt: true },
      });
      const evict = selectTokensToEvict(rows);
      if (evict.length) {
        await tx.deviceToken.deleteMany({ where: { id: { in: evict } } });
      }
    });
    return { ok: true };
  }

  /** Remove one token (device logout / FCM refresh before re-register). */
  async unregister(user: User | null, token: string): Promise<{ ok: true }> {
    if (!user) throw new ApiError(401, "সাইন ইন প্রয়োজন");
    const t = (token ?? "").toString().trim();
    if (!t) throw new ApiError(400, "ডিভাইস টোকেনটি সঠিক নয়");
    await this.rls.run(user, (tx) =>
      tx.deviceToken.deleteMany({ where: { userId: user.id, token: t } })
    );
    return { ok: true };
  }
}
