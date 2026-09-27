// Unit tests for the assessment rule engine: majority-per-section pass rule
// and the score percentage (src/assessments/assessments.controller.ts).
import { assessmentPassed, scorePctOf } from "src/assessments/assessments.controller";
import type { AssessmentTemplate } from "src/shared/domain";

const template: AssessmentTemplate = {
  key: "farze_ain_v1",
  version: 1,
  titleBn: "ফরযে আইন মূল্যায়ন",
  titleEn: "Farze Ain v1",
  sections: [
    {
      key: "iman",
      titleBn: "ঈমান",
      criteria: [
        { key: "i1", titleBn: "১" },
        { key: "i2", titleBn: "২" },
        { key: "i3", titleBn: "৩" },
      ],
    },
    {
      key: "akhlaq",
      titleBn: "আখলাক",
      criteria: [
        { key: "a1", titleBn: "১" },
        { key: "a2", titleBn: "২" },
      ],
    },
  ],
};

describe("assessmentPassed — strict majority (count×2 > total) of criteria ≥1 per section", () => {
  it("all 2s → passed", () => {
    const scores = { i1: { score: 2 }, i2: { score: 2 }, i3: { score: 2 }, a1: { score: 2 }, a2: { score: 2 } };
    expect(assessmentPassed(template, scores)).toBe(true);
  });

  it("a 2-criteria section needs BOTH ≥1 (strict majority: 2×2 > 2)", () => {
    // akhlaq has 2 criteria; one 0 → section fails even though iman passes.
    const scores = { i1: { score: 1 }, i2: { score: 1 }, i3: { score: 0 }, a1: { score: 1 }, a2: { score: 0 } };
    expect(assessmentPassed(template, scores)).toBe(false);
  });

  it("iman majority but akhlaq half-failed → not_yet (mirrors the seeded 01000000009 case)", () => {
    const scores = { i1: { score: 1 }, i2: { score: 1 }, i3: { score: 1 }, a1: { score: 1 }, a2: { score: 0 } };
    expect(assessmentPassed(template, scores)).toBe(false);
  });

  it("missing scores count as 0", () => {
    const scores = { i1: { score: 2 }, i2: { score: 2 } }; // i3, a1, a2 missing
    expect(assessmentPassed(template, scores)).toBe(false);
  });

  it("zero-criteria sections never block", () => {
    const empty: AssessmentTemplate = { ...template, sections: [{ key: "x", titleBn: "x", criteria: [] }] };
    expect(assessmentPassed(empty, {})).toBe(true);
  });
});

describe("scorePctOf", () => {
  it("maps the sum of scores onto 0–100 of the doubled maximum", () => {
    expect(scorePctOf({ a: { score: 2 }, b: { score: 2 }, c: { score: 2 } })).toBe(100);
    expect(scorePctOf({ a: { score: 1 }, b: { score: 2 }, c: { score: 0 } })).toBe(50);
    expect(scorePctOf({})).toBeNull();
  });
});
