// ─────────────────────────────────────────────────────────────────────────────
// auth-otp.spec.ts (Phase C/W2b) — the audit's second production blocker:
// "Anyone can log in as anyone" (mock-only SMS + devCode in the response).
//
// Hardening under test:
//   • OTP generated with crypto.randomInt (6 digits) and stored HASHED —
//     sha256(phone:code); the plaintext never touches the DB
//   • ATOMIC attempt counter (conditional updateMany) — the 5th wrong code
//     flips to 429 even under races; attempt #5 itself still answers 400
//   • ATOMIC consume — the deleteMany is the lock; a second verify with the
//     same code is rejected
//   • devCode gating (shouldExposeDevCode) — mock+non-production only
//   • send-window 429 (DB rule) still enforced
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { createHash } from "crypto";

import { AppModule } from "src/app.module";
import { PrismaService } from "src/common/prisma.service";
import { shouldExposeDevCode } from "src/auth/sms/sms.service";

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let prisma: PrismaService;

const THROWAWAY = "01799990001"; // never part of the demo dataset

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  prisma = app.get(PrismaService);
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  await prisma.otpCode.deleteMany({ where: { phone: THROWAWAY } });
  await app.close();
});

describe("shouldExposeDevCode — the pure gate", () => {
  it("mock + non-production → exposed", () => {
    expect(shouldExposeDevCode("mock", "development")).toBe(true);
    expect(shouldExposeDevCode("mock", "test")).toBe(true);
    expect(shouldExposeDevCode("mock", undefined)).toBe(true);
  });
  it("mock + production → NEVER; real providers → never anywhere", () => {
    expect(shouldExposeDevCode("mock", "production")).toBe(false);
    expect(shouldExposeDevCode("sslwireless", "development")).toBe(false);
    expect(shouldExposeDevCode("sslwireless", "production")).toBe(false);
    expect(shouldExposeDevCode("infobip", "test")).toBe(false);
  });
});

describe("POST /api/auth/otp/request — hashed storage", () => {
  it("stores sha256(phone:code), never the plaintext", async () => {
    const res = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const devCode = res.body.devCode as string | undefined;
    // in the test env (NODE_ENV=test, mock provider) the code is exposed
    expect(devCode).toMatch(/^\d{6}$/);

    const rows = await prisma.otpCode.findMany({ where: { phone: THROWAWAY } });
    expect(rows).toHaveLength(1);
    expect(rows[0].codeHash).toBe(createHash("sha256").update(`${THROWAWAY}:${devCode}`).digest("hex"));
    // and it is NOT the plaintext
    expect(rows[0].codeHash).not.toBe(devCode);
    expect(rows[0].codeHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it("4th send within 10 minutes is rate-limited (DB window)", async () => {
    await prisma.otpCode.deleteMany({ where: { phone: THROWAWAY } });
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const blocked = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(429);
    expect(blocked.body.error).toContain("অনেকবার");
  });
});

describe("POST /api/auth/otp/verify — atomic counter + single-use consume", () => {
  beforeEach(async () => {
    await prisma.otpCode.deleteMany({ where: { phone: THROWAWAY } });
  });

  it("a WRONG code counts one attempt; the 6th attempt is a hard 429", async () => {
    const req = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const realCode = req.body.devCode as string;

    // 5 wrong attempts (the max) — each one a 400
    for (let i = 0; i < 5; i++) {
      await http()
        .post("/api/auth/otp/verify")
        .send({ phone: THROWAWAY, code: "000000" === realCode ? "111111" : "000000" })
        .expect(400);
    }
    // the counter is at the limit now — even the CORRECT code is refused 429
    const late = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY, code: realCode })
      .expect(429);
    expect(late.body.error).toContain("নতুন কোড");
  });

  it("attempts=MAX raced through the conditional updateMany → 429 (atomicity)", async () => {
    // seed a row already at the limit; a wrong code must get 429 (not a 400
    // that also bumps the counter past the limit)
    await prisma.otpCode.create({
      data: {
        phone: THROWAWAY,
        codeHash: createHash("sha256").update(`${THROWAWAY}:999999`).digest("hex"),
        attempts: 5,
        expiresAt: new Date(Date.now() + 300_000),
      },
    });
    const res = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY, code: "123456" })
      .expect(429);
    expect(res.body.error).toContain("নতুন কোড");
    const row = await prisma.otpCode.findFirst({ where: { phone: THROWAWAY } });
    expect(row?.attempts).toBe(5); // NOT incremented past the limit
  });

  it("a successful verify CONSUMES the code — replay is rejected", async () => {
    const req = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const code = req.body.devCode as string;

    const first = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY, code })
      .expect(200);
    expect(first.body.accessToken).toBeTruthy();

    // the account was created — clean it up so the suite is repeatable
    await prisma.user.deleteMany({ where: { phone: THROWAWAY } });

    // fresh OTP + consume, then replay the SAME code → rejected
    const req2 = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const code2 = req2.body.devCode as string;
    await http().post("/api/auth/otp/verify").send({ phone: THROWAWAY, code: code2 }).expect(200);
    await prisma.user.deleteMany({ where: { phone: THROWAWAY } });

    const replay = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY, code: code2 })
      .expect(400);
    // the consumed row is GONE — the replay is just "no active code"
    expect(replay.body.error).toContain("কোডের সময় শেষ");
  });
});
