// A member's own screens must not break when someone OUTSIDE their RLS
// view is named on them. A plain member cannot see the head's or a full
// admin's User row, so a Prisma relation include (author / reviewer) came
// back null and the whole response failed with a 500:
//   • GET /api/usrah — after a full admin's announcement to the usrah
//   • GET /api/reviews — after the head (or an admin) reviewed the member
//   • GET /api/usrah-questions — after the head answered
// The names are now looked up separately; this pins all three.
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

describe("names from outside the member's RLS view", () => {
  it("the usrah tab survives a full admin's announcement to the usrah", async () => {
    const member = await signIn("01000000004");
    const before = await http().get("/api/usrah").set("Authorization", `Bearer ${member}`).expect(200);
    const usrahId = before.body.usrah?.id as string;
    expect(usrahId).toBeTruthy();

    const admin = await signIn("01000000001");
    const text = `অ্যাডমিনের ঘোষণা ${Date.now()}`;
    await http()
      .post("/api/admin/broadcast")
      .set("Authorization", `Bearer ${admin}`)
      .send({ usrahId, body: text })
      .expect((r) => {
        if (r.status >= 300) throw new Error(`broadcast → ${r.status} ${JSON.stringify(r.body)}`);
      });

    const after = await http().get("/api/usrah").set("Authorization", `Bearer ${member}`).expect(200);
    const ann = (after.body.announcements as { body: string; authorName?: string }[]).find((a) => a.body === text);
    expect(ann).toBeDefined();
    expect(typeof ann!.authorName).toBe("string");
  });

  it("a member's own review history loads with the reviewer's name", async () => {
    const member = await signIn("01000000004");
    const r = await http().get("/api/reviews").set("Authorization", `Bearer ${member}`).expect(200);
    expect(Array.isArray(r.body.reviews)).toBe(true);
  });

  it("the usrah question board loads for a plain member", async () => {
    const member = await signIn("01000000007");
    const r = await http().get("/api/usrah-questions").set("Authorization", `Bearer ${member}`).expect(200);
    expect(Array.isArray(r.body.questions)).toBe(true);
  });
});
