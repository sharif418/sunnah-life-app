// Unit tests for the offline-sync conflict rule (src/shared/conflict.ts) —
// the exact Bengali reject reasons the web mirror produces.
// Phase C/W2g additions: client-timestamp clamping (no lying future clock
// can win LWW forever), catalog-driven value↔inputType validation, the
// guardSource allow-list, and serverValue on newerVersion rejections.
import {
  clampClientTs,
  CLIENT_TS_MAX_SKEW_MS,
  decideEntry,
  guardSource,
  lockedDatesFor,
  normalizeValue,
  REJECT_REASONS,
} from "src/shared/conflict";

const DEF_KEYS = new Set(["salat_fajr", "tilawat", "durood_100", "ishraq_done"]);
const DEF_TYPES = new Map([
  ["salat_fajr", "tri_state"],
  ["tilawat", "count"],
  ["durood_100", "count"],
  ["ishraq_done", "boolean"],
]);
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

describe("clampClientTs", () => {
  it("keeps past and slightly-future timestamps untouched", () => {
    const past = new Date("2025-06-14T10:00:00.000Z");
    expect(clampClientTs(past, now).getTime()).toBe(past.getTime());
    const nearFuture = new Date(now.getTime() + CLIENT_TS_MAX_SKEW_MS);
    expect(clampClientTs(nearFuture, now).getTime()).toBe(nearFuture.getTime());
  });
  it("clamps anything beyond now + 5 min to the cap", () => {
    const yearAhead = new Date(now.getTime() + 365 * 24 * 3_600_000);
    const clamped = clampClientTs(yearAhead, now);
    expect(clamped.getTime()).toBe(now.getTime() + CLIENT_TS_MAX_SKEW_MS);
  });
});

describe("guardSource", () => {
  it("keeps manual as-is", () => {
    expect(guardSource("manual")).toBe("manual");
  });
  it("keeps well-formed auto sources", () => {
    expect(guardSource("auto:prayer:fajr")).toBe("auto:prayer:fajr");
    expect(guardSource("auto:quran:tilawat")).toBe("auto:quran:tilawat");
    expect(guardSource("auto:reminder")).toBe("auto:reminder");
  });
  it("degrades free text, scripts and junk to manual", () => {
    expect(guardSource("auto:<script>alert(1)</script>")).toBe("manual");
    expect(guardSource("weird free text")).toBe("manual");
    expect(guardSource("")).toBe("manual");
    expect(guardSource("AUTO:PRAYER:FAJR")).toBe("manual"); // case-sensitive shape
    expect(guardSource("auto:prayer:fajr:extra")).toBe("manual");
    expect(guardSource("x".repeat(65))).toBe("manual");
  });
});

