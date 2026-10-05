// Security review 2026-10-05: a supervisor could grade, review and approve
// THEMSELVES — a self-submitted "passed" Farze-Ain assessment, confirmed with
// their own OTP, fed auto-promotion. Every decision about a person is now
// made by someone else.
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

let app: INestApplication;
let rls: RlsService;
const http = () => request(app.getHttpServer());
const MARK = "self-decision-test";

async function signIn(phone: string) {
  const otp = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const v = await http().post("/api/auth/otp/verify").send({ phone, code: otp.body.devCode }).expect(200);
  return { token: v.body.accessToken as string, id: v.body.user.id as string };
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
});
afterAll(async () => {
  await rls.system((tx) => tx.personalGoal.deleteMany({ where: { title: { contains: MARK } } }));
  await app.close();
});

describe("no supervisor decides about themselves", () => {
  it("assessment: an invigilator cannot submit their own", async () => {
    const inv = await signIn("01000000002");
    const tpl = await http().get("/api/assessments/templates").expect(200);
    const active = tpl.body.templates[0] as { key: string; sections: { criteria: { key: string }[] }[] };
    const scores: Record<string, { score: 2 }> = {};
    for (const s of active.sections) for (const c of s.criteria) scores[c.key] = { score: 2 };
    await http()
      .post("/api/assessments")
      .set("Authorization", `Bearer ${inv.token}`)
      .send({ assesseeId: inv.id, templateKey: active.key, participantCategory: 1, scores })
      .expect(403);
  });

  it("weekly review: a head cannot review their own week", async () => {
    const head = await signIn("01000000003");
    await http()
      .post("/api/reviews")
      .set("Authorization", `Bearer ${head.token}`)
      .send({ userId: head.id, weekStart: "2025-06-07", rating: 5 })
      .expect(403);
  });

  it("goals: a head's own goal is not in their queue and they cannot approve it", async () => {
    const head = await signIn("01000000003");
    const created = await http()
      .post("/api/goals")
      .set("Authorization", `Bearer ${head.token}`)
      .send({ amalKey: "tahajjud", title: `${MARK} — নিজের`, startDate: "2025-06-01" })
      .expect(201);
    const id = created.body.goal.id as string;
    const queue = await http().get("/api/usrah/goals").set("Authorization", `Bearer ${head.token}`).expect(200);
    expect((queue.body.queue as { id: string }[]).some((g) => g.id === id)).toBe(false);
    await http().post(`/api/goals/${id}/approve`).set("Authorization", `Bearer ${head.token}`).expect(403);
    await http()
      .post(`/api/goals/${id}/reject`)
      .set("Authorization", `Bearer ${head.token}`)
      .send({ reason: "x" })
      .expect(403);
  });
});

describe("admin gender change keeps usrahs single-gender", () => {
  it("a member leaves the old usrah; a head must hand over first", async () => {
    const admin = await signIn("01000000001");
    const member = await signIn("01711114444"); // throwaway
    const head = await signIn("01000000003");
    const usrah = await rls.system((tx) => tx.usrah.findFirst({ where: { headUserId: head.id } }));
    await rls.system((tx) => tx.user.update({ where: { id: member.id }, data: { gender: "M", usrahId: usrah!.id } }));
    try {
      const res = await http()
        .patch("/api/admin/users")
        .set("Authorization", `Bearer ${admin.token}`)
        .send({ userId: member.id, gender: "F", reason: "ভুলবশত ভাই হিসেবে নিবন্ধিত" })
        .expect(200);
      expect(res.body.user.gender).toBe("F");
      expect(res.body.user.usrahId).toBeNull();

      await http()
        .patch("/api/admin/users")
        .set("Authorization", `Bearer ${admin.token}`)
        .send({ userId: head.id, gender: "F", reason: "পরীক্ষা — বাতিল হবে" })
        .expect(400);
      const still = await rls.system((tx) => tx.user.findUnique({ where: { id: head.id } }));
      expect(still?.gender).toBe("M");
    } finally {
      await rls.system(async (tx) => {
        await tx.referralClosure.deleteMany({ where: { descendantId: member.id } });
        await tx.user.delete({ where: { id: member.id } });
      });
    }
  });
});
