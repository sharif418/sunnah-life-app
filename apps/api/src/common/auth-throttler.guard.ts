import { Injectable } from "@nestjs/common";
import { ThrottlerGuard } from "@nestjs/throttler";

/**
 * Auth-aware rate limiting (Phase C/W2b):
 *
 *   • POST /api/auth/otp/request → tracked PER PHONE (+ ip suffix):
 *     5 requests / 10 min (on top of the DB-backed 3 sends / 10 min window —
 *     the DB rule counts what was STORED, this one counts every attempt,
 *     including phones that never pass validation).
 *   • everything else → PER IP: 600 req / min (env THROTTLE_IP_PER_MIN;
 *     generous because a legit phone user makes many calls, but a flood
 *     still gets 429).
 *
 * Both named throttlers are declared in AppModule (ThrottlerModule.forRoot);
 * the otp-phone one is scoped to the OTP route there via skipIf.
 */
@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    const http = req as unknown as {
      url?: string;
      ip?: string;
      body?: { phone?: unknown };
    };
    const isOtpRequest = typeof http.url === "string" && http.url.includes("/auth/otp/request");
    if (isOtpRequest && http.body && typeof http.body.phone === "string") {
      const phone = http.body.phone.replace(/[^\d+]/g, "");
      return `phone:${phone}@${http.ip ?? "unknown"}`;
    }
    return `ip:${http.ip ?? "unknown"}`;
  }

}
