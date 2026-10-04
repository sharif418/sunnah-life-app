// DELETE /api/me — Google Play's account-deletion rule. The member's own
// data goes, the profile is anonymised, the old token stops working, the
// same phone can start a fresh account, and a usrah head is refused until
// the usrah is handed over.
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

let app: INestApplication;
let rls: RlsService;
const http = () => request(app.getHttpServer());

async function signIn(phone: string, extra: Record<string, string> = {}) {
  const otp = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const v = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otp.body.devCode, ...extra })
    .expect(200);
  return { token: v.body.accessToken as string, id: v.body.user.id as string };
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
});
afterAll(async () => app.close());

describe("DELETE /api/me", () => {
  const phone = `017${String(Date.now()).slice(-8)}`;

  it("needs the explicit confirmation", async () => {
    const me = await signIn(phone, { name: "মোছার পরীক্ষা", gender: "M" });
    await http().delete("/api/me").set("Authorization", `Bearer ${me.token}`).send({}).expect(400);
  });

  it("removes the member's data, anonymises the profile and ends the session", async () => {
    const me = await signIn(phone);
    await http()
      .post("/api/feedback")
      .set("Authorization", `Bearer ${me.token}`)
      .send({ message: "মোছার আগে একটি মতামত" })
      .expect((r) => {
        if (r.status >= 300) throw new Error(`feedback → ${r.status}`);
      });

    await http()
      .post("/api/masala")
      .set("Authorization", `Bearer ${me.token}`)
      .send({ name: "পরীক্ষা", question: "মোছার আগে একটি মাসআলা প্রশ্ন" })
      .expect((r) => {
        if (r.status >= 300) throw new Error(`masala → ${r.status}`);
      });

    await http()
      .delete("/api/me")
      .set("Authorization", `Bearer ${me.token}`)
      .send({ confirm: "DELETE" })
      .expect(200);

    const row = await rls.system((tx) => tx.user.findUnique({ where: { id: me.id } }));
    expect(row?.name).toBe("মুছে ফেলা অ্যাকাউন্ট");
    expect(row?.phone).toBeNull();
    expect(row?.email).toBeNull();
    expect((row as { deletedAt?: Date | null })?.deletedAt).toBeTruthy();
    const feedback = await rls.system((tx) => tx.feedback.count({ where: { userId: me.id } }));
    expect(feedback).toBe(0);
    const masala = await rls.system((tx) => tx.masalaQuestion.count({ where: { userId: me.id } }));
    expect(masala).toBe(0);

    // the old access token no longer identifies anyone
    const after = await http().get("/api/me").set("Authorization", `Bearer ${me.token}`).expect(200);
    expect(after.body.user).toBeNull();

    // the same phone starts a brand-new account
    const again = await signIn(phone, { name: "নতুন অ্যাকাউন্ট", gender: "M" });
    expect(again.id).not.toBe(me.id);
  });

  it("a usrah head is asked to hand the usrah over first", async () => {
    const head = await signIn("01000000003");
    const r = await http()
      .delete("/api/me")
      .set("Authorization", `Bearer ${head.token}`)
      .send({ confirm: "DELETE" })
      .expect(409);
    expect(String(r.body.error)).toContain("উসরা");
  });
});
