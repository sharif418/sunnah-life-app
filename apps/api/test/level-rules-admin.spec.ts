// ─────────────────────────────────────────────────────────────────────────────
// level-rules-admin.spec.ts (W4h) — the full_admin level-rules editor:
//   • PURE validator: normalize + every rejection (unknown key, wrong types,
//     ranges, checklist shape, empty body)
//   • GET /api/admin/level-rules: full_admin sees the effective document with
//     per-level source (pack when nothing is overridden); usrah_head → 403;
//     unauth → 401
//   • PUT: merge semantics (unmentioned fields keep pack values), wrong
//     types → 400 with the field named, audit row level_rules_update, and the
//     ENGINE (GET /api/dawah/requirements) serves the new rule within the same
//     process (cache bust)
//   • DELETE: reset-to-pack + audit (meta.reset), idempotent second call
// Cleanup: the AppConfigRow "level_rules" row is hard-deleted in afterAll
// (audit rows stay — the goals pattern).
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import {
  invalidateLevelRulesCache,
  validateLevelRulesNode,
  LevelRulesValidationError,
} from "src/shared/levels";

const ADMIN = "01000000001"; // আব্দুল্লাহ আল মামুন — full_admin
const HEAD = "01000000003"; // মাওলানা ইউসুফ — usrah_head, level farze_ain_1

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;

async function signIn(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const res = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return res.body.accessToken as string;
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  rls = app.get(RlsService);
  http = () => request(app.getHttpServer());

  // no override row leaks between runs of this spec
  await rls.system((tx) => tx.appConfigRow.deleteMany({ where: { key: "level_rules" } }));
  invalidateLevelRulesCache();
});

afterAll(async () => {
  await rls.system((tx) => tx.appConfigRow.deleteMany({ where: { key: "level_rules" } }));
  invalidateLevelRulesCache();
  await app.close();
});

describe("validateLevelRulesNode (pure)", () => {
  it("normalizes a valid node: trims strings, keeps ints/bools", () => {
    const out = validateLevelRulesNode({
      titleBn: "  মুহিব্বুস সুন্নাহ ",
      minMonths: 6,
      requireAssessmentPassed: false,
      autoPromote: false,
      checklistBn: [{ key: " a ", categoryBn: " ঈমান ", label: " লক্ষ্য " }],
    });
    expect(out.titleBn).toBe("মুহিব্বুস সুন্নাহ");
    expect(out.minMonths).toBe(6);
    expect(out.requireAssessmentPassed).toBe(false);
    expect(out.checklistBn).toEqual([{ key: "a", categoryBn: "ঈমান", label: "লক্ষ্য" }]);
  });

  it("rejects unknown keys naming them", () => {
    expect(() => validateLevelRulesNode({ minMonths: 3, iqamaRequired: true })).toThrow(
      LevelRulesValidationError
    );
    try {
      validateLevelRulesNode({ iqamaRequired: true });
    } catch (e) {
      expect((e as Error).message).toContain("iqamaRequired");
    }
  });

  it.each([
    ["minMonths string", { minMonths: "6" }],
    ["negative minMonths", { minMonths: -1 }],
    ["huge minMonths", { minMonths: 500 }],
    ["bool as string", { autoPromote: "yes" }],
    ["label not string", { minMonthsLabelBn: 5 }],
    ["over-long label", { titleBn: "x".repeat(121) }],
    ["checklist not array", { checklistBn: { label: "x" } }],
    ["too many checklist items", { checklistBn: Array.from({ length: 101 }, () => ({ label: "x" })) }],
    ["checklist item missing label", { checklistBn: [{ key: "a" }] }],
    ["checklist item unknown field", { checklistBn: [{ label: "x", points: 3 }] }],
    ["empty body", {}],
  ])("rejects %s", (_name, body) => {
    expect(() => validateLevelRulesNode(body)).toThrow(LevelRulesValidationError);
  });

  it("drops an EMPTY assessmentKey (absent beats empty string)", () => {
    const out = validateLevelRulesNode({ assessmentKey: "   " });
    expect("assessmentKey" in out).toBe(false);
  });
});

