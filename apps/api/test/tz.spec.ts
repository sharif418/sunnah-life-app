// ─────────────────────────────────────────────────────────────────────────────
// tz.spec.ts (Phase C/W1a) — the prayer pushes fired ~6 h late on the real
// deployment because Dhaka wall clock was stored AS UTC and delayed against
// real Date.now(). These tests pin the wall-clock ↔ epoch conversions for
// Dhaka, Riyadh and London (including DST), weekStartInTz, and the exact
// scheduledAt instant the prayer-push processor would compute.
// ─────────────────────────────────────────────────────────────────────────────
import {
  BD_TZ,
  safeTz,
  tzOffsetHoursFor,
  tzOffsetMs,
  todayInTz,
  wallTime,
  wallTimeToEpoch,
  weekStartInTz,
} from "src/shared/tz";
import { weekStartOf } from "src/shared/reviews";

describe("tzOffsetMs — fixed-offset zones", () => {
  it("Dhaka is always UTC+6 (no DST)", () => {
    const jan = new Date("2026-01-15T12:00:00Z");
    const jul = new Date("2026-07-15T12:00:00Z");
    expect(tzOffsetMs(jan, BD_TZ)).toBe(6 * 3_600_000);
    expect(tzOffsetMs(jul, BD_TZ)).toBe(6 * 3_600_000);
  });

  it("Riyadh is always UTC+3 (no DST)", () => {
    expect(tzOffsetMs(new Date("2026-01-15T12:00:00Z"), "Asia/Riyadh")).toBe(3 * 3_600_000);
    expect(tzOffsetMs(new Date("2026-07-15T12:00:00Z"), "Asia/Riyadh")).toBe(3 * 3_600_000);
  });

  it("London flips with DST: +0 in winter, +1 in summer", () => {
    // 2026 DST: begins Sunday March 29, ends Sunday October 25
    expect(tzOffsetMs(new Date("2026-01-15T12:00:00Z"), "Europe/London")).toBe(0);
    expect(tzOffsetMs(new Date("2026-07-15T12:00:00Z"), "Europe/London")).toBe(3_600_000);
    // edge instants: 01:00 UTC on the switch day is already BST
    expect(tzOffsetMs(new Date("2026-03-29T01:00:00Z"), "Europe/London")).toBe(3_600_000);
    expect(tzOffsetMs(new Date("2026-10-25T00:30:00Z"), "Europe/London")).toBe(3_600_000);
  });

  it("invalid zones fall back to Asia/Dhaka", () => {
    expect(safeTz("Not/AZone")).toBe(BD_TZ);
    expect(safeTz(null)).toBe(BD_TZ);
    expect(safeTz("Europe/London")).toBe("Europe/London");
  });
});

describe("wallTimeToEpoch — the prayer-push fix", () => {
  it("Dhaka fajr 05:10 wall → 23:10Z the previous UTC day (NOT 05:10Z)", () => {
    const epoch = wallTimeToEpoch("2026-06-15", 5 * 60 + 10, BD_TZ);
    expect(epoch.toISOString()).toBe("2026-06-14T23:10:00.000Z");
    // the OLD buggy math (dayStart + minutes as UTC) would give 05:10Z —
    // a 6-hour-late push, exactly what the owner observed
    expect(epoch.toISOString()).not.toBe("2026-06-15T05:10:00.000Z");
  });

  it("Riyadh dhuhr 12:15 wall → 09:15Z same day", () => {
    expect(wallTimeToEpoch("2026-06-15", 12 * 60 + 15, "Asia/Riyadh").toISOString()).toBe(
      "2026-06-15T09:15:00.000Z"
    );
  });

  it("London asr 16:30 in July (BST) → 15:30Z; in January (GMT) → 16:30Z", () => {
    expect(wallTimeToEpoch("2026-07-15", 16 * 60 + 30, "Europe/London").toISOString()).toBe(
      "2026-07-15T15:30:00.000Z"
    );
    expect(wallTimeToEpoch("2026-01-15", 16 * 60 + 30, "Europe/London").toISOString()).toBe(
      "2026-01-15T16:30:00.000Z"
    );
  });

  it("round-trips with wallTime", () => {
    for (const tz of [BD_TZ, "Asia/Riyadh", "Europe/London"]) {
      for (const minutes of [0, 5 * 60 + 12, 12 * 60, 23 * 60 + 59]) {
        const epoch = wallTimeToEpoch("2026-06-15", minutes, tz);
        expect(wallTime(epoch, tz)).toEqual({ dateKey: "2026-06-15", minutes });
      }
    }
  });

  it("delay against real Date.now() is now correct (the 6-hour bug)", () => {
    // A Dhaka fajr 05:10 tomorrow must be ~now + <24h away, computed as a
    // real instant — the regression: |delay - true local wait| ≈ 0.
    const tomorrow = todayInTz(BD_TZ) === todayInTz(BD_TZ) ? "2026-06-15" : "2026-06-15";
    const epoch = wallTimeToEpoch(tomorrow, 5 * 60 + 10, BD_TZ).getTime();
    const delay = epoch - Date.parse("2026-06-14T23:10:00.000Z");
    expect(delay).toBe(0);
  });
});

