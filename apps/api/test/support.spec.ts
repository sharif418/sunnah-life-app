// ─────────────────────────────────────────────────────────────────────────────
// support.spec.ts (W4d) — live support threads (user ↔ admin):
//   • member opens a thread (subject + first message, status "open")
//   • GET /api/support lists own threads with stats (messageCount, preview,
//     unreadForUser = the last message is an admin reply)
//   • append; a member reply on an ANSWERED thread flips it back to "open"
//   • cross-user isolation: a same-usrah peer gets 403 on detail/append, and
//     RLS itself (the net) hides the row in the peer's own context
//   • admin reply flips status → "answered" + audit support_reply
//   • admin close → closed (idempotent); appending to a closed thread → 400
//     (member AND admin — closed is terminal, no auto-reopen)
//   • unauth 401; a plain member on /api/admin/support → 403
// Runs against the demo DB (SEED_DEMO) exactly like rls.e2e/goals.spec.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { MAX_OPEN_SUPPORT_THREADS } from "src/support/support.controller";
import type { User } from "src/shared/domain";

const M_MEMBER = "01000000004"; // রাফিউল ইসলাম — male member of আল-ফুরকান
const M_PEER = "01000000007"; // তানভীর হোসেন — plain member of the SAME usrah
const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin

const MARK = "ই২ই সাপোর্ট"; // marks every thread this spec creates

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
let memberId: string;

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
  memberId = (await rls.system((tx) => tx.user.findUnique({ where: { phone: M_MEMBER } })))!.id;
});

afterAll(async () => {
  // leave the demo DB pristine: every thread this spec created is hard-deleted
  // (messages cascade); audit rows stay like every other spec (goals pattern).
  if (memberId) {
    await rls.system(async (tx) => {
      await tx.supportThread.deleteMany({ where: { userId: memberId, subject: { contains: MARK } } });
    });
  }
  await app.close();
});

