// "আনলক চাই": a member asks their usrah head to open a locked diary day.
// Before, the app called POST /api/amal/unlock (heads only) — the member got
// 403 and the head never heard. Now the head gets one inbox message (no
// duplicates for the same day) and only heads can still unlock.
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

let app: INestApplication;
let rls: RlsService;
const http = () => request(app.getHttpServer());

async function signIn(phone: string) {
  const otp = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const v = await http().post("/api/auth/otp/verify").send({ phone, code: otp.body.devCode }).expect(200);
  return { token: v.body.accessToken as string, user: v.body.user as { id: string; usrahId: string | null } };
}

const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000).toISOString().slice(0, 10);

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
});
afterAll(async () => app.close());

describe("POST /api/amal/unlock-request", () => {
  it("reaches the usrah head once per day, and a member still cannot unlock directly", async () => {
    const member = await signIn("01000000004");
    const date = daysAgo(3);
    const headId = await rls.system(async (tx) => {
      const u = await tx.usrah.findUnique({ where: { id: member.user.usrahId! }, select: { headUserId: true } });
      return u!.headUserId!;
    });
    const count = () =>
      rls.system((tx) =>
        tx.reminder.count({ where: { userId: headId, kind: "unlock_request", body: { contains: date }, read: false } })
      );
    const before = await count();

    for (let i = 0; i < 2; i++) {
      await http()
        .post("/api/amal/unlock-request")
        .set("Authorization", `Bearer ${member.token}`)
        .send({ date })
        .expect(201);
    }
    expect(await count()).toBe(before === 0 ? 1 : before);

    await http()
      .post("/api/amal/unlock")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ userId: member.user.id, date })
      .expect(403);
  });

  it("refuses today and future days", async () => {
    const member = await signIn("01000000004");
    await http()
      .post("/api/amal/unlock-request")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ date: new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10) })
      .expect(400);
  });
});
