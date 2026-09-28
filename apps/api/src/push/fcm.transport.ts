// ─────────────────────────────────────────────────────────────────────────────
// FCM HTTP v1 adapter (Task B2) — plain fetch, NO firebase-admin SDK.
//
// Auth: service-account → OAuth2 jwt-bearer grant (RFC 7523)
// (https://developers.google.com/identity/protocols/oauth2/service-account).
// The RS256 signature is produced with WebCrypto (crypto.subtle), which both
// the node (>= 18) and bun runtimes expose globally — zero new dependencies.
//
// Messages: POST https://fcm.googleapis.com/v1/projects/{project}/messages:send
// one request per registration token, fanned out in small Promise.all
// batches (FCM HTTP v1 has no server-side multicast; the batching just keeps
// the event loop and the token endpoint polite).
//
// Invalid tokens (HTTP 404/410, error_details UNREGISTERED) are reported as
// `unregister: true` — PushService prunes them from DeviceToken.
// ─────────────────────────────────────────────────────────────────────────────
import { Logger } from "@nestjs/common";
import type { PushMessage, PushSendOutcome, PushTransport } from "./push.transport";

const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const FCM_SEND_URL = (project: string) =>
  `https://fcm.googleapis.com/v1/projects/${project}/messages:send`;
/** FCM recommendation: keep concurrent sends modest; we chunk by this size. */
const SEND_BATCH = 25;
/** Refresh the access token a minute before it expires. */
const TOKEN_MARGIN_MS = 60_000;

/** The fields of a Firebase service-account JSON this adapter needs. */
export interface FcmServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Normalized outgoing FCM message (subset — enough for this product). */
export interface FcmOutgoingMessage {
  notification: { title: string; body: string };
  data?: Record<string, string>;
  android?: {
    notification?: { channel_id?: string; icon?: string; default_sound?: boolean };
    priority?: "high" | "normal";
  };
  apns?: {
    payload?: { aps?: { sound?: string; badge?: number } };
  };
}

export function buildFcmMessage(m: PushMessage): { message: { token: string } & FcmOutgoingMessage } {
  const data = m.data ?? (m.deepLink ? { deepLink: m.deepLink } : undefined);
  return {
    message: {
      token: m.token,
      notification: { title: m.title, body: m.body },
      ...(data && Object.keys(data).length ? { data } : {}),
      // Android: route through the app's push channel + drawable icon so the
      // notification looks native even when the app is backgrounded (the
      // Flutter plugin uses the same channel id — AndroidManifest meta-data).
      android: {
        priority: "high",
        notification: {
          channel_id: "sunnah_life_push",
          icon: "ic_notification",
          default_sound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            // Present so iOS badges can be overridden per-message later.
            badge: 1,
          },
        },
      },
    },
  };
}

// ── RS256 JWT (WebCrypto) ────────────────────────────────────────────────────

function base64UrlEncode(bytes: Uint8Array | string): string {
  const buf = typeof bytes === "string" ? Buffer.from(bytes, "utf8") : Buffer.from(bytes);
  return buf.toString("base64url");
}

/** PEM PKCS#8 → DER ArrayBuffer (strip armor + base64-decode). */
function pkcs8PemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Buffer.from(body, "base64");
  // Return a stable copy: Buffer's underlying ArrayBuffer may be a pooled view.
  const out = new ArrayBuffer(der.byteLength);
  new Uint8Array(out).set(der);
  return out;
}

/** Service-account JWT assertion claims (client-credentials grant). */
export function buildJwtClaims(
  clientEmail: string,
  nowSec: number,
  ttlSec = 3600
): { iss: string; scope: string; aud: string; iat: number; exp: number } {
  return {
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: OAUTH_TOKEN_URL,
    iat: nowSec,
    exp: nowSec + ttlSec,
  };
}