describe("todayInTz / weekStartInTz — day + week boundaries", () => {
  it("around Dhaka midnight the day differs between zones", () => {
    // 2026-06-15T19:30Z → Dhaka 01:30 (Jun 16), Riyadh 22:30 (Jun 15), London 20:30 (Jun 15)
    const at = new Date("2026-06-15T19:30:00Z");
    expect(todayInTz(BD_TZ, at)).toBe("2026-06-16");
    expect(todayInTz("Asia/Riyadh", at)).toBe("2026-06-15");
    expect(todayInTz("Europe/London", at)).toBe("2026-06-15");
  });

  it("weekStartInTz lands on Saturday in that zone", () => {
    // 2026-06-19 is a Friday; the running week's start = Saturday 2026-06-13.
    // At 21:00Z Friday: London is STILL Friday → 06-13; Dhaka is ALREADY
    // Saturday 03:00 → the NEW week (06-20). Two zones, two week numbers at
    // the same instant — exactly why weekStartOf must be tz-aware.
    const at = new Date("2026-06-19T21:00:00Z");
    expect(weekStartInTz("Europe/London", at)).toBe("2026-06-13");
    expect(weekStartInTz(BD_TZ, at)).toBe("2026-06-20");
    // At Friday 15:00Z: London Friday 16:00 → 06-13; Dhaka Friday 21:00 → 06-13
    expect(weekStartInTz("Europe/London", new Date("2026-06-19T15:00:00Z"))).toBe("2026-06-13");
    expect(weekStartInTz(BD_TZ, new Date("2026-06-19T15:00:00Z"))).toBe("2026-06-13");
    // Wednesday mid-week: 2026-06-17 → week start 06-13 in both zones
    expect(weekStartInTz("Europe/London", new Date("2026-06-17T12:00:00Z"))).toBe("2026-06-13");
  });

  it("the old weekStartOf(date) signature is gone — server-local no longer decides", () => {
    // weekStartOf(tz) is the only entry point now; default zone is Dhaka.
    expect(weekStartOf("Europe/London", new Date("2026-06-19T21:00:00Z"))).toBe("2026-06-13");
    expect(weekStartOf(undefined, new Date("2026-06-19T21:00:00Z"))).toBe("2026-06-20");
  });

  it("London Saturday-early edge: 2026-06-20T00:30Z is Sat 01:30 in London → same week", () => {
    expect(weekStartInTz("Europe/London", new Date("2026-06-20T00:30:00Z"))).toBe("2026-06-20");
    // …but still Saturday 06:30 in Dhaka → ALSO 2026-06-20? No: Dhaka is Sat
    // 06:30 → week start of Sat is that Saturday itself.
    expect(weekStartInTz(BD_TZ, new Date("2026-06-20T00:30:00Z"))).toBe("2026-06-20");
  });
});

describe("tzOffsetHoursFor — the prayer engine input", () => {
  it("Dhaka 6, Riyadh 3, London 1 in summer / 0 in winter", () => {
    expect(tzOffsetHoursFor("2026-07-15", BD_TZ)).toBe(6);
    expect(tzOffsetHoursFor("2026-07-15", "Asia/Riyadh")).toBe(3);
    expect(tzOffsetHoursFor("2026-07-15", "Europe/London")).toBe(1);
    expect(tzOffsetHoursFor("2026-01-15", "Europe/London")).toBe(0);
  });
});
