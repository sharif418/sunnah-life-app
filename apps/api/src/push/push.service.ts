// ─────────────────────────────────────────────────────────────────────────────
// PushService — the one fan-out door for push notifications (Task B2).
//
//   send(userIds, payload, {actor})       → resolve DeviceTokens + deliver
//   sendToUsrah(usrahId, payload, opts)   → gender-isolated usrah fan-out
//
// Token resolution ALWAYS runs through RlsService:
//   • actor present  → rls.run(actor): PostgreSQL RLS on DeviceToken means a
//     male head's query physically CANNOT return a female member's tokens,
//     even if membership data drifted (proven against the *_device_tokens
//     migration policy in the sandbox scratch DB).
//   • no actor (worker context) → rls.system() + an application-level gender
//     filter (usrah gender for sendToUsrah) as a second net.
//
// Delivery goes through the transport selected at boot:
//   FCM_SERVICE_ACCOUNT_JSON set (object or file path) → FCM HTTP v1 adapter,
//   otherwise the no-op dev adapter (the sandbox has no Firebase project).
//
// Pruning of UNREGISTERED tokens runs in the system context — it is a
// maintenance write scoped to the fan-out set, mirroring the worker pattern
// (an actor could not delete other users' rows under the RLS WITH CHECK by
// design).
// ─────────────────────────────────────────────────────────────────────────────
import { Injectable, Logger, type OnModuleInit } from "@nestjs/common";
import { readFileSync } from "fs";
import { RlsService } from "../common/rls.service";
import { ApiError } from "../common/api-error";
import type { User, Gender } from "../shared/domain";
import { NoopPushTransport, type PushMessage, type PushTransport } from "./push.transport";
import { FcmTransport, type FcmServiceAccount } from "./fcm.transport";

export interface PushPayload {
  title: string;
  body: string;
  /** Extra string-only data (merged with deepLink). */
  data?: Record<string, string>;
  /** e.g. "sunnahlife://reviews" — see ./deep-links.ts. */
  deepLink?: string;
}

export interface PushSendOptions {
  /** Acting user for RLS token resolution (controllers pass the caller). */
  actor?: User | null;
  /**
   * Application-level gender filter for system-context fan-outs — tokens are
   * only resolved for users of this gender. Used by sendToUsrah (usrah
   * gender) as the second net under the DB policy.
   */
  gender?: Gender;
}

export interface PushOutcome {
  /** Distinct recipient users that had ≥ 1 token. */
  users: number;
  /** Tokens the transport accepted (no-op counts all as sent). */
  sent: number;
  failed: number;
  /** Stale tokens pruned from DeviceToken (FCM 404/410 UNREGISTERED). */
  pruned: number;
  transport: "fcm" | "noop";
}

/**
 * Build the transport from the FCM_SERVICE_ACCOUNT_JSON env value:
 *   • absent/empty → no-op adapter
 *   • JSON object string → parsed directly
 *   • anything else → treated as a file path to the JSON
 * Invalid/missing-field credentials → warn + no-op (never crash the boot;
 * the lead ships the real secret via docs/RELEASE.md).
 */
export function createPushTransport(envValue: string | undefined): PushTransport {
  const logger = new Logger("PushService");
  const raw = (envValue ?? "").trim();
  if (!raw) return new NoopPushTransport();

  const parse = (text: string): FcmServiceAccount => {
    const json = JSON.parse(text) as Partial<FcmServiceAccount>;
    if (
      !json.project_id ||
      !json.client_email ||
      !json.private_key ||
      !json.private_key.includes("PRIVATE KEY")
    ) {
      throw new Error("service account needs project_id, client_email and a PEM private_key");
    }
    return {
      project_id: json.project_id,
      client_email: json.client_email,
      private_key: json.private_key,
    };
  };

  try {
    const account = parse(raw.startsWith("{") ? raw : readFileSync(raw, "utf8"));
    logger.log(`FCM transport ready (project ${account.project_id})`);
    return new FcmTransport(account);
  } catch (e) {
    logger.warn(
      `FCM_SERVICE_ACCOUNT_JSON invalid (${e instanceof Error ? e.message : e}) — falling back to the no-op push transport`
    );
    return new NoopPushTransport();
  }
}

