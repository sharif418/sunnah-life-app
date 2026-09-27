import { Injectable, Logger } from "@nestjs/common";
import { MockSmsProvider } from "./sms-providers";

export { type SmsProvider, type SmsSendResult } from "./sms-providers";

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  private readonly provider = (() => {
    // Adapter selection — production swaps via env, no code change.
    switch (process.env.SMS_PROVIDER) {
      case "sslwireless":
      case "infobip":
        this.logger.warn(`SMS_PROVIDER=${process.env.SMS_PROVIDER} has no credentials in this environment — verify with mock`);
        return new MockSmsProvider();
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
    return result.devCode ? { devCode: result.devCode } : {};
  }
}
