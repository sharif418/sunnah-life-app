import { Injectable, Logger } from "@nestjs/common";
import { InfobipProvider, MockSmsProvider, SslWirelessProvider, type SmsProvider } from "./sms-providers";

export { type SmsProvider, type SmsSendResult } from "./sms-providers";

/**
 * devCode (the OTP in the response body) is a DEV/DEMO ONLY affordance of the
 * mock provider. It must NEVER appear in production — this pure gate is
 * unit-tested in test/auth-otp.spec.ts.
 */
export function shouldExposeDevCode(providerName: string, nodeEnv: string | undefined): boolean {
  return providerName === "mock" && nodeEnv !== "production";
}

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  private readonly provider: SmsProvider = (() => {
    const provider = process.env.SMS_PROVIDER ?? "mock";
    switch (provider) {
      case "sslwireless": {
        const url = process.env.SMS_SSLWIRELESS_URL ?? "";
        const user = process.env.SMS_SSLWIRELESS_USER ?? "";
        const pass = process.env.SMS_SSLWIRELESS_PASS ?? "";
        if (!url || !user || !pass) {
          // env.validation refuses this in production; dev gets a loud hint.
          this.logger.error(
            `SMS_PROVIDER=sslwireless but credentials missing (SMS_SSLWIRELESS_URL/USER/PASS) — falling back to mock`
          );
          return new MockSmsProvider();
        }
        return new SslWirelessProvider(url, user, pass);
      }
      case "infobip": {
        const url = process.env.SMS_INFOBIP_URL ?? "";
        const key = process.env.SMS_INFOBIP_KEY ?? "";
        if (!url || !key) {
          this.logger.error(
            `SMS_PROVIDER=infobip but credentials missing (SMS_INFOBIP_URL/KEY) — falling back to mock`
          );
          return new MockSmsProvider();
        }
        return new InfobipProvider(url, key);
      }
      default:
        return new MockSmsProvider();
    }
  })();

  get providerName(): string {
    return this.provider.name;
  }

  /** Send the OTP text; the mock provider surfaces the code for dev/demo. */
  async sendOtp(phone: string, code: string): Promise<{ devCode?: string }> {
    const text = `সুন্নাহ লাইফ যাচাইকরণ কোড: ${code}`;
    const result = await this.provider.send(phone, text, code);
    if (!result.ok) {
      this.logger.error("SMS delivery failed", result.providerError);
    }
    // The devCode gate lives HERE — no caller can leak it in production even
    // if a future controller forgets the rule.
    return result.devCode && shouldExposeDevCode(this.provider.name, process.env.NODE_ENV)
      ? { devCode: result.devCode }
      : {};
  }
}
