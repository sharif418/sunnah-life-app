// ─────────────────────────────────────────────────────────────────────────────
// usrah-join.spec.ts (W4d) — usrah join requests (member asks → admin assigns):
//   • a member already IN an usrah → 409
//   • a usrah-less member requests → pending; duplicate while pending is
//     IDEMPOTENT (201 with the SAME row — the /api/enroll upsert precedent;
//     one pending row per user is enforced in the service)
//   • own-status read (current/last request); RLS hides other users' rows
//   • a plain member gets 403 on the admin endpoints; unauth 401
//   • admin queue lists pending first with member names
//   • approve {usrahId}: gender mismatch → 400; a match sets User.usrahId +
//     status approved + audit join_request_approve; idempotent re-approve
//   • the now-assigned member gets 409 on a new request
//   • reject {reason}: rejected + reason visible to the member; re-request
//     opens a NEW pending row; approving a rejected row → 400; re-reject is
//     idempotent
// Fresh synthetic users (phone prefix 01779…) so the demo data is untouched;
// hard-deleted in afterAll (requests cascade on user delete).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import type { User } from "src/shared/domain";

const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — already in উসরা আল-ফুরকান
const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin

const A_PHONE = "01779100001"; // synthetic user A (approve flow)
const B_PHONE = "01779100002"; // synthetic user B (reject flow)

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
let maleUsrahId: string; // উসরা আল-ফুরকান (M)
let femaleUsrahId: string; // উসরা আয়েশা সিদ্দিকা (F)

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

/** OTP sign-in → the domain user row (for a direct RlsService context). */
async function signInUser(phone: string): Promise<User> {
  const token = await signIn(phone);
  const res = await http().get("/api/me").set("Authorization", `Bearer ${token}`).expect(200);
  return res.body.user as User;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());

  // synthetic usrah-less male users (the demo members are ALL in usrahs)
  await rls.system(async (tx) => {
    await tx.user.deleteMany({ where: { phone: { in: [A_PHONE, B_PHONE] } } });
    await tx.user.create({ data: { phone: A_PHONE, name: "ই২ই যোগ আলফা", gender: "M" } });
    await tx.user.create({ data: { phone: B_PHONE, name: "ই২ই যোগ বেটা", gender: "M" } });
    const usrahs = await tx.usrah.findMany({ select: { id: true, name: true, gender: true } });
    maleUsrahId = usrahs.find((u) => u.name === "উসরা আল-ফুরকান")!.id;
    femaleUsrahId = usrahs.find((u) => u.name === "উসরা আয়েশা সিদ্দিকা")!.id;
  });
});

afterAll(async () => {
  // hard-delete the synthetic users (join requests cascade); audit rows stay
  // like every other spec (goals pattern).
  await rls.system((tx) => tx.user.deleteMany({ where: { phone: { startsWith: "0177910" } } }));
  await app.close();
});

