// ─────────────────────────────────────────────────────────────────────────────
// throttle-scope.spec.ts — regression for the staging outage of 2026-09-30.
//
// @nestjs/throttler v6 applies EVERY named throttler to EVERY route. The
// 5-per-10-min "otp-phone" cap therefore rate-limited all traffic by IP:
// Docker's /health/live probe got 429 after five polls, the container went
// unhealthy and Coolify's Traefik dropped the api ("no available server").
//
// Pinned here:
//   • /health/live and a normal product route never 429 under repeated calls
//     from one IP (well past the OTP cap)
//   • the OTP request route is still capped by the otp-phone throttler
//
// The OTP cap is lowered to 3 for this file only (read when AppModule is
// first evaluated — hence the dynamic import after setting the env).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

const OTP_CAP = 3;
const THROWAWAY = "01799990002"; // never part of the demo dataset

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let otpCleanup: () => Promise<unknown>;
const previousOtpCap = process.env.THROTTLE_OTP_PER_10MIN;
const OTP_IP_CAP = 8;
const VERIFY_CAP = 3;
const PUMP_PREFIX = "0179999"; // 01799990100.. one code each, never real
const previousEnv = {
  THROTTLE_OTP_IP_PER_HOUR: process.env.THROTTLE_OTP_IP_PER_HOUR,
  THROTTLE_OTP_VERIFY_PER_DAY: process.env.THROTTLE_OTP_VERIFY_PER_DAY,
};

beforeAll(async () => {
  process.env.THROTTLE_OTP_PER_10MIN = String(OTP_CAP);
  process.env.THROTTLE_OTP_IP_PER_HOUR = String(OTP_IP_CAP);
  process.env.THROTTLE_OTP_VERIFY_PER_DAY = String(VERIFY_CAP);
  const { AppModule } = await import("src/app.module");
  const { RlsService } = await import("src/common/rls.service");
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "health/live", "health/ready", "metrics"] });
  await app.init();
  await app.listen(0);
  const rls = app.get(RlsService);
  otpCleanup = () =>
    rls.system((tx) =>
      tx.otpCode.deleteMany({ where: { OR: [{ phone: THROWAWAY }, { phone: { startsWith: `${PUMP_PREFIX}01` } }] } })
    );
  await otpCleanup();
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  await otpCleanup();
  await app.close();
  // jest --runInBand shares process.env across spec files — restore it.
  if (previousOtpCap === undefined) delete process.env.THROTTLE_OTP_PER_10MIN;
  else process.env.THROTTLE_OTP_PER_10MIN = previousOtpCap;
  for (const [k, v] of Object.entries(previousEnv)) {
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
});

describe("throttler scope", () => {
  it("GET /health/live never 429s (probes poll every few seconds)", async () => {
    for (let i = 0; i < 20; i++) {
      await http().get("/health/live").expect(200);
    }
  });

  it("a normal product route is not capped by the OTP throttler", async () => {
    for (let i = 0; i < 20; i++) {
      const res = await http().get("/api/config");
      expect(res.status).not.toBe(429);
    }
  });

  it("POST /api/auth/otp/request is still capped per phone", async () => {
    const statuses: number[] = [];
    const bodies: string[] = [];
    for (let i = 0; i < OTP_CAP + 2; i++) {
      const res = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY });
      statuses.push(res.status);
      bodies.push(JSON.stringify(res.body));
    }
    // Past the cap the throttler itself answers (not the DB send-window rule).
    expect(statuses[OTP_CAP]).toBe(429);
    expect(bodies[OTP_CAP]).toContain("ThrottlerException");
  });

  it("one IP cannot send codes to an unlimited number of phones (SMS pumping)", async () => {
    // the per-phone test above already used some of this IP's budget
    const statuses: number[] = [];
    for (let i = 0; i < OTP_IP_CAP + 2; i++) {
      const res = await http()
        .post("/api/auth/otp/request")
        .send({ phone: `${PUMP_PREFIX}01${String(i).padStart(2, "0")}` });
      statuses.push(res.status);
    }
    expect(statuses[0]).toBe(200);
    expect(statuses).toContain(429);
  });

  it("code guesses for one phone are capped per day across codes", async () => {
    const statuses: number[] = [];
    for (let i = 0; i < VERIFY_CAP + 1; i++) {
      const res = await http().post("/api/auth/otp/verify").send({ phone: THROWAWAY, code: "000000" });
      statuses.push(res.status);
    }
    expect(statuses.slice(0, VERIFY_CAP)).not.toContain(429);
    expect(statuses[VERIFY_CAP]).toBe(429);
  });
});

