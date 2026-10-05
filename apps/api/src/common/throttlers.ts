import type { ExecutionContext } from "@nestjs/common";
import type { ThrottlerOptions } from "@nestjs/throttler";

/**
 * Named rate limits (ThrottlerModule.forRoot). @nestjs/throttler v6 runs
 * EVERY named throttler on EVERY route and, without its own getTracker, keys
 * each one by the guard's tracker — so the OTP-only ones scope themselves by
 * URL (skipIf) and every one names what it counts (getTracker).
 *
 * Security review 2026-10-05: the "ip" throttler was keyed phone@ip on the
 * OTP route, so one IP could send codes to any number of phones (SMS
 * pumping), and a phone could be guessed at ~15 codes / 10 min forever.
 *
 *   ip            every route, per IP              600 / min
 *   otp-phone     code sends, per phone            5 / 10 min
 *   otp-phone-day code sends, per phone            10 / day
 *   otp-ip        code sends, per IP               60 / hour (BD mobile
 *                 data shares IPs behind CGNAT — a sign-in is rare per person)
 *   otp-verify    code checks, per phone           30 / day (the DB allows
 *                 5 tries per code; this caps guessing across codes)
 *   join-ip       referral landing, per IP         20 / min (codes are
 *                 sequential — slows walking them)
 */

const OTP_SEND = ["/auth/otp/request", "/me/phone/request"];
const OTP_VERIFY = ["/auth/otp/verify", "/me/phone/verify"];

const urlOf = (ctx: ExecutionContext) => ctx.switchToHttp().getRequest<{ url?: string }>()?.url ?? "";
const onRoutes = (routes: string[]) => (ctx: ExecutionContext) => !routes.some((r) => urlOf(ctx).includes(r));

type Req = { ip?: string; body?: { phone?: unknown } };
const ipOf = (req: Record<string, unknown>) => `ip:${(req as Req).ip ?? "unknown"}`;
const phoneOf = (req: Record<string, unknown>) => {
  const p = (req as Req).body?.phone;
  return typeof p === "string" ? p.replace(/[^\d+]/g, "") : "none";
};

const n = (v: string | undefined, d: number) => Number(v || d);

export function throttlers(): ThrottlerOptions[] {
  const env = process.env;
  return [
    { name: "ip", ttl: 60_000, limit: n(env.THROTTLE_IP_PER_MIN, 600), getTracker: ipOf },
    {
      name: "otp-phone",
      ttl: 600_000,
      limit: n(env.THROTTLE_OTP_PER_10MIN, 5),
      skipIf: onRoutes(OTP_SEND),
      getTracker: (req) => `otp-phone:${phoneOf(req)}`,
    },
    {
      name: "otp-phone-day",
      ttl: 86_400_000,
      limit: n(env.THROTTLE_OTP_PER_DAY, 10),
      skipIf: onRoutes(OTP_SEND),
      getTracker: (req) => `otp-phone-day:${phoneOf(req)}`,
    },
    {
      name: "otp-ip",
      ttl: 3_600_000,
      limit: n(env.THROTTLE_OTP_IP_PER_HOUR, 60),
      skipIf: onRoutes(OTP_SEND),
      getTracker: (req) => `otp-${ipOf(req)}`,
    },
    {
      // the public referral landing — member codes are sequential
      name: "join-ip",
      ttl: 60_000,
      limit: n(env.THROTTLE_JOIN_PER_MIN, 20),
      skipIf: onRoutes(["/api/join"]),
      getTracker: (req) => `join-${ipOf(req)}`,
    },
    {
      name: "otp-verify",
      ttl: 86_400_000,
      limit: n(env.THROTTLE_OTP_VERIFY_PER_DAY, 30),
      skipIf: onRoutes(OTP_VERIFY),
      getTracker: (req) => `otp-verify:${phoneOf(req)}`,
    },
  ];
}
