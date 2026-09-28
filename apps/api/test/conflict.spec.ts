// Unit tests for the offline-sync conflict rule (src/shared/conflict.ts) —
// the exact Bengali reject reasons the web mirror produces.
import { decideEntry, lockedDatesFor, normalizeValue, REJECT_REASONS } from "src/shared/conflict";

const DEF_KEYS = new Set(["salat_fajr", "tilawat", "durood_100"]);
const TODAY = "2025-06-15";
const now = new Date("2025-06-15T12:00:00.000Z");

describe("normalizeValue", () => {
  it("accepts booleans, finite numbers and strings", () => {
    expect(normalizeValue(true)).toBe(true);
    expect(normalizeValue(3)).toBe(3);
    expect(normalizeValue("jamaat")).toBe("jamaat");
  });
  it("rejects null, undefined, objects, NaN, Infinity", () => {
    expect(normalizeValue(null)).toBeNull();
    expect(normalizeValue(undefined)).toBeNull();
    expect(normalizeValue({})).toBeNull();
    expect(normalizeValue([1])).toBeNull();
    expect(normalizeValue(Number.NaN)).toBeNull();
    expect(normalizeValue(Number.POSITIVE_INFINITY)).toBeNull();
  });
});

describe("decideEntry", () => {
  const base = { amalKey: "salat_fajr", date: "2025-06-14", value: "jamaat", clientUpdatedAt: "2025-06-14T10:00:00.000Z" };

  it("accepts a valid entry", () => {
    const d = decideEntry(base, DEF_KEYS, TODAY, new Map(), null, now);
    expect(d.ok).toBe(true);
    if (d.ok) {
      expect(d.amalKey).toBe("salat_fajr");
      expect(d.value).toBe("jamaat");
      expect(d.source).toBe("manual");
    }
  });

  it("rejects incomplete entries (missing key/date/value, bad date shape)", () => {
    expect(decideEntry({ ...base, amalKey: "" }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, date: "2025-6-4" }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, date: "2025-02-30" }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, value: undefined }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
  });

  it("rejects unknown amal keys", () => {
    expect(decideEntry({ ...base, amalKey: "not_in_catalog" }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.unknownAmal,
    });
  });

  it("rejects future dates", () => {
    expect(decideEntry({ ...base, date: "2025-06-16" }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.future,
    });
  });

  it("rejects locked days (unless unlocked)", () => {
    const locked = new Map([["2025-06-14", true]]);
    expect(decideEntry(base, DEF_KEYS, TODAY, locked, null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.locked,
    });
    // same date unlocked → accepted
    expect(decideEntry(base, DEF_KEYS, TODAY, new Map(), null, now).ok).toBe(true);
  });

  it("rejects non-storable values", () => {
    expect(decideEntry({ ...base, value: { nested: true } }, DEF_KEYS, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.badValue,
    });
  });

  it("conflict rule: an existing entry with clientUpdatedAt >= incoming is refused", () => {
    const existing = { amalKey: "salat_fajr", date: "2025-06-14", clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z") };
    expect(decideEntry(base, DEF_KEYS, TODAY, new Map(), existing, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.newerVersion,
    });
    // strictly newer incoming wins
    const newer = decideEntry(
      { ...base, clientUpdatedAt: "2025-06-14T10:00:00.001Z" },
      DEF_KEYS,
      TODAY,
      new Map(),
      existing,
      now
    );
    expect(newer.ok).toBe(true);
  });

  it("a missing/invalid clientUpdatedAt falls back to server now", () => {
    const d = decideEntry({ ...base, clientUpdatedAt: "garbage" }, DEF_KEYS, TODAY, new Map(), null, now);
    expect(d.ok).toBe(true);
    if (d.ok) expect(d.clientUpdatedAt.getTime()).toBe(now.getTime());
  });

  it("source defaults to manual; custom source preserved", () => {
    const d = decideEntry({ ...base, source: "auto:prayer:fajr" }, DEF_KEYS, TODAY, new Map(), null, now);
    expect(d.ok && d.source).toBe("auto:prayer:fajr");
  });
});

describe("lockedDatesFor", () => {
  it("locks past dates but never the future or today-unless-locked", () => {
    const dates = ["2025-06-10", "2025-06-15", "2025-06-20"];
    const isLocked = (_u: unknown, date: string) => date === "2025-06-15"; // pretend today just locked
    const m = lockedDatesFor({ lat: null, lng: null, calcMethod: "karachi", madhhab: "hanafi" }, dates, new Set(["2025-06-10"]), TODAY, isLocked);
    expect(m.get("2025-06-10")).toBe(false); // unlocked override
    expect(m.get("2025-06-15")).toBe(true);
    expect(m.get("2025-06-20")).toBe(false); // future can't be locked
  });
});
