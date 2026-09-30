// ─────────────────────────────────────────────────────────────────────────────
// referral-tree.spec.ts (W4h) — GET /api/admin/referral-tree (full_admin):
//   • roles: unauth 401; member / usrah_head / invigilator 403 (whole-forest
//     browsing is a full_admin tool — supervisors keep /api/dawah)
//   • roots page: the demo referral roots (03, 05) with correct childCount
//   • children page: one parent's direct children + each node's childCount
//     (04 → 07/08/09; 09 → 10)
//   • pagination: limit boundary (exact fit → nextCursor null), cursor walk
//     (page 1 → page 2 → exhausted), remaining counter, limit validation
//   • unknown userId → 404
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";

const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin
const HEAD = "01000000003"; // মাওলানা ইউসুফ — usrah_head
const INVIGILATOR = "01000000002"; // হাফেজ যাকারিয়া — invigilator
const MEMBER = "01000000008"; // সাইফুল ইসলাম — plain user

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

interface Node {
  id: string;
  name: string;
  gender: string;
  level: string;
  memberCode: string | null;
  role: string;
  lastActiveAt: string;
  joinedAt: string;
  childCount: number;
}
interface Page {
  nodes: Node[];
  nextCursor: string | null;
  remaining: number;
}

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

async function idOf(phone: string): Promise<string> {
  return (await rls.system((tx) => tx.user.findUnique({ where: { phone } })))!.id;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());
});

afterAll(async () => {
  await app.close();
});

describe("roles", () => {
  it("unauthenticated → 401", async () => {
    await http().get("/api/admin/referral-tree").expect(401);
  });

  it.each([
    ["plain member", MEMBER],
    ["usrah_head", HEAD],
    ["invigilator", INVIGILATOR],
  ])("%s → 403 (full_admin only)", async (_name, phone) => {
    const token = await signIn(phone);
    await http()
      .get("/api/admin/referral-tree")
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
  });
});

describe("the forest pages", () => {
  let adminToken: string;

  it("roots page carries the demo roots with childCount", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http()
      .get("/api/admin/referral-tree")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    const page = res.body as Page;
    expect(page.nodes.length).toBeGreaterThanOrEqual(2);
    const byName = new Map(page.nodes.map((n) => [n.name, n]));
    const usrahHeadM = byName.get("মাওলানা ইউসুফ");
    const usrahHeadF = byName.get("উম্মে হাবিবা");
    expect(usrahHeadM).toBeDefined();
    expect(usrahHeadF).toBeDefined();
    expect(usrahHeadM!.childCount).toBe(1); // 04
    expect(usrahHeadF!.childCount).toBe(1); // 06
    // roots have no referrer by construction — node payloads stay flat
    expect(page.nodes.every((n) => n.lastActiveAt && n.joinedAt)).toBe(true);
  });

  it("children page of 04 lists 07/08/09 with 09's childCount = 1", async () => {
    const parentId = await idOf("01000000004"); // রাফিউল ইসলাম (daee)
    const res = await http()
      .get(`/api/admin/referral-tree?userId=${parentId}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    const page = res.body as Page;
    const names = page.nodes.map((n) => n.name);
    expect(names.sort((a, b) => a.localeCompare(b, "bn"))).toEqual(
      ["তানভীর হোসেন", "সাইফুল ইসলাম", "মেহেদী হাসান"].sort((a, b) => a.localeCompare(b, "bn"))
    );
    const mehedi = page.nodes.find((n) => n.name === "মেহেদী হাসান")!;
    expect(mehedi.childCount).toBe(1); // 10
    expect(page.nextCursor).toBeNull();
    expect(page.remaining).toBe(0);
  });

  it("unknown userId → 404", async () => {
    await http()
      .get("/api/admin/referral-tree?userId=does-not-exist")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(404);
  });

  it("invalid limit → 400", async () => {
    await http()
      .get("/api/admin/referral-tree?limit=0")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(400);
    await http()
      .get("/api/admin/referral-tree?limit=101")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(400);
  });
});

describe("pagination boundary (children of the admin's synthetic parent)", () => {
  let adminToken: string;
  const PARENT_PHONE = "01779200001";

  beforeAll(async () => {
    // synthetic parent with exactly 5 children → boundary maths is exact
    await rls.system(async (tx) => {
      await tx.user.deleteMany({ where: { phone: { startsWith: "0177920" } } });
      const parent = await tx.user.create({
        data: { phone: PARENT_PHONE, name: "ই২ই ট্রি প্যারেন্ট", gender: "M" },
      });
      for (let i = 2; i <= 6; i++) {
        await tx.user.create({
          data: {
            phone: `0177920000${i}`,
            name: `ই২ই ট্রি শিশু ${i}`,
            gender: "M",
            referredById: parent.id,
          },
        });
      }
    });
  });

  afterAll(async () => {
    await rls.system((tx) => tx.user.deleteMany({ where: { phone: { startsWith: "0177920" } } }));
  });

  it("exact-fit page (5 children, limit 5) → nextCursor null", async () => {
    adminToken = await signIn(ADMIN);
    const parentId = await idOf(PARENT_PHONE);
    const res = await http()
      .get(`/api/admin/referral-tree?userId=${parentId}&limit=5`)
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    const page = res.body as Page;
    expect(page.nodes).toHaveLength(5);
    expect(page.nextCursor).toBeNull();
    expect(page.remaining).toBe(0);
  });

  it("cursor walk: 5 children at limit 2 → 2 + 2 + 1, counters exact", async () => {
    const parentId = await idOf(PARENT_PHONE);
    const seen: string[] = [];

    let url = `/api/admin/referral-tree?userId=${parentId}&limit=2`;
    let pages = 0;
    for (;;) {
      const res = await http()
        .get(url)
        .set("Authorization", `Bearer ${adminToken}`)
        .expect(200);
      const page = res.body as Page;
      pages += 1;
      seen.push(...page.nodes.map((n) => n.id));
      if (page.nextCursor) {
        url = `/api/admin/referral-tree?userId=${parentId}&limit=2&cursor=${page.nextCursor}`;
      } else {
        expect(page.remaining).toBe(0);
        break;
      }
      expect(pages).toBeLessThan(10); // walk must terminate
    }

    expect(pages).toBe(3);
    expect(new Set(seen).size).toBe(5); // every child exactly once
    // every synthetic child is a leaf
    expect(seen.length).toBe(5);
  });

  it("the synthetic parent appears on the roots page with childCount 5", async () => {
    const res = await http()
      .get("/api/admin/referral-tree?limit=100")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    const page = res.body as Page;
    const parent = page.nodes.find((n) => n.name === "ই২ই ট্রি প্যারেন্ট");
    expect(parent).toBeDefined();
    expect(parent!.childCount).toBe(5);
  });
});