describe("usrah join requests (e2e)", () => {
  let aToken: string;
  let bToken: string;
  let adminToken: string;
  let aRequestId: string;
  let bRequestId: string;

  it("a member already in an usrah → 409", async () => {
    const token = await signIn(M_MEMBER);
    const res = await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "আমাকে নেওয়া হয়েছে তো?" })
      .expect(409);
    expect(res.body.error).toContain("উসরায়");
  });

  it("a usrah-less member requests → pending, message kept", async () => {
    aToken = await signIn(A_PHONE);
    const res = await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${aToken}`)
      .send({ message: "আমি মিরপুরে থাকি — কাছের উসরায় যুক্ত হতে চাই।" })
      .expect(201);
    expect(res.body.request.status).toBe("pending");
    expect(res.body.request.message).toContain("মিরপুরে");
    aRequestId = res.body.request.id;
  });

  it("duplicate while pending → IDEMPOTENT (same row, still exactly one)", async () => {
    const res = await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${aToken}`)
      .send({})
      .expect(201);
    expect(res.body.request.id).toBe(aRequestId);
    const count = await rls.system((tx) =>
      tx.usrahJoinRequest.count({ where: { userId: res.body.request.userId } })
    );
    expect(count).toBe(1);
  });

  it("own-status read carries the pending request", async () => {
    const res = await http().get("/api/usrah/join-request").set("Authorization", `Bearer ${aToken}`).expect(200);
    expect(res.body.request.id).toBe(aRequestId);
    expect(res.body.request.status).toBe("pending");
  });

  it("RLS: user B's context sees ZERO of user A's requests", async () => {
    const aUser = (await rls.system((tx) => tx.user.findUnique({ where: { phone: A_PHONE } })))!;
    const bUser = await signInUser(B_PHONE);
    const visible = await rls.run(bUser, (tx) =>
      tx.usrahJoinRequest.count({ where: { userId: aUser.id } })
    );
    expect(visible).toBe(0);
  });

  it("unauthenticated → 401", async () => {
    await http().get("/api/usrah/join-request").expect(401);
    await http().post("/api/usrah/join-request").send({}).expect(401);
  });

  it("a plain member cannot use the admin endpoints (403)", async () => {
    await http().get("/api/usrah/join-requests").set("Authorization", `Bearer ${aToken}`).expect(403);
    await http()
      .post(`/api/usrah/join-requests/${aRequestId}/approve`)
      .set("Authorization", `Bearer ${aToken}`)
      .send({ usrahId: maleUsrahId })
      .expect(403);
  });

  it("admin queue lists the pending requests first with member names", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http().get("/api/usrah/join-requests").set("Authorization", `Bearer ${adminToken}`).expect(200);
    const rows = res.body.requests as { id: string; userName: string; status: string; userGender: string }[];
    const mine = rows.find((r) => r.id === aRequestId)!;
    expect(mine).toBeDefined();
    expect(mine.userName).toBe("ই২ই যোগ আলফা");
    expect(mine.status).toBe("pending");
    expect(mine.userGender).toBe("M");
    // pending rows sort before decided ones (oldest pending at the very top)
    const firstDecided = rows.findIndex((r) => r.status !== "pending");
    const lastPending = rows.map((r) => r.status).lastIndexOf("pending");
    if (firstDecided >= 0) expect(lastPending).toBeLessThan(firstDecided);
  });

  it("approve into an opposite-gender usrah → 400", async () => {
    await http()
      .post(`/api/usrah/join-requests/${aRequestId}/approve`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ usrahId: femaleUsrahId })
      .expect(400);
  });

  it("approve into the matching usrah → User.usrahId set + approved + audit row", async () => {
    const res = await http()
      .post(`/api/usrah/join-requests/${aRequestId}/approve`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ usrahId: maleUsrahId })
      .expect(200);
    expect(res.body.request.status).toBe("approved");
    expect(res.body.request.usrahId).toBe(maleUsrahId);
    expect(res.body.request.handledAt).toBeTruthy();

    const member = await rls.system((tx) => tx.user.findUnique({ where: { phone: A_PHONE } }));
    expect(member!.usrahId).toBe(maleUsrahId); // THE assignment

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "join_request_approve", targetId: aRequestId } })
    );
    expect(audit).toBeTruthy();
    expect((audit!.metaJson as { usrahId: string }).usrahId).toBe(maleUsrahId);
  });

  it("the member's own status now shows approved + the assigned usrah", async () => {
    const res = await http().get("/api/usrah/join-request").set("Authorization", `Bearer ${aToken}`).expect(200);
    expect(res.body.request.status).toBe("approved");
    expect(res.body.request.usrahId).toBe(maleUsrahId);
  });

  it("the assigned member's new requests → 409", async () => {
    await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${aToken}`)
      .send({})
      .expect(409);
  });

  it("re-approve is idempotent — no second audit transition", async () => {
    const res = await http()
      .post(`/api/usrah/join-requests/${aRequestId}/approve`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ usrahId: maleUsrahId })
      .expect(200);
    expect(res.body.request.status).toBe("approved");
    const count = await rls.system((tx) =>
      tx.auditLog.count({ where: { action: "join_request_approve", targetId: aRequestId } })
    );
    expect(count).toBe(1);
  });

  it("reject with a reason → rejected, the member sees the reason + audit row", async () => {
    bToken = await signIn(B_PHONE);
    const created = await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${bToken}`)
      .send({ message: "আমার জন্য একটি উসরা দরকার।" })
      .expect(201);
    bRequestId = created.body.request.id;

    const res = await http()
      .post(`/api/usrah/join-requests/${bRequestId}/reject`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ reason: "আপনার এলাকায় এখনো উসরা চালু হয়নি — ইনশাআল্লাহ শিগগির।" })
      .expect(200);
    expect(res.body.request.status).toBe("rejected");
    expect(res.body.request.reason).toContain("ইনশাআল্লাহ");

    const own = await http().get("/api/usrah/join-request").set("Authorization", `Bearer ${bToken}`).expect(200);
    expect(own.body.request.status).toBe("rejected");
    expect(own.body.request.reason).toContain("ইনশাআল্লাহ");

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "join_request_reject", targetId: bRequestId } })
    );
    expect(audit).toBeTruthy();
  });

  it("a rejected member may RE-request (a NEW pending row)", async () => {
    const res = await http()
      .post("/api/usrah/join-request")
      .set("Authorization", `Bearer ${bToken}`)
      .send({ message: "এখন উসরা চালু হয়েছে শুনলাম।" })
      .expect(201);
    expect(res.body.request.status).toBe("pending");
    expect(res.body.request.id).not.toBe(bRequestId);
    bRequestId = res.body.request.id;
  });

  it("approving a REJECTED row → 400; re-rejecting the new pending row works", async () => {
    // the OLD rejected row cannot be flipped into an assignment anymore
    const bUserId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: B_PHONE } })))!.id;
    const old = await rls.system((tx) =>
      tx.usrahJoinRequest.findFirst({ where: { userId: bUserId, status: "rejected" } })
    );
    await http()
      .post(`/api/usrah/join-requests/${old!.id}/approve`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ usrahId: maleUsrahId })
      .expect(400);

    // the fresh pending row gets rejected (and the repeat is idempotent)
    await http()
      .post(`/api/usrah/join-requests/${bRequestId}/reject`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({})
      .expect(200);
    const again = await http()
      .post(`/api/usrah/join-requests/${bRequestId}/reject`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({})
      .expect(200);
    expect(again.body.request.status).toBe("rejected");
  });

  it("unknown request id → 404", async () => {
    await http()
      .post("/api/usrah/join-requests/does-not-exist/approve")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ usrahId: maleUsrahId })
      .expect(404);
  });
});
