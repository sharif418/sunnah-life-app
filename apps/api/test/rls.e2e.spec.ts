// ─────────────────────────────────────────────────────────────────────────────
// RLS e2e — THE privacy proof (client-mandated spec).
//
// Female usrah head (01000000005) calls the test-only raw endpoint
// (/api/test/rls-raw, header x-rls-raw-test: 1) whose handler runs
// prisma.amalEntry.findMany/count({ where: { userId: <male member> } })
// with NO application-level gender filter, inside her own RLS context.
// PostgreSQL must return 0 rows — the database itself refuses. The same
// access through the standard endpoint (/api/amal/entries?userId=…) must
// fail with the 403 gender error. Then the exact mirror case for the male
// usrah head (01000000003) against a female member.
//
// Positive controls prove the zeros are RLS scoping, not emptiness:
// the F head DOES see her own (female) member's rows through the same raw
// endpoint, and without the test header the probe is disabled (404).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

const F_HEAD = "01000000005"; // উম্মে হাবিবা — head of উসরা আয়েশা সিদ্দিকা (F)
const M_HEAD = "01000000003"; // মাওলানা ইউসুফ — head of উসরা আল-ফুরকান (M)
const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — male member of আল-ফুরকান
const F_MEMBER = "01000000006"; // মারিয়াম হাসান — female member of আয়েশা সিদ্দিকা
const FULL_ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন

const GENDER_ERR = "বিপরীত লিঙ্গের তথ্য দেখার অনুমতি নেই";

let app: INestApplication;
let http: () => ReturnType<typeof request>;
// Module scope: shared by both describe blocks below.
let adminToken: string;
let maleMemberId: string;
let femaleMemberId: string;

/** Full OTP sign-in → access token (mock SMS surfaces devCode). */
async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const devCode: string = otpRes.body.devCode;
  expect(devCode).toBeTruthy();
  const verifyRes = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: devCode })
    .expect(200);
  expect(verifyRes.body.user.phone).toBe(phone);
  return verifyRes.body.accessToken as string;
}

/** Look up a demo user's id via the admin console API (full_admin). */
async function userIdByPhone(adminToken: string, phone: string): Promise<string> {
  const res = await http()
    .get(`/api/admin/users?q=${phone}`)
    .set("Authorization", `Bearer ${adminToken}`)
    .expect(200);
  const hit = (res.body.users as { id: string; phone: string | null }[]).find(
    (u) => u.phone === phone
  );
  expect(hit).toBeTruthy();
  return hit!.id;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  await app.close();
});

describe("RLS e2e — the database refuses cross-gender reads", () => {
  beforeAll(async () => {
    adminToken = await signIn(FULL_ADMIN);
    maleMemberId = await userIdByPhone(adminToken, M_MEMBER);
    femaleMemberId = await userIdByPhone(adminToken, F_MEMBER);
  });

  it("FEMALE head → raw unfiltered query for a MALE member returns 0 rows (DB-level refusal)", async () => {
    const token = await signIn(F_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw?userId=${maleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    // findMany without app-level filters — PostgreSQL policy hides him.
    expect(res.body.rows).toBe(0);
    expect(res.body.count).toBe(0);
  });

  it("FEMALE head → standard endpoint returns 403 with the gender error", async () => {
    const token = await signIn(F_HEAD);
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 29 * 86400_000).toISOString().slice(0, 10);
    const res = await http()
      .get(`/api/amal/entries?from=${from}&to=${today}&userId=${maleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
    expect(res.body.error).toBe(GENDER_ERR);
  });

  it("MALE head → raw unfiltered query for a FEMALE member returns 0 rows (mirror case)", async () => {
    const token = await signIn(M_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw?userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.rows).toBe(0);
    expect(res.body.count).toBe(0);
  });

  it("MALE head → standard endpoint returns 403 with the gender error (mirror case)", async () => {
    const token = await signIn(M_HEAD);
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 29 * 86400_000).toISOString().slice(0, 10);
    const res = await http()
      .get(`/api/amal/entries?from=${from}&to=${today}&userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
    expect(res.body.error).toBe(GENDER_ERR);
  });

  it("positive control — the F head DOES see her own member's rows through the same raw endpoint", async () => {
    const token = await signIn(F_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw?userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.count).toBeGreaterThan(0);
    expect(res.body.rows).toBe(res.body.count);
  });

  it("the raw probe is test-only — without the header it is disabled (404)", async () => {
    const token = await signIn(F_HEAD);
    await http()
      .get(`/api/test/rls-raw?userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(404);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// DeviceToken RLS e2e (Task B2 — push fan-out defense in depth).
//
// Both members register an FCM token through the REAL route
// (POST /api/push/token), then the raw probe
// (/api/test/rls-raw-device-tokens) queries the opposite-gender head's
// member tokens inside the HEAD's RLS context with no application filter.
// PostgreSQL must return 0 rows — a male head can never resolve a female
// member's push tokens even if membership data drifted. Positive control:
// the F head DOES resolve her own member's token (same-gender, same usrah).
// ─────────────────────────────────────────────────────────────────────────────
describe("RLS e2e — DeviceToken refuses cross-gender fan-out (push, B2)", () => {
  const maleToken = `e2e-m-${"x".repeat(80)}`;
  const femaleToken = `e2e-f-${"x".repeat(80)}`;

  afterAll(async () => {
    // Leave the demo DB pristine — remove the seeded device tokens.
    const rls = app.get(RlsService);
    await rls.system((tx) =>
      tx.deviceToken.deleteMany({ where: { token: { in: [maleToken, femaleToken] } } })
    );
  });

  it("members register device tokens through the real route (201/200)", async () => {
    const mToken = await signIn(M_MEMBER);
    const fToken = await signIn(F_MEMBER);
    await http()
      .post("/api/push/token")
      .set("Authorization", `Bearer ${mToken}`)
      .send({ token: maleToken, platform: "android" })
      .expect(201);
    await http()
      .post("/api/push/token")
      .set("Authorization", `Bearer ${fToken}`)
      .send({ token: femaleToken, platform: "ios" })
      .expect(201);
    // idempotent re-register (upsert per user+token)
    await http()
      .post("/api/push/token")
      .set("Authorization", `Bearer ${fToken}`)
      .send({ token: femaleToken, platform: "ios" })
      .expect(201);
  });

  it("FEMALE head → raw DeviceToken query for a MALE member returns 0 rows", async () => {
    const token = await signIn(F_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw-device-tokens?userId=${maleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.rows).toBe(0);
  });

  it("MALE head → raw DeviceToken query for a FEMALE member returns 0 rows (mirror)", async () => {
    const token = await signIn(M_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw-device-tokens?userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.rows).toBe(0);
  });

  it("positive control — the F head resolves her own member's token (same gender, same usrah)", async () => {
    const token = await signIn(F_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw-device-tokens?userId=${femaleMemberId}`)
      .set("Authorization", `Bearer ${token}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.rows).toBe(1);
  });

  it("unregister removes the token (DELETE, own row only)", async () => {
    const mToken = await signIn(M_MEMBER);
    await http()
      .delete("/api/push/token")
      .set("Authorization", `Bearer ${mToken}`)
      .send({ token: maleToken })
      .expect(200);
    // gone for everyone — even the positive-control path
    const headToken = await signIn(M_HEAD);
    const res = await http()
      .get(`/api/test/rls-raw-device-tokens?userId=${maleMemberId}`)
      .set("Authorization", `Bearer ${headToken}`)
      .set("x-rls-raw-test", "1")
      .expect(200);
    expect(res.body.rows).toBe(0);
  });
});
