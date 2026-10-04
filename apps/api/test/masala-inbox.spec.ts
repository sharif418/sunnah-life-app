// ─────────────────────────────────────────────────────────────────────────────
// মাসআলা: a member asks → full_admin lists and answers → the member reads
// the answer in GET /api/masala/mine and gets an inbox message (kind
// 'masala'). Nobody but full_admin reads the inbox.
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

describe("masala inbox", () => {
  it("member asks → admin answers → the member sees it + an inbox message", async () => {
    const member = await signIn("01000000010");
    const marker = `পরীক্ষামূলক প্রশ্ন ${Date.now()}`;
    await http()
      .post("/api/masala")
      .set("Authorization", `Bearer ${member}`)
      .send({ name: "আব্দুর রহিম", question: `${marker} — বিতর কত রাকাত?` })
      .expect(201);

    const admin = await signIn("01000000001");
    const list = await http().get("/api/admin/masala?status=new").set("Authorization", `Bearer ${admin}`).expect(200);
    const q = (list.body.questions as { id: string; question: string }[]).find((x) => x.question.startsWith(marker));
    expect(q).toBeTruthy();

    await http()
      .post(`/api/admin/masala/${q!.id}/answer`)
      .set("Authorization", `Bearer ${admin}`)
      .send({ answer: "বিতর তিন রাকাত — বিস্তারিত দলিলসহ…" })
      .expect(200);

    const mine = await http().get("/api/masala/mine").set("Authorization", `Bearer ${member}`).expect(200);
    const answered = (mine.body.questions as { id: string; status: string; answer: string }[]).find((x) => x.id === q!.id);
    expect(answered).toMatchObject({ status: "answered" });
    expect(answered!.answer).toContain("তিন রাকাত");

    const reminders = await http().get("/api/reminders").set("Authorization", `Bearer ${member}`).expect(200);
    expect((reminders.body.reminders as { kind: string }[]).some((r) => r.kind === "masala")).toBe(true);
  });

  it("only full_admin reads the inbox; an empty answer is refused", async () => {
    const head = await signIn("01000000003");
    await http().get("/api/admin/masala").set("Authorization", `Bearer ${head}`).expect(403);
    const admin = await signIn("01000000001");
    await http()
      .post("/api/admin/masala/nope/answer")
      .set("Authorization", `Bearer ${admin}`)
      .send({ answer: "" })
      .expect(400);
  });
});