describe("decideEntry", () => {
  const base = { amalKey: "salat_fajr", date: "2025-06-14", value: "jamaat", clientUpdatedAt: "2025-06-14T10:00:00.000Z" };

  it("accepts a valid entry", () => {
    const d = decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now);
    expect(d.ok).toBe(true);
    if (d.ok) {
      expect(d.amalKey).toBe("salat_fajr");
      expect(d.value).toBe("jamaat");
      expect(d.source).toBe("manual");
    }
  });

  it("rejects incomplete entries (missing key/date/value, bad date shape)", () => {
    expect(decideEntry({ ...base, amalKey: "" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, date: "2025-6-4" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, date: "2025-02-30" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
    expect(decideEntry({ ...base, value: undefined }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.incomplete,
    });
  });

  it("rejects unknown amal keys", () => {
    expect(decideEntry({ ...base, amalKey: "not_in_catalog" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.unknownAmal,
    });
  });

  it("rejects future dates", () => {
    expect(decideEntry({ ...base, date: "2025-06-16" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.future,
    });
  });

  it("rejects locked days (unless unlocked)", () => {
    const locked = new Map([["2025-06-14", true]]);
    expect(decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, locked, null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.locked,
    });
    // same date unlocked → accepted
    expect(decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok).toBe(true);
  });

  it("rejects non-storable values", () => {
    expect(decideEntry({ ...base, value: { nested: true } }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.badValue,
    });
  });

  describe("value ↔ inputType (catalog-driven, W2g)", () => {
    it("tri_state definition: numeric value → badValue", () => {
      expect(decideEntry({ ...base, value: 3 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
        ok: false,
        reason: REJECT_REASONS.badValue,
      });
      expect(decideEntry({ ...base, value: "jamat" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
        ok: false,
        reason: REJECT_REASONS.badValue,
      });
      // all three legit tri-state values pass
      for (const v of ["jamaat", "alone", "qaza"]) {
        expect(decideEntry({ ...base, value: v }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok).toBe(true);
      }
    });

    it("count definition: tri-state string → badValue; sane numbers pass", () => {
      const countEntry = { ...base, amalKey: "tilawat", value: "jamaat" };
      expect(decideEntry(countEntry, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)).toMatchObject({
        ok: false,
        reason: REJECT_REASONS.badValue,
      });
      expect(
        decideEntry({ ...base, amalKey: "tilawat", value: 7 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok
      ).toBe(true);
      expect(
        decideEntry({ ...base, amalKey: "tilawat", value: 0 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok
      ).toBe(true);
      // out-of-range / negative numbers are rejected
      expect(
        decideEntry({ ...base, amalKey: "tilawat", value: -1 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)
      ).toMatchObject({ ok: false, reason: REJECT_REASONS.badValue });
      expect(
        decideEntry({ ...base, amalKey: "tilawat", value: 1_000_001 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)
      ).toMatchObject({ ok: false, reason: REJECT_REASONS.badValue });
    });

    it("boolean definition: numeric value → badValue", () => {
      expect(
        decideEntry({ ...base, amalKey: "ishraq_done", value: 3 }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now)
      ).toMatchObject({ ok: false, reason: REJECT_REASONS.badValue });
      expect(
        decideEntry({ ...base, amalKey: "ishraq_done", value: true }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok
      ).toBe(true);
      expect(
        decideEntry({ ...base, amalKey: "ishraq_done", value: false }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok
      ).toBe(true);
    });

    it("unknown inputType (catalog drift) → accepted", () => {
      const drift = new Map([["salat_fajr", "some_new_admin_type"]]);
      expect(decideEntry({ ...base, value: 42 }, DEF_KEYS, drift, TODAY, new Map(), null, now).ok).toBe(true);
      const empty = new Map<string, string>(); // key missing from defTypes entirely
      expect(decideEntry({ ...base, value: 42 }, DEF_KEYS, empty, TODAY, new Map(), null, now).ok).toBe(true);
    });
  });

  it("clamps a far-future clientUpdatedAt to now + 5 min (a lying clock can't win forever)", () => {
    const d = decideEntry(
      { ...base, clientUpdatedAt: new Date(now.getTime() + 365 * 24 * 3_600_000).toISOString() },
      DEF_KEYS,
      DEF_TYPES,
      TODAY,
      new Map(),
      null,
      now
    );
    expect(d.ok).toBe(true);
    if (d.ok) {
      expect(d.clientUpdatedAt.getTime()).toBe(now.getTime() + CLIENT_TS_MAX_SKEW_MS);
    }
    // …and the clamped ts still competes fairly against a same-instant row
    const existing = { amalKey: "salat_fajr", date: "2025-06-14", clientUpdatedAt: new Date(now.getTime() + CLIENT_TS_MAX_SKEW_MS) };
    const tie = decideEntry(
      { ...base, clientUpdatedAt: new Date(now.getTime() + 365 * 24 * 3_600_000).toISOString() },
      DEF_KEYS,
      DEF_TYPES,
      TODAY,
      new Map(),
      existing,
      now
    );
    expect(tie).toMatchObject({ ok: false, reason: REJECT_REASONS.newerVersion });
  });

  it("conflict rule: an existing entry with clientUpdatedAt >= incoming is refused", () => {
    const existing = { amalKey: "salat_fajr", date: "2025-06-14", clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z") };
    expect(decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, new Map(), existing, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.newerVersion,
    });
    // strictly newer incoming wins
    const newer = decideEntry(
      { ...base, clientUpdatedAt: "2025-06-14T10:00:00.001Z" },
      DEF_KEYS,
      DEF_TYPES,
      TODAY,
      new Map(),
      existing,
      now
    );
    expect(newer.ok).toBe(true);
  });

  it("newerVersion rejection carries the server's winning value (serverValue, W2g)", () => {
    const existing = {
      amalKey: "salat_fajr",
      date: "2025-06-14",
      clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z"),
      value: "alone",
    };
    const d = decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, new Map(), existing, now);
    expect(d).toMatchObject({ ok: false, reason: REJECT_REASONS.newerVersion, serverValue: "alone" });
    // numeric server values flow through too
    const countExisting = {
      amalKey: "tilawat",
      date: "2025-06-14",
      clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z"),
      value: 12,
    };
    const d2 = decideEntry(
      { ...base, amalKey: "tilawat", value: 3 },
      DEF_KEYS,
      DEF_TYPES,
      TODAY,
      new Map(),
      countExisting,
      now
    );
    expect(d2).toMatchObject({ ok: false, reason: REJECT_REASONS.newerVersion, serverValue: 12 });
    // no stored value → no serverValue key at all
    const bare = { amalKey: "salat_fajr", date: "2025-06-14", clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z") };
    const d3 = decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, new Map(), bare, now);
    expect(d3).toMatchObject({ ok: false, reason: REJECT_REASONS.newerVersion });
    expect("serverValue" in (d3 as object)).toBe(false);
  });

  it("clearing a prayer (\"\") is a valid tri-state value — the clear reaches the server", () => {
    expect(decideEntry({ ...base, value: "" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now).ok).toBe(true);
  });

  it("an identical replay is accepted unchanged — even on a locked day (guest import, lost response)", () => {
    const existing = {
      amalKey: "salat_fajr",
      date: "2025-06-14",
      clientUpdatedAt: new Date("2025-06-14T10:00:00.000Z"),
      value: "jamaat",
    };
    const locked = new Map([["2025-06-14", true]]);
    expect(decideEntry(base, DEF_KEYS, DEF_TYPES, TODAY, locked, existing, now)).toEqual({
      ok: true,
      amalKey: "salat_fajr",
      date: "2025-06-14",
      unchanged: true,
    });
    // a DIFFERENT value on a locked day is still refused
    expect(decideEntry({ ...base, value: "alone" }, DEF_KEYS, DEF_TYPES, TODAY, locked, existing, now)).toMatchObject({
      ok: false,
      reason: REJECT_REASONS.locked,
    });
  });

  it("a missing/invalid clientUpdatedAt falls back to server now", () => {
    const d = decideEntry({ ...base, clientUpdatedAt: "garbage" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now);
    expect(d.ok).toBe(true);
    if (d.ok) expect(d.clientUpdatedAt.getTime()).toBe(now.getTime());
  });

  it("source defaults to manual; custom source preserved", () => {
    const d = decideEntry({ ...base, source: "auto:prayer:fajr" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now);
    expect(d.ok && d.source).toBe("auto:prayer:fajr");
  });

  it("junk sources degrade to manual (guardSource applied inside decideEntry)", () => {
    const d = decideEntry({ ...base, source: "auto:<script>" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now);
    expect(d.ok && d.source).toBe("manual");
    const d2 = decideEntry({ ...base, source: "weird free text" }, DEF_KEYS, DEF_TYPES, TODAY, new Map(), null, now);
    expect(d2.ok && d2.source).toBe("manual");
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