@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger("PushService");
  private transport: PushTransport = new NoopPushTransport();

  constructor(private readonly rls: RlsService) {}

  onModuleInit(): void {
    this.transport = createPushTransport(process.env.FCM_SERVICE_ACCOUNT_JSON);
  }

  /** For tests / manual operators: which transport is live. */
  get transportKind(): "fcm" | "noop" {
    return this.transport.kind;
  }

  /**
   * Fan a payload out to every DeviceToken of the given users.
   * Never throws for delivery failures — per-token errors are logged and
   * counted; the caller's own flow (broadcast, review reminder, …) continues.
   */
  async send(userIds: string[], payload: PushPayload, opts: PushSendOptions = {}): Promise<PushOutcome> {
    const ids = [...new Set(userIds.filter(Boolean))];
    if (!ids.length) {
      return { users: 0, sent: 0, failed: 0, pruned: 0, transport: this.transport.kind };
    }

    const rows = await this.resolveTokens(ids, opts);
    if (!rows.length) {
      return { users: 0, sent: 0, failed: 0, pruned: 0, transport: this.transport.kind };
    }

    const messages: PushMessage[] = rows.map((r) => ({
      token: r.token,
      title: payload.title,
      body: payload.body,
      data: { ...(payload.data ?? {}), ...(payload.deepLink ? { deepLink: payload.deepLink } : {}) },
      deepLink: payload.deepLink,
    }));

    const outcomes = await this.transport.sendAll(messages);
    const unregistered = outcomes.filter((o) => o.unregister).map((o) => o.token);
    const pruned = unregistered.length ? await this.pruneTokens(unregistered) : 0;

    const sent = outcomes.filter((o) => o.ok).length;
    const failed = outcomes.length - sent;
    if (failed) {
      this.logger.warn(
        `push "${payload.title.slice(0, 40)}": ${sent} sent, ${failed} failed` +
          (pruned ? `, ${pruned} pruned` : "")
      );
    }
    return {
      users: new Set(rows.map((r) => r.userId)).size,
      sent,
      failed,
      pruned,
      transport: this.transport.kind,
    };
  }

  /**
   * Usrah fan-out. `respectGenderIsolation` (default true) stamps the
   * caller's context AND filters member tokens to the usrah's gender — the
   * usrah is single-gender by design; this guarantees a male head can never
   * reach a female member's tokens even if a member row drifted genders.
   */
  async sendToUsrah(
    usrahId: string,
    payload: PushPayload,
    opts: { respectGenderIsolation?: boolean; actor?: User | null } = {}
  ): Promise<PushOutcome> {
    const respectGender = opts.respectGenderIsolation !== false;
    const actor = opts.actor;

    // Visibility + member list under the ACTING user's RLS context when one
    // is provided (a head only ever finds their own usrah here).
    const usrah = actor
      ? await this.rls.run(actor, (tx) => tx.usrah.findUnique({ where: { id: usrahId } }))
      : await this.rls.system((tx) => tx.usrah.findUnique({ where: { id: usrahId } }));
    if (!usrah) {
      throw new ApiError(403, "শুধু নিজের উসরার জন্য নোটিফিকেশন পাঠানো যাবে");
    }
    if (
      respectGender &&
      actor &&
      actor.role !== "full_admin" &&
      actor.gender !== usrah.gender
    ) {
      // Invigilators are same-gender scoped (like the broadcast route); only
      // full_admin may cross — and the token rows are still gender-filtered.
      throw new ApiError(403, "বিপরীত লিঙ্গের উসরায় নোটিফিকেশন পাঠানো যাবে না");
    }

    const members = actor
      ? await this.rls.run(actor, (tx) =>
          tx.user.findMany({ where: { usrahId }, select: { id: true } })
        )
      : await this.rls.system((tx) =>
          tx.user.findMany({ where: { usrahId }, select: { id: true } })
        );

    return this.send(
      members.map((m) => m.id),
      payload,
      { actor, gender: respectGender ? (usrah.gender as Gender) : undefined }
    );
  }

  /** Resolve DeviceTokens for the user set under the proper RLS context. */
  private async resolveTokens(
    userIds: string[],
    opts: PushSendOptions
  ): Promise<{ token: string; userId: string }[]> {
    const where = {
      userId: { in: userIds },
      ...(opts.gender ? { user: { gender: opts.gender } } : {}),
    };
    if (opts.actor) {
      return this.rls.run(opts.actor, (tx) =>
        tx.deviceToken.findMany({ where, select: { token: true, userId: true } })
      );
    }
    return this.rls.system((tx) =>
      tx.deviceToken.findMany({ where, select: { token: true, userId: true } })
    );
  }

  /** Delete stale tokens (system context — see file header). */
  private async pruneTokens(tokens: string[]): Promise<number> {
    try {
      const res = await this.rls.system((tx) =>
        tx.deviceToken.deleteMany({ where: { token: { in: tokens } } })
      );
      if (res.count) this.logger.log(`pruned ${res.count} unregistered device token(s)`);
      return res.count;
    } catch (e) {
      this.logger.warn(`token prune failed: ${e instanceof Error ? e.message : e}`);
      return 0;
    }
  }
}
