// NAV-03: Foundation-wide announcements are public; a sisters-only notice is
// shown to sisters only (never to brothers or guests); usrah notices stay out.
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

describe("public announcements", () => {
  it("everyone sees the all-audience notice; only sisters see the sisters-only one", async () => {
    const admin = await signIn("01000000001");
    const all = `সবার জন্য ${Date.now()}`;
    const sisters = `শুধু বোনদের ${Date.now()}`;
    await http().post("/api/admin/broadcast").set("Authorization", `Bearer ${admin}`).send({ body: all }).expect((r) => {
      if (r.status >= 300) throw new Error(`broadcast all → ${r.status} ${JSON.stringify(r.body)}`);
    });
    await http()
      .post("/api/admin/broadcast")
      .set("Authorization", `Bearer ${admin}`)
      .send({ body: sisters, gender: "F" })
      .expect((r) => {
        if (r.status >= 300) throw new Error(`broadcast F → ${r.status} ${JSON.stringify(r.body)}`);
      });

    const bodies = (res: request.Response) => (res.body.announcements as { body: string }[]).map((a) => a.body);
    const guest = await http().get("/api/announcements").expect(200);
    expect(bodies(guest)).toContain(all);
    expect(bodies(guest)).not.toContain(sisters);

    const brother = await signIn("01000000004");
    const b = await http().get("/api/announcements").set("Authorization", `Bearer ${brother}`).expect(200);
    expect(bodies(b)).not.toContain(sisters);

    const sister = await signIn("01000000006");
    const s = await http().get("/api/announcements").set("Authorization", `Bearer ${sister}`).expect(200);
    expect(bodies(s)).toEqual(expect.arrayContaining([all, sisters]));
  });

  it("a usrah head's own-gender broadcast stays out of the public Foundation list", async () => {
    const head = await signIn("01000000003");
    const text = `উসরা প্রধানের ঘোষণা ${Date.now()}`;
    await http()
      .post("/api/admin/broadcast")
      .set("Authorization", `Bearer ${head}`)
      .send({ body: text, gender: "M" })
      .expect((r) => {
        if (r.status >= 300) throw new Error(`broadcast → ${r.status} ${JSON.stringify(r.body)}`);
      });
    const brother = await signIn("01000000004");
    const res = await http().get("/api/announcements").set("Authorization", `Bearer ${brother}`).expect(200);
    expect((res.body.announcements as { body: string }[]).map((a) => a.body)).not.toContain(text);
  });
});
