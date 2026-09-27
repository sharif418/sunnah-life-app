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

describe("locking rule (Ishraq of D+1)", () => {
  it("a date ~2 days ago is locked; today never is", () => {
    const today = bdToday();
    const twoDaysAgo = new Date(bdNowShifted() - 2 * 86400_000).toISOString().slice(0, 10);
    expect(isDateLocked(USER, twoDaysAgo)).toBe(true);
    expect(isDateLocked(USER, today)).toBe(false);
  });
  it("the deadline is morning of the next day (Ishraq ≈ sunrise+20m)", () => {
    const deadline = computeLockDeadline("2025-06-14", USER);
    const nextMidnight = Date.UTC(2025, 5, 15); // Dhaka-shifted domain
    const hours = (deadline - nextMidnight) / 3_600_000;
    expect(hours).toBeGreaterThan(5); // after sunrise everywhere in BD
    expect(hours).toBeLessThan(8); // but still morning
  });
});
