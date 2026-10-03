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
import { RlsService } from "src/common/rls.service";
import { shouldExposeDevCode } from "src/auth/sms/sms.service";

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let prisma: PrismaService;
let rls: RlsService;

/** OtpCode rows are system-context-only since the W2e RLS tightening — the
 *  spec must clean/seed through the same context the app itself uses. */
const otpCleanup = () => rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: THROWAWAY } }));
const otpSeed = (data: { codeHash: string; attempts: number }) =>
  rls.system((tx) =>
    tx.otpCode.create({
      data: { phone: THROWAWAY, codeHash: data.codeHash, attempts: data.attempts, expiresAt: new Date(Date.now() + 300_000) },
    })
  );

const THROWAWAY = "01799990001"; // never part of the demo dataset

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  prisma = app.get(PrismaService);
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  await otpCleanup();
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

    const rows = await rls.system((tx) => tx.otpCode.findMany({ where: { phone: THROWAWAY } }));
    expect(rows).toHaveLength(1);
    expect(rows[0].codeHash).toBe(createHash("sha256").update(`${THROWAWAY}:${devCode}`).digest("hex"));
    // and it is NOT the plaintext
    expect(rows[0].codeHash).not.toBe(devCode);
    expect(rows[0].codeHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it("4th send within 10 minutes is rate-limited (DB window)", async () => {
    await otpCleanup();
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(200);
    const blocked = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY }).expect(429);
    expect(blocked.body.error).toContain("অনেকবার");
  });
});

describe("POST /api/auth/otp/verify — atomic counter + single-use consume", () => {
  beforeEach(async () => {
    await otpCleanup();
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
    await otpSeed({
      codeHash: createHash("sha256").update(`${THROWAWAY}:999999`).digest("hex"),
      attempts: 5,
    });
    const res = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY, code: "123456" })
      .expect(429);
    expect(res.body.error).toContain("নতুন কোড");
    const row = await rls.system((tx) => tx.otpCode.findFirst({ where: { phone: THROWAWAY } }));
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

describe("PROF-04 — change phone (OTP to the new number) and e-mail", () => {
  const OLD = "01799990002";
  const NEW = "01799990003";

  afterAll(async () => {
    await rls.system((tx) => tx.user.deleteMany({ where: { phone: { in: [OLD, NEW] } } }));
    await rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: { in: [OLD, NEW] } } }));
  });

  it("a member proves the new number, then the account moves to it", async () => {
    const otp = await http().post("/api/auth/otp/request").send({ phone: OLD }).expect(200);
    const signIn = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: OLD, code: otp.body.devCode, name: "ফোন বদল", gender: "M" })
      .expect(200);
    const token = signIn.body.accessToken as string;
    const auth = { Authorization: `Bearer ${token}` };

    // a number another account holds is refused (the demo full admin's)
    await http().post("/api/me/phone/request").set(auth).send({ phone: "01000000001" }).expect(409);

    const sent = await http().post("/api/me/phone/request").set(auth).send({ phone: NEW }).expect(200);
    await http().post("/api/me/phone/verify").set(auth).send({ phone: NEW, code: "000000" }).expect(400);
    const done = await http()
      .post("/api/me/phone/verify")
      .set(auth)
      .send({ phone: NEW, code: sent.body.devCode })
      .expect(200);
    expect(done.body.user.phone).toBe(NEW);

    // e-mail: normalised, invalid refused, empty clears
    const mail = await http().patch("/api/me").set(auth).send({ email: "Name@Example.COM" }).expect(200);
    expect(mail.body.user.email).toBe("name@example.com");
    await http().patch("/api/me").set(auth).send({ email: "not-an-email" }).expect(400);
    const cleared = await http().patch("/api/me").set(auth).send({ email: "" }).expect(200);
    expect(cleared.body.user.email).toBeNull();
  });
});

describe("sign-in never fails on the phone's guest leftovers", () => {
  const PHONE = "01799990021";

  afterAll(async () => {
    await rls.system((tx) => tx.user.deleteMany({ where: { phone: PHONE } }));
    await rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: PHONE } }));
  });

  it("gender 'unspecified' + a cleared diary row → signs in gender-less; the good row merges", async () => {
    const otp = await http().post("/api/auth/otp/request").send({ phone: PHONE }).expect(200);
    const today = new Date().toISOString().slice(0, 10);
    const res = await http()
      .post("/api/auth/otp/verify")
      .send({
        phone: PHONE,
        code: otp.body.devCode,
        name: "অতিথি নাম",
        gender: "unspecified",
        guestEntries: [
          { amalKey: "salat_fajr", date: today, value: "", clientUpdatedAt: new Date().toISOString() }, // cleared
          { amalKey: "salat_dhuhr", date: today, value: null, clientUpdatedAt: new Date().toISOString() },
          { amalKey: "salat_asr", date: today, value: "jamaat", clientUpdatedAt: new Date().toISOString() },
          { nonsense: true },
        ],
      })
      .expect(200);
    expect(res.body.user.gender).toBe("unspecified"); // the app runs the completion step
    const rows = await rls.system((tx) => tx.amalEntry.findMany({ where: { userId: res.body.user.id } }));
    expect(rows.map((r) => r.amalKey)).toEqual(["salat_asr"]);
  });

  it("an existing account keeps its name (the guest name on the phone does not overwrite it)", async () => {
    const otp = await http().post("/api/auth/otp/request").send({ phone: PHONE }).expect(200);
    const res = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: PHONE, code: otp.body.devCode, name: "অন্য নাম" })
      .expect(200);
    expect(res.body.user.name).toBe("অতিথি নাম");
  });

  it("validation errors say what is wrong (not the bare 'Bad Request')", async () => {
    const res = await http().post("/api/auth/otp/verify").send({ phone: PHONE, gender: "X" }).expect(400);
    expect(res.body.error).not.toBe("Bad Request");
  });
});
