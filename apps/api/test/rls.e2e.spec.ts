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
import type { User } from "src/shared/domain";
import { PrismaClient } from "src/generated/prisma/client";

const F_HEAD = "01000000005"; // উম্মে হাবিবা — head of উসরা আয়েশা সিদ্দিকা (F)
const M_HEAD = "01000000003"; // মাওলানা ইউসুফ — head of উসরা আল-ফুরকান (M)
const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — male member of আল-ফুরকান
const F_MEMBER = "01000000006"; // মারিয়াম হাসান — female member of আয়েশা সিদ্দিকা
const FULL_ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন

const GENDER_ERR = "বিপরীত লিঙ্গের তথ্য দেখার অনুমতি নেই";

let app: INestApplication;
// Superuser maintenance connection: RLS has NO delete policy on DayUnlock
// (owner-connection-only by design) and rls.system cannot delete either —
// leftover rows from earlier runs would trip the unique (userId, date) index.
const maintenance = new PrismaClient({ datasources: { db: { url: process.env.DIRECT_URL || process.env.DATABASE_URL || "" } } });
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

/** Full OTP sign-in → the domain user row (for direct RlsService contexts). */
async function signInUser(phone: string): Promise<User> {
  const token = await signIn(phone);
  const res = await http().get("/api/me").set("Authorization", `Bearer ${token}`).expect(200);
  return res.body.user as User;
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
  await app.listen(0); // own the listener - supertest lazy listen(0) race (CI 36423438154)
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  await app.close();
  await maintenance.$disconnect();
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

// ─────────────────────────────────────────────────────────────────────────────
// Phase C/W2e — the tightened policies. Every bug the audit found gets a
// test that would have caught it:
//   (a) plain members could read same-gender usrah peers' diaries via the
//       usrahId clause — now usrah_head/invigilator only
//   (b) DayUnlock inserts were possible for any visible user — now heads+
//   (c) OtpCode/AuditLog/MasalaQuestion/Feedback had no RLS
//   (d) users could change own role/gender/usrahId at the DB level
// ─────────────────────────────────────────────────────────────────────────────
describe("RLS e2e — W2e tightening", () => {
  const M_PEER = "01000000008"; // সাইফুল ইসলাম — plain user, SAME usrah as M_MEMBER
  const F_PEER = "01000000011"; // ফাতিমা আক্তার — plain user, same usrah as F_MEMBER

  let rls: RlsService;
  let maleMember: User;
  let maleMemberToken: string;
  let adminToken: string;

  beforeAll(async () => {
    rls = app.get(RlsService);
    adminToken = await signIn(FULL_ADMIN);
    maleMember = await signInUser(M_MEMBER);
    maleMemberToken = await signIn(M_MEMBER);
  });

  it("(meta) the runtime connects as the restricted role — current_user + NO rolbypassrls", async () => {
    const res = await rls.system((tx) =>
      tx.$queryRaw<{ current_user: string; rolbypassrls: boolean }[]>`
        SELECT current_user, r.rolbypassrls FROM pg_roles r WHERE r.rolname = current_user
      `
    );
    expect(res[0].current_user).toBe("sunnah_app");
    expect(res[0].rolbypassrls).toBe(false);
  });

  it("(a) regression: a plain member CANNOT read same-usrah peers' diaries (was the audit bug)", async () => {
    // target = the USRAH HEAD: same usrah, same gender, NOT in the member's
    // downline (M_MEMBER referred several peers — those stay visible to the
    // daee; the head is the clean same-usrah-not-downline case).
    const head = await signInUser(M_HEAD);
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 29 * 86400_000).toISOString().slice(0, 10);
    // the standard endpoint refuses (403 — not in guard's allowed set)
    const res = await http()
      .get(`/api/amal/entries?from=${from}&to=${today}&userId=${head.id}`)
      .set("Authorization", `Bearer ${maleMemberToken}`)
      .expect(403);
    expect(res.body.error).toBeTruthy();
    // and at the DATABASE level: unfiltered count inside the member's context
    const count = await rls.run(maleMember, (tx) =>
      tx.amalEntry.count({ where: { userId: head.id } })
    );
    expect(count).toBe(0);
    // …while the OLD bug would have counted the head's seeded diary:
    const headDiarySize = await rls.system((tx) => tx.amalEntry.count({ where: { userId: head.id } }));
    expect(headDiarySize).toBeGreaterThan(0);
  });

  it("(a) positive control — the member still sees THEIR OWN diary", async () => {
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 29 * 86400_000).toISOString().slice(0, 10);
    const res = await http()
      .get(`/api/amal/entries?from=${from}&to=${today}`)
      .set("Authorization", `Bearer ${maleMemberToken}`)
      .expect(200);
    expect(Array.isArray(res.body.entries)).toBe(true);
    expect((res.body.entries as unknown[]).length).toBeGreaterThan(0); // seeded history
  });

  it("(a) same gender, OTHER usrah — a plain member of one usrah cannot read another usrah's member", async () => {
    // build a second male usrah with one member (system context)
    const { usrahId, memberId } = await rls.system(async (tx) => {
      const usrah = await tx.usrah.create({
        data: { name: "উসরা পরীক্ষা-২ (M)", gender: "M", district: "dhaka" },
      });
      const member = await tx.user.create({
        data: { phone: "01777770002", name: "পরীক্ষা সদস্য", gender: "M", usrahId: usrah.id },
      });
      return { usrahId: usrah.id, memberId: member.id };
    });
    try {
      const visible = await rls.run(maleMember, (tx) => tx.user.count({ where: { id: memberId } }));
      expect(visible).toBe(0);
      const diary = await rls.run(maleMember, (tx) => tx.amalEntry.count({ where: { userId: memberId } }));
      expect(diary).toBe(0);
    } finally {
      await rls.system(async (tx) => {
        await tx.user.delete({ where: { id: memberId } });
        await tx.usrah.delete({ where: { id: usrahId } });
      });
    }
  });

  it("(b) DayUnlock: a member CANNOT insert an unlock row even for themself (DB-level)", async () => {
    await expect(
      rls.run(maleMember, (tx) =>
        tx.dayUnlock.create({ data: { userId: maleMember.id, date: new Date().toISOString().slice(0, 10), reason: "self" } })
      )
    ).rejects.toThrow();
  });

  it("(b) DayUnlock: the USRAH HEAD still can (the real flow)", async () => {
    const head = await signInUser(M_HEAD); // মাওলানা ইউসুফ — head of আল-ফুরকান
    const date = new Date().toISOString().slice(0, 10);
    await maintenance.dayUnlock.deleteMany({ where: { userId: maleMember.id, date } });
    await rls.run(head, async (tx) => {
      await tx.dayUnlock.create({
        data: { userId: maleMember.id, date, byUserId: head.id, reason: "e2e" },
      });
    });
    await maintenance.dayUnlock.deleteMany({ where: { userId: maleMember.id, date } });
  });

  it("(c) OtpCode rows are invisible outside the system context", async () => {
    const total = await rls.system((tx) => tx.otpCode.count());
    expect(total).toBeGreaterThanOrEqual(0);
    const asMember = await rls.run(maleMember, (tx) => tx.otpCode.count());
    expect(asMember).toBe(0);
  });

  it("(c) AuditLog rows are invisible to plain users", async () => {
    const asMember = await rls.run(maleMember, (tx) => tx.auditLog.count());
    expect(asMember).toBe(0);
  });

  it("(c) a guest can ask a masala question; nobody else's questions are visible", async () => {
    const res = await http()
      .post("/api/masala")
      .send({ name: "অতিথি", question: "রিভিউ সময় কখন?" })
      .expect(201);
    const mine = await rls.run(maleMember, (tx) => tx.masalaQuestion.count());
    expect(mine).toBe(0); // the guest row is not the member's
    const asSystem = await rls.system((tx) => tx.masalaQuestion.count());
    expect(asSystem).toBeGreaterThanOrEqual(1);
    expect(res.body).toBeTruthy();
  });

  it("(d) a user cannot change own role / gender / usrahId at the DB level (trigger)", async () => {
    await expect(
      rls.run(maleMember, (tx) => tx.user.update({ where: { id: maleMember.id }, data: { role: "full_admin" } }))
    ).rejects.toThrow();
    await expect(
      rls.run(maleMember, (tx) => tx.user.update({ where: { id: maleMember.id }, data: { gender: "F" } }))
    ).rejects.toThrow();
    await expect(
      rls.run(maleMember, (tx) => tx.user.update({ where: { id: maleMember.id }, data: { usrahId: "anywhere" } }))
    ).rejects.toThrow();
    // the ONE-TIME gender completion (unspecified → M/F) stays allowed
    await rls.system(async (tx) => {
      const guest = await tx.user.create({ data: { phone: "01777770003", name: "সোশ্যাল গেস্ট", gender: "unspecified" } });
      await tx.$executeRawUnsafe(`SELECT set_config('app.user_id', '${guest.id}', true), set_config('app.gender', 'unspecified', true), set_config('app.usrah_id', '', true), set_config('app.role', 'user', true)`);
      // simulate PATCH /me: gender completion under the user's own context
      await tx.user.update({ where: { id: guest.id }, data: { gender: "M" } });
      await tx.user.delete({ where: { id: guest.id } });
    });
  });

  it("(g) PATCH /api/admin/users: a cross-gender usrah assignment is rejected (400)", async () => {
    const fUserId = (await signInUser(F_PEER)).id;
    // the FEMALE member cannot be moved into the MALE usrah
    const maleUsrah = await rls.system((tx) => tx.usrah.findFirst({ where: { gender: "M" } }));
    const res = await http()
      .patch("/api/admin/users")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ userId: fUserId, usrahId: maleUsrah!.id, reason: "পরীক্ষা" })
      .expect(400);
    expect(res.body.error).toContain("এক-লিঙ্গ");
  });

  it("(g) reports + reviews of the member stay readable by the HEAD only ( tightened surface)", async () => {
    // head CAN see the member's reviews through the standard endpoint
    await http()
      .get("/api/reviews")
      .set("Authorization", `Bearer ${await signIn(M_HEAD)}`)
      .expect(200);
    // a same-usrah PEER cannot read the member's reviews at the DB level
    const peer = await signInUser(M_PEER);
    const reviews = await rls.run(peer, (tx) => tx.weeklyReview.count({ where: { userId: maleMember.id } }));
    expect(reviews).toBe(0);
  });
});
