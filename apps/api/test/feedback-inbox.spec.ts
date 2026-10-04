// ─────────────────────────────────────────────────────────────────────────────
// The app's মতামত inbox: feedback (guests too) carries its device context,
// full_admin lists it new-first and marks it done; nobody else can read it.
// ─────────────────────────────────────────────────────────────────────────────
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

describe("feedback inbox", () => {
  it("a guest's feedback with its device context reaches the admin; done hides it from 'new'", async () => {
    const marker = `পরীক্ষা ${Date.now()}`;
    await http()
      .post("/api/feedback")
      .send({ message: `${marker} — বাটন কাজ করে না`, context: "app 1.0.0 · Android 13" })
      .expect(201);

    const admin = await signIn("01000000001");
    const list = await http().get("/api/admin/feedback").set("Authorization", `Bearer ${admin}`).expect(200);
    const mine = (list.body.feedback as { id: string; message: string; context: string; status: string }[]).find((f) =>
      f.message.startsWith(marker)
    );
    expect(mine).toMatchObject({ context: "app 1.0.0 · Android 13", status: "new" });
    expect(list.body.newCount).toBeGreaterThanOrEqual(1);

    await http()
      .patch(`/api/admin/feedback/${mine!.id}`)
      .set("Authorization", `Bearer ${admin}`)
      .send({ status: "done" })
      .expect(200);
    const fresh = await http().get("/api/admin/feedback?status=new").set("Authorization", `Bearer ${admin}`).expect(200);
    expect((fresh.body.feedback as { id: string }[]).some((f) => f.id === mine!.id)).toBe(false);
  });

  it("a usrah head cannot read the inbox", async () => {
    const head = await signIn("01000000003");
    await http().get("/api/admin/feedback").set("Authorization", `Bearer ${head}`).expect(403);
  });
});
