// ─────────────────────────────────────────────────────────────────────────────
// prayer-adjust.spec.ts (2026-10-09) — "নিজের মসজিদের সাথে মেলান": whole
// minutes per waqt on top of the calculation, and IFB as the default.
//   • the engine adds the minutes to the five start times only; sunrise,
//     ishraq and the zawal window stay with the sun
//   • parsePrayerAdjust: known keys, whole minutes within ±30, zeros dropped
//   • PATCH /api/me stores a clean value and refuses a bad one; a new
//     account starts on the IFB method with no adjustment
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { computePrayerTimesForDate, forbiddenWindows, parsePrayerAdjust } from "src/shared/prayer-times";

const day = new Date("2026-08-28T06:00:00Z");
const dhaka = (adjust?: object) =>
  ({ lat: 23.8103, lng: 90.4125, tzOffsetHours: 6, method: "ifb", madhhab: "hanafi", adjust }) as never;

describe("the engine", () => {
  it("adds the minutes to the start times, nothing else", () => {
    const base = computePrayerTimesForDate(day, dhaka());
    const mine = computePrayerTimesForDate(day, dhaka({ fajr: 2, dhuhr: 10, maghrib: 5, isha: -1 }));
    expect(mine.fajr - base.fajr).toBe(2);
    expect(mine.dhuhr - base.dhuhr).toBe(10);
    expect(mine.asr).toBe(base.asr);
    expect(mine.maghrib - base.maghrib).toBe(5);
    expect(mine.isha - base.isha).toBe(-1);
    for (const k of ["sunrise", "ishraq", "sunset", "tahajjud", "noon"] as const) expect(mine[k]).toBe(base[k]);
    // a mosque that calls Dhuhr later does not move zawal
    expect(forbiddenWindows(mine)).toEqual(forbiddenWindows(base));
  });

  it("noon is the calculated Dhuhr", () => {
    const t = computePrayerTimesForDate(day, dhaka());
    expect(t.noon).toBe(t.dhuhr);
  });
});

describe("parsePrayerAdjust", () => {
  it("keeps a clean value, drops zeros, reads stored JSON", () => {
    expect(parsePrayerAdjust({ fajr: 2, asr: 0, isha: -30 })).toEqual({ fajr: 2, isha: -30 });
    expect(parsePrayerAdjust('{"maghrib":5}')).toEqual({ maghrib: 5 });
    expect(parsePrayerAdjust(null)).toEqual({});
    expect(parsePrayerAdjust({})).toEqual({});
  });
  it("refuses unknown keys, fractions, out of range and non-objects", () => {
    for (const bad of [{ sunrise: 2 }, { fajr: 1.5 }, { fajr: 31 }, { isha: -31 }, { fajr: "2" }, [1], 5, "nope"]) {
      expect(parsePrayerAdjust(bad)).toBeNull();
    }
  });
});

describe("PATCH /api/me — prayerAdjust", () => {
  const PHONE = "01799990031";
  let app: INestApplication;
  let rls: RlsService;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
    await app.init();
    rls = app.get(RlsService);
  });

  afterAll(async () => {
    await rls.system((tx) => tx.user.deleteMany({ where: { phone: PHONE } }));
    await rls.system((tx) => tx.otpCode.deleteMany({ where: { phone: PHONE } }));
    await app.close();
  });

  it("a new account: IFB, no adjustment; a clean value is stored, a bad one refused", async () => {
    const otp = await http().post("/api/auth/otp/request").send({ phone: PHONE }).expect(200);
    const signIn = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: PHONE, code: otp.body.devCode, name: "মসজিদের সময়", gender: "M" })
      .expect(200);
    expect(signIn.body.user.calcMethod).toBe("ifb");
    expect(signIn.body.user.prayerAdjust).toEqual({});
    const auth = { Authorization: `Bearer ${signIn.body.accessToken}` };

    const ok = await http().patch("/api/me").set(auth).send({ prayerAdjust: { fajr: 2, maghrib: 5, asr: 0 } }).expect(200);
    expect(ok.body.user.prayerAdjust).toEqual({ fajr: 2, maghrib: 5 });
    const me = await http().get("/api/me").set(auth).expect(200);
    expect(me.body.user.prayerAdjust).toEqual({ fajr: 2, maghrib: 5 });

    await http().patch("/api/me").set(auth).send({ prayerAdjust: { fajr: 45 } }).expect(400);
    await http().patch("/api/me").set(auth).send({ prayerAdjust: { tahajjud: 5 } }).expect(400);
    await http().patch("/api/me").set(auth).send({ prayerAdjust: "5" }).expect(400);

    const cleared = await http().patch("/api/me").set(auth).send({ prayerAdjust: {} }).expect(200);
    expect(cleared.body.user.prayerAdjust).toEqual({});
  });
});
