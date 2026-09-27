// Unit tests (B6) for the level rule engine:
//   • buildLevelChecklist — the met/not-met matrix shared by the member
//     checklist, the admin promote gate and the nightly auto-promotion
//   • requireBengaliReason — the promote/gender-change justification validator
import { buildLevelChecklist, DEFAULT_LEVEL_RULES, monthsInLevelOf } from "src/shared/levels";
import { requireBengaliReason } from "src/levels/levels.service";
import { ApiError } from "src/common/api-error";

/** ApiError carries the Bengali message in getResponse() ({error: msg}). */
function messageOf(fn: () => unknown): string {
  try {
    fn();
    return "";
  } catch (e) {
    return String(((e as ApiError).getResponse() as { error: string }).error);
  }
}

const rules = {
  ...DEFAULT_LEVEL_RULES,
  minMonths: 4,
  minReferralsAtLevel: 5,
  autoPromote: true,
  checklist: [
    { key: "iman", label: "ঈমান: ঈমানের অপরিহার্য পাঠ সম্পন্ন" },
    { key: "ilm", label: "ইলম: মূল শিক্ষা অর্জন" },
  ],
};

describe("buildLevelChecklist — met/not-met matrix", () => {
  it("nothing met → allMet false, autoEligible false", () => {
    const c = buildLevelChecklist(rules, { months: 0, assessmentPassed: false, referralsAtLevel: 0 });
    expect(c.allMet).toBe(false);
    expect(c.autoEligible).toBe(false);
    const byKey = Object.fromEntries(c.rows.map((r) => [r.key, r]));
    expect(byKey.min_months.met).toBe(false);
    expect(byKey.min_months.current).toBe(0);
    expect(byKey.min_months.target).toBe(4);
    expect(byKey.assessment_passed.met).toBe(false);
    expect(byKey.assessment_passed.current).toBe(0);
    expect(byKey.min_referrals.met).toBe(false);
    expect(byKey.min_referrals.current).toBe(0);
  });

  it("months exactly at target → met (boundary)", () => {
    const c = buildLevelChecklist(rules, { months: 4, assessmentPassed: false, referralsAtLevel: 0 });
    const months = c.rows.find((r) => r.key === "min_months")!;
    expect(months.met).toBe(true);
  });

  it("months below target → not met", () => {
    const c = buildLevelChecklist(rules, { months: 3, assessmentPassed: false, referralsAtLevel: 0 });
    const months = c.rows.find((r) => r.key === "min_months")!;
    expect(months.met).toBe(false);
  });

  it("referrals exactly at target → met; below → not met", () => {
    const at = buildLevelChecklist(rules, { months: 4, assessmentPassed: true, referralsAtLevel: 5 });
    expect(at.rows.find((r) => r.key === "min_referrals")!.met).toBe(true);
    expect(at.allMet).toBe(true);
    expect(at.autoEligible).toBe(true);

    const below = buildLevelChecklist(rules, { months: 4, assessmentPassed: true, referralsAtLevel: 4 });
    expect(below.rows.find((r) => r.key === "min_referrals")!.met).toBe(false);
    expect(below.allMet).toBe(false);
  });

  it("assessment passed at exactly 1 → met", () => {
    const c = buildLevelChecklist(rules, { months: 4, assessmentPassed: true, referralsAtLevel: 5 });
    const a = c.rows.find((r) => r.key === "assessment_passed")!;
    expect(a.met).toBe(true);
    expect(a.current).toBe(1);
    expect(a.target).toBe(1);
  });

  it("assessment rule drops out when requireAssessmentPassed = false", () => {
    const noExam = { ...rules, requireAssessmentPassed: false };
    const c = buildLevelChecklist(noExam, { months: 4, assessmentPassed: false, referralsAtLevel: 5 });
    expect(c.rows.some((r) => r.key === "assessment_passed")).toBe(false);
    expect(c.allMet).toBe(true);
  });

  it("informational checklist items are present, NOT auto-checked and never block", () => {
    const c = buildLevelChecklist(rules, { months: 4, assessmentPassed: true, referralsAtLevel: 5 });
    const info = c.rows.filter((r) => !r.autoChecked);
    expect(info.map((r) => r.key).sort()).toEqual(["checklist_ilm", "checklist_iman"]);
    for (const r of info) {
      expect(r.met).toBe(false);
      expect(r.current).toBeNull();
      expect(r.target).toBeNull();
    }
    expect(c.allMet).toBe(true); // machine rules all met
    expect(c.autoEligible).toBe(true); // …and autoPromote enabled
  });

  it("autoPromote=false → allMet true but autoEligible false (admin override only)", () => {
    const locked = { ...rules, autoPromote: false };
    const c = buildLevelChecklist(locked, { months: 4, assessmentPassed: true, referralsAtLevel: 5 });
    expect(c.allMet).toBe(true);
    expect(c.autoEligible).toBe(false);
  });
});

describe("monthsInLevelOf — whole 30.44-day months", () => {
  it("null levelStartedAt → 0 months", () => {
    expect(monthsInLevelOf({ levelStartedAt: null })).toBe(0);
  });
  it("130 days → 4 whole months", () => {
    expect(monthsInLevelOf({ levelStartedAt: new Date(Date.now() - 130 * 86400000).toISOString() })).toBe(4);
  });
  it("91 days → 2 whole months (not 3)", () => {
    expect(monthsInLevelOf({ levelStartedAt: new Date(Date.now() - 91 * 86400000).toISOString() })).toBe(2);
  });
});

describe("requireBengaliReason — promote/gender-change justification", () => {
  it("accepts a Bengali reason and trims it", () => {
    expect(requireBengaliReason("  তারবিয়াত পরিষদের সিদ্ধান্ত  ")).toBe("তারবিয়াত পরিষদের সিদ্ধান্ত");
  });

  it("rejects empty / whitespace", () => {
    expect(() => requireBengaliReason("")).toThrow(ApiError);
    expect(messageOf(() => requireBengaliReason(""))).toBe("কারণ লিখুন");
    expect(messageOf(() => requireBengaliReason("   "))).toBe("কারণ লিখুন");
  });

  it("rejects a too-short reason", () => {
    expect(messageOf(() => requireBengaliReason("ab"))).toBe("কারণ আরও বিস্তারিত লিখুন");
  });

  it("rejects non-Bengali text (must be readable by members)", () => {
    expect(messageOf(() => requireBengaliReason("approved by council"))).toBe("কারণ বাংলায় লিখুন");
    expect(messageOf(() => requireBengaliReason("12345"))).toBe("কারণ বাংলায় লিখুন");
  });

  it("rejects non-string input", () => {
    expect(messageOf(() => requireBengaliReason(undefined))).toBe("কারণ লিখুন");
    expect(messageOf(() => requireBengaliReason(null))).toBe("কারণ লিখুন");
  });

  it("caps the length at 500 chars", () => {
    const long = "ক".repeat(600);
    expect(requireBengaliReason(long).length).toBe(500);
  });
});
