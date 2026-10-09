// ─────────────────────────────────────────────────────────────────────────────
// body-limits.spec.ts (2026-10-09) — the app booted the way main.ts boots it:
//   • JSON bodies still parse on every route (a route-scoped parser named
//     "jsonParser" once made Nest skip its global one — every login failed)
//   • /api/admin/cms takes a whole pack (> 100kb); other routes keep 100kb
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { applyBodyLimits } from "src/common/body-limits";

let app: INestApplication;

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "health/live", "health/ready", "metrics"] });
  applyBodyLimits(app);
  await app.init();
});

afterAll(async () => {
  await app.close();
});

const big = (bytes: number) => ({ data: { items: [{ q: "x".repeat(bytes), a: "y" }] } });

describe("request bodies", () => {
  it("JSON parses on ordinary routes", async () => {
    // a fresh number each run (the per-phone send window is 3 per 10 minutes)
    const phone = `0179${String(Date.now()).slice(-7)}`;
    const res = await request(app.getHttpServer()).post("/api/auth/otp/request").send({ phone });
    expect(res.status).toBe(200);
    expect(res.body.devCode).toMatch(/^\d{6}$/);
  });

  it("a malformed body is refused, not ignored", async () => {
    const res = await request(app.getHttpServer())
      .post("/api/auth/otp/request")
      .set("Content-Type", "application/json")
      .send("{bad")
      .expect(400);
    // the parser's refusal — not the route's "no phone given"
    expect(res.body.error).not.toBe("সঠিক মোবাইল নম্বর দিন");
  });

  it("the CMS takes a whole pack; elsewhere 100kb stays the limit", async () => {
    // reaches the auth check (401) — the 300kb body was accepted
    await request(app.getHttpServer()).put("/api/admin/cms/faq/draft").send(big(300_000)).expect(401);
    const res = await request(app.getHttpServer()).post("/api/auth/otp/request").send(big(300_000)).expect(413);
    expect(res.body.error).toBe("পাঠানো তথ্য খুব বড়");
  });
});
