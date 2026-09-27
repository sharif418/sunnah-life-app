// ─────────────────────────────────────────────────────────────────────────────
// Push transport interface + no-op dev adapter (Task B2).
//
// The transport is the ONLY place that talks to an external push service.
// Two implementations exist:
//   • NoopPushTransport  — default when FCM_SERVICE_ACCOUNT_JSON is absent
//     (the sandbox has no Firebase project): logs what would be sent.
//   • FcmTransport       — FCM HTTP v1 with the OAuth2 client-credentials
//     JWT grant over plain fetch (fcm.transport.ts).
//
// Selection happens once per process in PushService.onModuleInit via
// createPushTransport() — see push.service.ts.
// ─────────────────────────────────────────────────────────────────────────────
import { Logger } from "@nestjs/common";

/** What PushService hands to a transport for one recipient token. */
export interface PushMessage {
  /** FCM registration token. */
  token: string;
  title: string;
  body: string;
  /** String-only data payload (FCM requirement) — includes `deepLink`. */
  data?: Record<string, string>;
  /** Convenience: the deep link URI (also embedded into data by the caller). */
  deepLink?: string;
}

/** Per-token delivery outcome. */
export interface PushSendOutcome {
  token: string;
  ok: boolean;
  /** True when the transport determined the token is stale (404/410 UNREGISTERED). */
  unregister?: boolean;
  error?: string;
}

export interface PushTransport {
  /** "fcm" | "noop" — surfaced in logs/metrics. */
  readonly kind: "fcm" | "noop";
  /** Send one message per token; resolves (never throws) per token. */
  sendAll(messages: PushMessage[]): Promise<PushSendOutcome[]>;
}

/**
 * Dev/sandbox adapter: no Firebase project configured. Logs a single line
 * per send batch so flows remain observable in development, and reports
 * success so queue processors don't retry forever.
 */
export class NoopPushTransport implements PushTransport {
  readonly kind = "noop" as const;
  private readonly logger = new Logger("PushService");

  async sendAll(messages: PushMessage[]): Promise<PushSendOutcome[]> {
    const first = messages[0];
    if (first) {
      this.logger.log(
        `(no-op) would send: ${first.title} / ${first.body}` +
          (messages.length > 1 ? ` (+${messages.length - 1} more)` : "")
      );
    }
    return messages.map((m) => ({ token: m.token, ok: true }));
  }
}
