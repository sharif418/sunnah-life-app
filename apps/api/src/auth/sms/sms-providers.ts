// ─────────────────────────────────────────────────────────────────────────────
// SMS gateway adapters (Phase C/W2b — REAL implementations).
//
//   SMS_PROVIDER=mock        dev/demo only; returns devCode (non-production)
//   SMS_PROVIDER=sslwireless SSL Wireless v3 HTTP API (Bangladesh)
//                            env: SMS_SSLWIRELESS_URL/USER/PASS
//   SMS_PROVIDER=infobip     Infobip SMS HTTP API
//                            env: SMS_INFOBIP_URL/KEY
//
// In production, env.validation REFUSES to boot on SMS_PROVIDER=mock or
// missing credentials for the selected provider — the fallback-to-mock
// behaviour that let anyone log in as anyone is gone.
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

/** SSL Wireless v3 API (https://smsplus.sslwireless.com/api/v3/send-sms). */
@Injectable()
export class SslWirelessProvider implements SmsProvider {
  readonly name = "sslwireless";
  private readonly logger = new Logger(SslWirelessProvider.name);

  constructor(
    private readonly url: string,
    private readonly user: string,
    private readonly pass: string
  ) {}

  async send(phone: string, text: string, csmsId: string): Promise<SmsSendResult> {
    if (!this.url || !this.user || !this.pass) {
      return { ok: false, providerError: "sslwireless_not_configured" };
    }
    try {
      const res = await fetch(this.url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user: this.user,
          pass: this.pass,
          sid: "SUNNAHLIFE",
          msisdn: phone,
          sms: text,
          csms_id: csmsId,
        }),
        signal: AbortSignal.timeout(15_000),
      });
      if (!res.ok) {
        return { ok: false, providerError: `sslwireless_http_${res.status}` };
      }
      const data = (await res.json().catch(() => null)) as {
        smsinfo?: { sms_status?: string; status_code?: string }[] | null;
      } | null;
      const info = data?.smsinfo?.[0];
      const ok = info?.sms_status === "SUCCESS" || info?.status_code === "200";
      if (!ok) {
        this.logger.warn(`sslwireless rejected sms: ${JSON.stringify(info ?? data)}`);
      }
      return { ok };
    } catch (e) {
      return { ok: false, providerError: e instanceof Error ? e.message : "network" };
    }
  }
}

/** Infobip SMS API (POST {base}/sms/2/text/advanced, App KEY auth). */
@Injectable()
export class InfobipProvider implements SmsProvider {
  readonly name = "infobip";
  private readonly logger = new Logger(InfobipProvider.name);

  constructor(
    private readonly url: string,
    private readonly key: string
  ) {}

  async send(phone: string, text: string, _code: string): Promise<SmsSendResult> {
    if (!this.url || !this.key) {
      return { ok: false, providerError: "infobip_not_configured" };
    }
    try {
      const res = await fetch(`${this.url.replace(/\/$/, "")}/sms/2/text/advanced`, {
        method: "POST",
        headers: { Authorization: `App ${this.key}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: [{ destinations: [{ to: phone }], from: "SUNNAHLIFE", text }],
        }),
        signal: AbortSignal.timeout(15_000),
      });
      if (!res.ok) {
        return { ok: false, providerError: `infobip_http_${res.status}` };
      }
      const data = (await res.json().catch(() => null)) as {
        messages?: { status?: { groupId?: number; groupName?: string } }[] | null;
      } | null;
      const group = data?.messages?.[0]?.status?.groupName ?? "";
      const ok = group === "ACCEPTED" || data !== null; // 2xx = queued by Infobip
      if (!ok) {
        this.logger.warn(`infobip rejected sms: ${JSON.stringify(data)}`);
      }
      return { ok };
    } catch (e) {
      return { ok: false, providerError: e instanceof Error ? e.message : "network" };
    }
  }
}