/** Sign `header.payload` with RS256 via WebCrypto; returns the full JWT. */
export async function signRsaJwt(
  header: object,
  claims: object,
  privateKeyPem: string
): Promise<string> {
  const algorithm = {
    name: "RSASSA-PKCS1-v1_5",
    hash: "SHA-256",
  } as const;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8PemToDer(privateKeyPem),
    algorithm,
    false,
    ["sign"]
  );
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(claims)
  )}`;
  const signature = await crypto.subtle.sign(
    algorithm,
    key,
    new TextEncoder().encode(unsigned)
  );
  return `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;
}

// ── Adapter ─────────────────────────────────────────────────────────────────

export class FcmTransport implements PushTransport {
  readonly kind = "fcm" as const;
  private readonly logger = new Logger("PushService");

  private accessToken: { token: string; expiresAtMs: number } | null = null;

  constructor(
    private readonly account: FcmServiceAccount,
    private readonly fetchImpl: typeof fetch = fetch
  ) {}

  /** Exchange the service-account JWT for an OAuth2 access token (cached). */
  async getAccessToken(forceRefresh = false): Promise<string> {
    if (!forceRefresh && this.accessToken && this.accessToken.expiresAtMs > Date.now() + TOKEN_MARGIN_MS) {
      return this.accessToken.token;
    }
    const nowSec = Math.floor(Date.now() / 1000);
    const jwt = await signRsaJwt(
      { alg: "RS256", typ: "JWT" },
      buildJwtClaims(this.account.client_email, nowSec),
      this.account.private_key
    );
    const res = await this.fetchImpl(OAUTH_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }).toString(),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`FCM oauth token exchange failed (${res.status}): ${text.slice(0, 300)}`);
    }
    const json = (await res.json()) as { access_token?: string; expires_in?: number };
    if (!json.access_token) throw new Error("FCM oauth response missing access_token");
    this.accessToken = {
      token: json.access_token,
      expiresAtMs: Date.now() + (json.expires_in ?? 3600) * 1000,
    };
    return this.accessToken.token;
  }

  async sendAll(messages: PushMessage[]): Promise<PushSendOutcome[]> {
    const out: PushSendOutcome[] = [];
    for (let i = 0; i < messages.length; i += SEND_BATCH) {
      const batch = messages.slice(i, i + SEND_BATCH);
      const results = await Promise.all(batch.map((m) => this.sendOne(m)));
      out.push(...results);
    }
    return out;
  }

  private async sendOne(m: PushMessage): Promise<PushSendOutcome> {
    try {
      const token = await this.getAccessToken();
      const res = await this.fetchImpl(FCM_SEND_URL(this.account.project_id), {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(buildFcmMessage(m)),
      });
      if (res.ok) return { token: m.token, ok: true };
      const text = await res.text().catch(() => "");
      const unregister =
        (res.status === 404 || res.status === 410) && text.includes("UNREGISTERED");
      // 401 access-token expiry race: one transparent retry with a fresh token.
      if (res.status === 401) {
        const fresh = await this.getAccessToken(true);
        const retry = await this.fetchImpl(FCM_SEND_URL(this.account.project_id), {
          method: "POST",
          headers: {
            Authorization: `Bearer ${fresh}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(buildFcmMessage(m)),
        });
        if (retry.ok) return { token: m.token, ok: true };
        const retryText = await retry.text().catch(() => "");
        this.logger.warn(
          `FCM send failed for token ${m.token.slice(0, 10)}… (${retry.status}): ${retryText.slice(0, 200)}`
        );
        return { token: m.token, ok: false, error: `HTTP ${retry.status}` };
      }
      if (!unregister) {
        this.logger.warn(
          `FCM send failed for token ${m.token.slice(0, 10)}… (${res.status}): ${text.slice(0, 200)}`
        );
      }
      return { token: m.token, ok: false, unregister, error: `HTTP ${res.status}` };
    } catch (e) {
      this.logger.warn(
        `FCM send error for token ${m.token.slice(0, 10)}…: ${e instanceof Error ? e.message : e}`
      );
      return { token: m.token, ok: false, error: e instanceof Error ? e.message : String(e) };
    }
  }
}
