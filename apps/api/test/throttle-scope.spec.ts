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

beforeAll(async () => {
  process.env.THROTTLE_OTP_PER_10MIN = String(OTP_CAP);
  const { AppModule } = await import("src/app.module");
  const { RlsService } = await import("src/common/rls.service");
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "health/live", "health/ready", "metrics"] });
  await app.init();
  await app.listen(0);
  const rls = app.get(RlsService);
  otpCleanup = () => rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: THROWAWAY } }));
  await otpCleanup();
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  await otpCleanup();
  await app.close();
  // jest --runInBand shares process.env across spec files — restore it.
  if (previousOtpCap === undefined) delete process.env.THROTTLE_OTP_PER_10MIN;
  else process.env.THROTTLE_OTP_PER_10MIN = previousOtpCap;
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
});
