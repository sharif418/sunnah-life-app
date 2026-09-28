// Unit tests for the pure parts of the amal engine (src/shared/amal.ts):
// points maths, completion %, Dhaka wall-clock helpers and the Ishraq-of-D+1
// locking rule. (The majority-per-section assessment rule is covered in
// assessment.spec.ts.)
import {
  amalPoints,
  bdToday,
  completionPctFromEntries,
  computeLockDeadline,
  bdNowShifted,
  isDateLocked,
  isValidDateKey,
  lastNDayKeys,
} from "src/shared/amal";
import type { AmalDefinition } from "src/shared/domain";

const def = (inputType: string, target?: Record<string, number>): AmalDefinition =>
  ({
    key: "x",
    titleBn: "টেস্ট",
    titleEn: "test",
    category: "salah",
    inputType,
    cadence: "daily",
    target: target ?? null,
    unit: null,
    minLevel: "none",
    sortOrder: 0,
    autoSource: null,
  }) as AmalDefinition;

const USER = { lat: null, lng: null, calcMethod: "karachi" as const, madhhab: "hanafi" as const };

describe("amalPoints", () => {
  it("tristate: jamaat/alone = 1, qaza = 0", () => {
    expect(amalPoints("jamaat", def("tristate"), "general")).toBe(1);
    expect(amalPoints("alone", def("tristate"), "general")).toBe(1);
    expect(amalPoints("qaza", def("tristate"), "general")).toBe(0);
  });
  it("boolean: true = 1", () => {
    expect(amalPoints(true, def("boolean"), "general")).toBe(1);
    expect(amalPoints(false, def("boolean"), "general")).toBe(0);
  });
  it("count/quantity: >= target = 1, below target = 0.5, zero = 0", () => {
    const d = def("count", { general: 5, hafez: 10, alim: 10 });
    expect(amalPoints(5, d, "general")).toBe(1);
    expect(amalPoints(3, d, "general")).toBe(0.5);
    expect(amalPoints(0, d, "general")).toBe(0);
    // category-specific target lookup
    expect(amalPoints(10, d, "hafez")).toBe(1);
    expect(amalPoints(5, d, "hafez")).toBe(0.5);
    expect(amalPoints("7", d, "general")).toBe(1); // numeric string coerced
  });
  it("text: non-empty = 1", () => {
    expect(amalPoints("নোট", def("text"), "general")).toBe(1);
    expect(amalPoints("   ", def("text"), "general")).toBe(0);
  });
});

describe("completionPctFromEntries", () => {
  it("computes rounded, clamped completion over the daily definitions", () => {
    const defs = [def("tristate"), def("boolean")].map((d, i) => ({ ...d, key: `k${i}` }));
    const days = ["2025-06-14", "2025-06-15"];
    // expected = 2 defs × 2 days = 4 points; jamaat(1) + qaza(0) + true(1) = 2 → 50%
    const entries = [
      { amalKey: "k0", valueJson: "jamaat" },
      { amalKey: "k0", valueJson: "qaza" },
      { amalKey: "k1", valueJson: true },
    ];
    expect(completionPctFromEntries(entries, defs, "general", days)).toBe(50);
    // perfect diary → 100
    const perfect = [
      { amalKey: "k0", valueJson: "alone" },
      { amalKey: "k0", valueJson: "jamaat" },
      { amalKey: "k1", valueJson: true },
      { amalKey: "k1", valueJson: true },
    ];
    expect(completionPctFromEntries(perfect, defs, "general", days)).toBe(100);
  });
  it("unknown keys and empty entries → 0", () => {
    expect(completionPctFromEntries([], [def("tristate")], "general", ["2025-06-14"])).toBe(0);
    expect(
      completionPctFromEntries([{ amalKey: "nope", valueJson: true }], [def("boolean")], "general", ["2025-06-14"])
    ).toBe(0);
  });
});

describe("Dhaka wall-clock helpers", () => {
  it("bdToday is a valid YYYY-MM-DD", () => {
    expect(isValidDateKey(bdToday())).toBe(true);
  });
  it("lastNDayKeys returns n ascending keys ending today", () => {
    const keys = lastNDayKeys(7);
    expect(keys).toHaveLength(7);
    expect(keys[6]).toBe(bdToday());
    expect(keys[0] < keys[6]).toBe(true);
  });
});

describe("locking rule (Ishraq of D+1, real-epoch per user tz)", () => {
  it("a date ~2 days ago is locked; today never is", () => {
    const today = bdToday();
    const twoDaysAgo = new Date(Date.now() - 2 * 86400_000).toISOString().slice(0, 10);
    expect(isDateLocked(USER, twoDaysAgo)).toBe(true);
    expect(isDateLocked(USER, today)).toBe(false);
  });
  it("the deadline is morning of the next day (Ishraq ≈ sunrise+20m) in the user's zone", () => {
    // Dhaka user (June): ishraq ≈ 05:31 wall → real epoch 23:31Z the day before.
    const deadline = computeLockDeadline("2025-06-14", USER);
    expect(new Date(deadline).toISOString()).toBe("2025-06-14T23:31:00.000Z");
    // …which in the USER's OWN wall clock is 2025-06-15 ~05:31 — morning.
    const wall = new Date(deadline + 6 * 3_600_000).toISOString();
    expect(wall.startsWith("2025-06-15T05:3")).toBe(true);
  });
  it("a London user (London coords) gets a different instant (tz honored)", () => {
    // The zone alone re-labels the wall clock; a REAL London user also has
    // London coordinates — sunrise there is a different SOLAR instant.
    const londonUser = { ...USER, lat: 51.5074, lng: -0.1278, tz: "Europe/London" };
    const dhaka = computeLockDeadline("2025-06-14", USER);
    const london = computeLockDeadline("2025-06-14", londonUser);
    // Dhaka deadline ≈ 23:31Z; London ishraq ≈ 05:0x BST ≈ 04:0xZ → ~4.5 h apart
    const diffH = Math.abs(dhaka - london) / 3_600_000;
    expect(diffH).toBeGreaterThan(3.5);
    expect(diffH).toBeLessThan(6.5);
    // and the London deadline must land in London's morning wall clock
    expect(new Date(london).toISOString().startsWith("2025-06-15T0")).toBe(true);
  });
});
