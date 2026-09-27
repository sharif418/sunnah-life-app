// ─────────────────────────────────────────────────────────────────────────────
// SMS gateway adapter seam (mock by default).
// Production swaps SMS_PROVIDER=sslwireless|infobip and sets credentials via
// env; the mock provider returns the dev code in the API response so the
// sandbox/demo can complete the OTP flow (same behaviour as the web mirror).
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from "@nestjs/common";

export interface SmsSendResult {
  ok: boolean;
  /** Present only for the mock provider (dev/demo convenience). */
  devCode?: string;
  providerError?: string;
}

export interface SmsProvider {
  readonly name: string;
  /** Sends the OTP text. Returns ok:false on transport failure. */
  send(phone: string, text: string, code: string): Promise<SmsSendResult>;
}

@Injectable()
export class MockSmsProvider implements SmsProvider {
  readonly name = "mock";
  private readonly logger = new Logger(MockSmsProvider.name);

  async send(phone: string, _text: string, code: string): Promise<SmsSendResult> {
    // Phone is masked — no PII in logs.
    this.logger.log(`[mock-sms] OTP dispatched to ${phone.slice(0, 4)}****${phone.slice(-2)}`);
    return { ok: true, devCode: code };
  }
}

/** SSL Wireless adapter (Bangladesh SMS gateway) — needs credentials via env. */
@Injectable()
export class SslWirelessProvider implements SmsProvider {
  readonly name = "sslwireless";
  constructor(
    private readonly url: string,
    private readonly user: string,
    private readonly pass: string
  ) {}

  async send(phone: string, text: string, code: string): Promise<SmsSendResult> {
    if (!this.url || !this.user || !this.pass) {
      return { ok: false, providerError: "sslwireless_not_configured" };
    }
    try {
      const res = await fetch(this.url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user: this.user, pass: this.pass, sid: "SUNNAHLIFE", msisdn: phone, sms: text, csms_id: code }),
      });
      return { ok: res.ok };
    } catch (e) {
      return { ok: false, providerError: e instanceof Error ? e.message : "network" };
    }
  }
}

/** Infobip adapter — needs INFOBIP_URL + INFOBIP_KEY via env. */
@Injectable()
export class InfobipProvider implements SmsProvider {
  readonly name = "infobip";
  constructor(
    private readonly url: string,
    private readonly key: string
  ) {}

  async send(phone: string, text: string): Promise<SmsSendResult> {
    if (!this.url || !this.key) {
      return { ok: false, providerError: "infobip_not_configured" };
    }
    try {
      const res = await fetch(`${this.url}/sms/2/text/advanced`, {
        method: "POST",
        headers: { Authorization: `App ${this.key}`, "Content-Type": "application/json" },
        body: JSON.stringify({ messages: [{ destinations: [{ to: phone }], from: "SUNNAHLIFE", text }] }),
      });
      return { ok: res.ok };
    } catch (e) {
      return { ok: false, providerError: e instanceof Error ? e.message : "network" };
    }
  }
}