describe("GET /api/admin/level-rules (e2e)", () => {
  let adminToken: string;

  it("unauthenticated → 401", async () => {
    await http().get("/api/admin/level-rules").expect(401);
  });

  it("usrah_head → 403 (editor is full_admin only)", async () => {
    const token = await signIn(HEAD);
    await http().get("/api/admin/level-rules").set("Authorization", `Bearer ${token}`).expect(403);
  });

  it("full_admin sees the pack document with source per level", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http()
      .get("/api/admin/level-rules")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    const { levels, packNote } = res.body;
    expect(Object.keys(levels).sort()).toEqual(["farze_ain_1", "farze_ain_2", "muhibbus_sunnah"]);
    expect(levels.muhibbus_sunnah.source).toBe("pack");
    expect(levels.muhibbus_sunnah.node.minMonths).toBe(4);
    expect(levels.muhibbus_sunnah.node.requireAssessmentPassed).toBe(false);
    expect(levels.muhibbus_sunnah.node.minReferralsAtLevel).toBe(5);
    expect(levels.farze_ain_1.node.assessmentKey).toBe("farze_ain_v1.1");
    expect(Array.isArray(levels.muhibbus_sunnah.node.checklistBn)).toBe(true);
    expect(levels.muhibbus_sunnah.node.checklistBn.length).toBeGreaterThanOrEqual(30);
    expect(typeof packNote).toBe("string");
  });

  it("unknown level param → 404", async () => {
    await http()
      .put("/api/admin/level-rules/muhibbus")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ minMonths: 5 })
      .expect(404);
  });
});

describe("PUT /api/admin/level-rules/:level (e2e)", () => {
  let adminToken: string;
  let headToken: string;

  it("usrah_head cannot write → 403", async () => {
    headToken = await signIn(HEAD);
    await http()
      .put("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${headToken}`)
      .send({ minMonths: 9 })
      .expect(403);
  });

  it("invalid field type → 400 naming the field", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http()
      .put("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ minMonths: "six" })
      .expect(400);
    expect(res.body.error).toContain("minMonths");
  });

  it("unknown field → 400 naming the field", async () => {
    const res = await http()
      .put("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ minWeeks: 2 })
      .expect(400);
    expect(res.body.error).toContain("minWeeks");
  });

  it("valid PUT: merges over the pack node, source flips to db, audited", async () => {
    const res = await http()
      .put("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ minMonths: 6, minMonthsLabelBn: "সময়সীমাঃ সর্বনিম্ন ৬ মাস" })
      .expect(200);
    expect(res.body.level).toBe("muhibbus_sunnah");
    expect(res.body.changed).toContain("minMonths");
    // merge: the pack's other fields survive
    expect(res.body.node.requireAssessmentPassed).toBe(false);
    expect(res.body.node.minReferralsAtLevel).toBe(5);
    expect(Array.isArray(res.body.node.checklistBn)).toBe(true);

    const get = await http()
      .get("/api/admin/level-rules")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(get.body.levels.muhibbus_sunnah.source).toBe("db");
    expect(get.body.levels.muhibbus_sunnah.node.minMonths).toBe(6);
    // the other levels are untouched (still pack)
    expect(get.body.levels.farze_ain_1.source).toBe("pack");

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({
        where: { action: "level_rules_update", targetType: "level_rules" },
        orderBy: { createdAt: "desc" },
      })
    );
    expect(audit).not.toBeNull();
    expect((audit!.metaJson as Record<string, unknown>).level).toBe("muhibbus_sunnah");
    expect((audit!.metaJson as Record<string, unknown>).changed).toContain("minMonths");
  });

  it("the ENGINE serves the new rule (requirements checklist label + target)", async () => {
    // the head (farze_ain_1) sees farze_ain_2's requirements next — edit that level
    await http()
      .put("/api/admin/level-rules/farze_ain_2")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ minMonths: 3 })
      .expect(200);

    const res = await http()
      .get("/api/dawah/requirements")
      .set("Authorization", `Bearer ${headToken}`)
      .expect(200);
    const row = (res.body.requirements as { key: string; target?: number | null }[]).find(
      (r) => r.key === "min_months"
    );
    expect(row).toBeDefined();
    expect(row!.target).toBe(3);
  });
});

describe("DELETE /api/admin/level-rules/:level (reset to pack, e2e)", () => {
  let adminToken: string;

  it("resets the override (audited) and is idempotent", async () => {
    adminToken = await signIn(ADMIN);
    const res = await http()
      .delete("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.reset).toBe(true);

    const audit = await rls.system((tx) =>
      tx.auditLog.findFirst({
        where: { action: "level_rules_update", targetType: "level_rules" },
        orderBy: { createdAt: "desc" },
      })
    );
    expect((audit!.metaJson as Record<string, unknown>).reset).toBe(true);

    const again = await http()
      .delete("/api/admin/level-rules/muhibbus_sunnah")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(again.body.reset).toBe(false); // nothing left to reset

    const get = await http()
      .get("/api/admin/level-rules")
      .set("Authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(get.body.levels.muhibbus_sunnah.source).toBe("pack");
    expect(get.body.levels.muhibbus_sunnah.node.minMonths).toBe(4);
    // farze_ain_2 override is still there (per-level reset)
    expect(get.body.levels.farze_ain_2.source).toBe("db");
  });
});