describe("support threads (e2e)", () => {
  let memberToken: string;
  let peerToken: string;
  let adminToken: string;
  let threadId: string; // the thread that goes through the full lifecycle

  it("member opens a thread → status open, first message inside", async () => {
    memberToken = await signIn(M_MEMBER);
    const res = await http()
      .post("/api/support")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ subject: `${MARK} — নামাজের সময়`, message: "আসসালামু আলাইকুম, একটি বিষয় জানতে চাই।" })
      .expect(201);
    expect(res.body.thread.status).toBe("open");
    expect(res.body.thread.userId).toBe(memberId);
    threadId = res.body.thread.id;

    const detail = await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect(detail.body.thread.subject).toContain(MARK);
    expect(detail.body.messages).toHaveLength(1);
    expect(detail.body.messages[0].isAdmin).toBe(false);
    expect(detail.body.messages[0].authorId).toBe(memberId);
  });

  it("too-short subject/message → 400 (Bengali validation)", async () => {
    await http()
      .post("/api/support")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ subject: "আ", message: "আ" })
      .expect(400);
  });

  it("GET /api/support lists own threads with stats (count, preview, unread=false)", async () => {
    const res = await http().get("/api/support").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const mine = (res.body.threads as { id: string; subject: string; messageCount: number; lastPreview: string | null; unreadForUser: boolean }[]).find(
      (t) => t.id === threadId
    )!;
    expect(mine).toBeDefined();
    expect(mine.messageCount).toBe(1);
    expect(mine.lastPreview).toContain("আসসালামু আলাইকুম");
    expect(mine.unreadForUser).toBe(false);
  });

  it("member appends a second message", async () => {
    const res = await http()
      .post(`/api/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ message: "বিসমিল্লাহ — অপেক্ষায় আছি।" })
      .expect(201);
    expect(res.body.message.isAdmin).toBe(false);

    const detail = await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect(detail.body.messages).toHaveLength(2);
    expect(detail.body.thread.status).toBe("open");
  });

  it("cross-user isolation: same-usrah peer gets 403 on detail + append", async () => {
    peerToken = await signIn(M_PEER);
    await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${peerToken}`).expect(403);
    await http()
      .post(`/api/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${peerToken}`)
      .send({ message: "আমি ঢুকে পড়ছি না তো?" })
      .expect(403);
  });

  it("RLS is the net: the peer's own context sees ZERO of the member's threads/messages", async () => {
    const peer = await signInUser(M_PEER);
    const visible = await rls.run(peer, async (tx) => {
      const threads = await tx.supportThread.findMany({ where: { userId: memberId } });
      const messages = await tx.supportMessage.findMany({ where: { threadId: threadId } });
      return { threads: threads.length, messages: messages.length };
    });
    expect(visible).toEqual({ threads: 0, messages: 0 });
  });

  it("unauthenticated → 401", async () => {
    await http().get("/api/support").expect(401);
    await http().get(`/api/support/${threadId}`).expect(401);
  });

  it("a plain member cannot read the admin inbox (403 — role floor)", async () => {
    await http().get("/api/admin/support").set("Authorization", `Bearer ${peerToken}`).expect(403);
  });

  it("admin inbox lists the thread (userName + open-first order)", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http().get("/api/admin/support").set("Authorization", `Bearer ${adminToken}`).expect(200);
    const rows = res.body.threads as { id: string; userName: string; status: string; messageCount: number; lastFromAdmin: boolean }[];
    const mine = rows.find((t) => t.id === threadId)!;
    expect(mine).toBeDefined();
    expect(mine.userName).toBe("রাফিউল ইসলাম");
    expect(mine.status).toBe("open");
    expect(mine.messageCount).toBe(2);
    expect(mine.lastFromAdmin).toBe(false);
    // open threads sort before answered/closed ones
    const firstClosed = rows.findIndex((t) => t.status === "closed");
    const lastOpen = rows.map((t) => t.status).lastIndexOf("open");
    if (firstClosed >= 0 && lastOpen >= 0) expect(lastOpen).toBeLessThan(firstClosed);

    // ?status= filter
    const onlyOpen = await http()
      .get("/api/admin/support?status=open")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    for (const t of onlyOpen.body.threads as { status: string }[]) expect(t.status).toBe("open");
  });

  it("admin reply flips status → answered + audit row; member list shows unreadForUser", async () => {
    const res = await http()
      .post(`/api/admin/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ message: "ওয়া আলাইকুমুস সালাম — বলুন কী জানতে চান?" })
      .expect(201);
    expect(res.body.message.isAdmin).toBe(true);

    const detail = await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect(detail.body.thread.status).toBe("answered");
    expect((detail.body.messages as { isAdmin: boolean }[]).filter((m) => m.isAdmin)).toHaveLength(1);

    const list = await http().get("/api/support").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const mine = (list.body.threads as { id: string; unreadForUser: boolean }[]).find((t) => t.id === threadId)!;
    expect(mine.unreadForUser).toBe(true);

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "support_reply", targetId: threadId } })
    );
    expect(audit).toBeTruthy();
    expect((audit!.metaJson as { userId: string }).userId).toBe(memberId);
  });

  it("member reply on an answered thread flips it back to open", async () => {
    await http()
      .post(`/api/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ message: "জাযাকাল্লাহু খাইরান, আরেকটি প্রশ্ন ছিল।" })
      .expect(201);
    const detail = await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect(detail.body.thread.status).toBe("open");
  });

  it("admin closes → closed; both member and admin appends are refused (closed is terminal)", async () => {
    await http().post(`/api/admin/support/${threadId}/close`).set("Authorization", `Bearer ${adminToken}`).expect(200);

    const detail = await http().get(`/api/support/${threadId}`).set("Authorization", `Bearer ${memberToken}`).expect(200);
    expect(detail.body.thread.status).toBe("closed");
    expect(detail.body.thread.closedAt).toBeTruthy();

    await http()
      .post(`/api/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ message: "আবার খুলে দিন প্লিজ।" })
      .expect(400);
    await http()
      .post(`/api/admin/support/${threadId}/messages`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ message: "বিজ্ঞাপনী প্রতিক্রিয়া।" })
      .expect(400);

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({ where: { action: "support_close", targetId: threadId } })
    );
    expect(audit).toBeTruthy();
  });

  it("re-close is idempotent (200, no error, no second audit transition)", async () => {
    const res = await http().post(`/api/admin/support/${threadId}/close`).set("Authorization", `Bearer ${adminToken}`).expect(200);
    expect(res.body.thread.status).toBe("closed");
    const count = await rls.system((tx) =>
      tx.auditLog.count({ where: { action: "support_close", targetId: threadId } })
    );
    expect(count).toBe(1);
  });

  it("unknown thread id → 404", async () => {
    await http().get("/api/support/does-not-exist").set("Authorization", `Bearer ${memberToken}`).expect(404);
    await http().post("/api/admin/support/does-not-exist/close").set("Authorization", `Bearer ${adminToken}`).expect(404);
  });

  it(`the max-${MAX_OPEN_SUPPORT_THREADS} open-thread cap is enforced`, async () => {
    // the lifecycle thread is CLOSED now → doesn't count; open 5 fresh ones
    for (let i = 0; i < MAX_OPEN_SUPPORT_THREADS; i++) {
      await http()
        .post("/api/support")
        .set("Authorization", `Bearer ${memberToken}`)
        .send({ subject: `${MARK} ক্যাপ ${i}`, message: "ক্যাপ পরীক্ষার বার্তা।" })
        .expect(201);
    }
    const full = await http()
      .post("/api/support")
      .set("Authorization", `Bearer ${memberToken}`)
      .send({ subject: `${MARK} ওভারফ্লো`, message: "এটা আর হবে না।" })
      .expect(400);
    expect(full.body.error).toContain("সর্বোচ্চ");

    // a closed thread never counts toward the cap (the lifecycle thread above)
    const list = await http().get("/api/support").set("Authorization", `Bearer ${memberToken}`).expect(200);
    const open = (list.body.threads as { status: string }[]).filter((t) => t.status !== "closed");
    expect(open.length).toBe(MAX_OPEN_SUPPORT_THREADS);
  });
});
