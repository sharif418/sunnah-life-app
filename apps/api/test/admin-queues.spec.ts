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
  it("names the member a promotion touched", async () => {
    const admin = await signIn("01000000001");
    const r = await http().get("/api/admin/audit").set("Authorization", `Bearer ${admin}`).expect(200);
    const promos = (r.body.entries as { action: string; targetName?: string | null }[]).filter(
      (e) => e.action === "promote_level"
    );
    expect(promos.length).toBeGreaterThan(0);
    expect(promos.every((e) => typeof e.targetName === "string" && e.targetName.length > 0)).toBe(true);
  });
});
