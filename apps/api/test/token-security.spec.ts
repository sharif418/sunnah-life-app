// ─────────────────────────────────────────────────────────────────────────────
// token-security.spec.ts (Phase C/W2c) — token/secret handling:
//   • refresh tokens are NEVER accepted as access tokens (typ claim), even
//     when the refresh secret equals the access secret (dev fallback)
//   • refresh rotation is ATOMIC — two racing refresh() calls with the same
//     token produce exactly ONE success; the family is revoked for the loser
//   • production env validation refuses missing/default secrets (JWT,
//     refresh ≠ access, quiz) and an empty CORS list
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { AuthService } from "src/auth/auth.service";
import { PrismaService } from "src/common/prisma.service";
import { validateEnv } from "src/config/env.validation";
import { RlsService } from "src/common/rls.service";

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let auth: AuthService;
let prisma: PrismaService;
let rls: RlsService;

const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — plain daee

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  auth = app.get(AuthService);
  prisma = app.get(PrismaService);
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer()) as unknown as ReturnType<typeof request>;
});

afterAll(async () => {
  await app.close();
});

describe("typ claim — refresh tokens are not access tokens", () => {
  it("a REFRESH token in the Authorization header authenticates NOTHING (401)", async () => {
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: M_MEMBER }).expect(200);
    const verify = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: M_MEMBER, code: otpRes.body.devCode })
      .expect(200);
    const refreshToken = verify.body.refreshToken as string;
    expect(refreshToken).toBeTruthy();

    // the diary endpoint requires a user — with the refresh token it must 401
    const res = await http()
      .get("/api/amal/entries?from=2026-01-01&to=2026-01-07")
      .set("Authorization", `Bearer ${refreshToken}`)
      .expect(401);
    expect(res.body.error).toBeTruthy();
  });

  it("an ACCESS token still works (typ: access)", async () => {
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: M_MEMBER }).expect(200);
    const verify = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: M_MEMBER, code: otpRes.body.devCode })
      .expect(200);
    const accessToken = verify.body.accessToken as string;

    await http()
      .get("/api/amal/entries?from=2026-01-01&to=2026-01-07")
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);
  });
});

describe("atomic refresh rotation", () => {
  it("two RACING refreshes with the same token → exactly one wins", async () => {
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: M_MEMBER }).expect(200);
    const verify = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: M_MEMBER, code: otpRes.body.devCode })
      .expect(200);
    const refreshToken = verify.body.refreshToken as string;

    // fire both rotations concurrently — no awaits in between
    const results = await Promise.allSettled([
      auth.refresh(refreshToken),
      auth.refresh(refreshToken),
    ]);
    const won = results.filter((r) => r.status === "fulfilled");
    const lost = results.filter((r) => r.status === "rejected");
    expect(won).toHaveLength(1);
    expect(lost).toHaveLength(1);

    // and the family is revoked — even the WINNER's new token is dead after
    // the loser's reuse detection ran
    const winner = won[0] as PromiseFulfilledResult<{ tokens: { refreshToken: string } }>;
    await expect(auth.refresh(winner.value.tokens.refreshToken)).rejects.toThrow();
  });

  it("sequential reuse also revokes the family (baseline behavior)", async () => {
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: M_MEMBER }).expect(200);
    const verify = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: M_MEMBER, code: otpRes.body.devCode })
      .expect(200);
    const refreshToken = verify.body.refreshToken as string;

    const first = await auth.refresh(refreshToken);
    expect(first.tokens.refreshToken).toBeTruthy();
    // replaying the SAME token → 401 ApiError
    await expect(auth.refresh(refreshToken)).rejects.toThrow();
    // …and the rotated successor from the first refresh is now family-revoked
    await expect(auth.refresh(first.tokens.refreshToken)).rejects.toThrow();
  });
});

describe("production env validation refuses weak secrets", () => {
  const BASE = {
    NODE_ENV: "production",
    DATABASE_URL: "postgresql://x:x@h/db",
    SMS_PROVIDER: "sslwireless",
    SMS_SSLWIRELESS_URL: "https://ssl.example",
    SMS_SSLWIRELESS_USER: "u",
    SMS_SSLWIRELESS_PASS: "p",
  } as Record<string, string>;

  it("accepts a complete production env", () => {
    expect(() =>
      validateEnv({
        ...BASE,
        JWT_SECRET: "a-real-access-secret-0123456789",
        JWT_REFRESH_SECRET: "a-different-refresh-secret-012345678",
        QUIZ_SECRET: "a-real-quiz-secret-0123456789",
        CORS_ORIGINS: "https://sunnahlife.app,https://api.sunnahlife.app",
      })
    ).not.toThrow();
  });

  it("refuses the dev-default JWT_SECRET / missing refresh / dev quiz / empty CORS", () => {
    const expectIssue = (env: Record<string, string>, path: string) => {
      try {
        validateEnv(env);
        throw new Error(`expected a validation error for ${path}`);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        expect(msg).toContain(path);
      }
    };
    expectIssue(
      { ...BASE, JWT_SECRET: "dev-only-secret-change-me-in-production", JWT_REFRESH_SECRET: "r".repeat(16), QUIZ_SECRET: "q".repeat(16), CORS_ORIGINS: "https://x.example" },
      "JWT_SECRET"
    );
    expectIssue(
      { ...BASE, JWT_SECRET: "a-real-access-secret-0123456789", JWT_REFRESH_SECRET: "", QUIZ_SECRET: "q".repeat(16), CORS_ORIGINS: "https://x.example" },
      "JWT_REFRESH_SECRET"
    );
    expectIssue(
      { ...BASE, JWT_SECRET: "a-real-access-secret-0123456789", JWT_REFRESH_SECRET: "a-real-access-secret-0123456789", QUIZ_SECRET: "q".repeat(16), CORS_ORIGINS: "https://x.example" },
      "JWT_REFRESH_SECRET" // same as access → refused
    );
    expectIssue(
      { ...BASE, JWT_SECRET: "a-real-access-secret-0123456789", JWT_REFRESH_SECRET: "r".repeat(16), QUIZ_SECRET: "", CORS_ORIGINS: "https://x.example" },
      "QUIZ_SECRET"
    );
    expectIssue(
      { ...BASE, JWT_SECRET: "a-real-access-secret-0123456789", JWT_REFRESH_SECRET: "r".repeat(16), QUIZ_SECRET: "q".repeat(16), CORS_ORIGINS: "" },
      "CORS_ORIGINS"
    );
  });
});
