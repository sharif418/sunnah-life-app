// The admin panel's waiting-work counts (nav badges + the dashboard's
// "আজকের কাজ"): full admins see every inbox, a usrah head only their own
// pending reviews (the inbox counts are null — they cannot open those).
// The audit log names the people involved instead of ids.
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";

let app: INestApplication;
const http = () => request(app.getHttpServer());

async function signIn(phone: string): Promise<string> {
  const otp = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const v = await http().post("/api/auth/otp/verify").send({ phone, code: otp.body.devCode }).expect(200);
  return v.body.accessToken as string;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
});
afterAll(async () => app.close());

describe("GET /api/admin/queues", () => {
  it("full admin: every queue is a number", async () => {
    const admin = await signIn("01000000001");
    const r = await http().get("/api/admin/queues").set("Authorization", `Bearer ${admin}`).expect(200);
    for (const k of ["reviews", "support", "masala", "feedback", "joinRequests"]) {
      expect(typeof r.body[k]).toBe("number");
    }
  });

  it("usrah head: own reviews only, inbox counts null", async () => {
    const head = await signIn("01000000003");
    const r = await http().get("/api/admin/queues").set("Authorization", `Bearer ${head}`).expect(200);
    expect(typeof r.body.reviews).toBe("number");
    expect(r.body.support).toBeNull();
    expect(r.body.masala).toBeNull();
    expect(r.body.feedback).toBeNull();
    expect(r.body.joinRequests).toBeNull();
  });

  it("a plain member is refused", async () => {
    const member = await signIn("01000000007");
    await http().get("/api/admin/queues").set("Authorization", `Bearer ${member}`).expect(403);
  });
});

describe("GET /api/admin/audit", () => {
  it("names the member an action touched", async () => {
    const admin = await signIn("01000000001");
    // make sure the newest window holds a member-targeted action
    const list = await http().get("/api/admin/users?q=").set("Authorization", `Bearer ${admin}`).expect(200);
    const member = (list.body.users as { id: string; role: string }[]).find((u) => u.role === "daee");
    expect(member).toBeDefined();
    const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
    await http()
      .post("/api/amal/unlock")
      .set("Authorization", `Bearer ${admin}`)
      .send({ userId: member!.id, date: yesterday, reason: "পরীক্ষা" })
      .expect((res) => {
        if (res.status >= 300) throw new Error(`unlock → ${res.status} ${JSON.stringify(res.body)}`);
      });
    const r = await http().get("/api/admin/audit").set("Authorization", `Bearer ${admin}`).expect(200);
    const entries = r.body.entries as { action: string; targetId: string | null; meta: { userId?: string } | null; targetName?: string | null }[];
    const unlock = entries.find(
      (e) => e.action === "unlock_day" && (e.targetId === member!.id || e.meta?.userId === member!.id)
    );
    expect(unlock).toBeDefined();
    expect(typeof unlock!.targetName).toBe("string");
    expect(unlock!.targetName!.length).toBeGreaterThan(0);
  });
});
