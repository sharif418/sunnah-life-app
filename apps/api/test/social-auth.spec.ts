// ─────────────────────────────────────────────────────────────────────────────
// Social sign-in e2e (Task B5) — Google + Apple id_token verification against
// the REAL app + DB, with the provider JWKS endpoints mocked on global fetch.
//
// The test generates REAL keypairs (RSA-2048 for Google/RS256, EC P-256 for
// Apple/ES256) with WebCrypto, publishes their public JWKs through the
// mocked https://www.googleapis.com/oauth2/v3/certs and
// https://appleid.apple.com/auth/keys, and signs genuine provider-shaped
// id_tokens — so the full verify path (parse → kid lookup → WebCrypto
// signature → iss/aud/exp claims) is exercised for real, not stubbed.
//
// Reject paths: wrong audience, unverified email, expired token, bad
// signature, alg confusion, disabled provider. Happy paths: creation with
// gender, creation without gender ("unspecified"), email linking
// (case-insensitive), linking onto a phone-OTP account, Apple's
// email-only-on-first-auth (sub fallback), guest amal merge, referral link,
// and the one-time gender completion via PATCH /api/me.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { RlsService } from "src/common/rls.service";
import { resetJwksCache } from "src/auth/social/jwks";
import { GOOGLE_JWKS_URL, APPLE_JWKS_URL } from "src/auth/social/jwks";

const GOOGLE_AUD = "google-web-client-id-test";
const GOOGLE_IOS_AUD = "google-ios-client-id-test";
const APPLE_AUD = "com.sunnahlife.test.services";
const APPLE_BUNDLE_AUD = "bd.asunnah.sunnahLife";

const DAEE = "01000000004"; // রাফিউল ইসলাম — DS-000004 (referral code for tests)
const THROWAWAY_PHONE = "01711112222"; // fresh phone user for the link test
const SQUATTER_PHONE = "01711113333"; // types someone else's email (takeover test)

let app: INestApplication;
let http: () => ReturnType<typeof request>;
let rls: RlsService;
const createdUserIds = new Set<string>();
const originalFetch = globalThis.fetch;

// ── Key material (real WebCrypto keypairs) ────────────────────────────────────

interface KeyMaterial {
  kid: string;
  jwk: JsonWebKey;
  private: CryptoKey;
}
let googleKey: KeyMaterial;
let appleKey: KeyMaterial;

async function rsaMaterial(kid: string): Promise<KeyMaterial> {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  return { kid, jwk: { ...jwk, kid, alg: "RS256", use: "sig" } as JsonWebKey, private: pair.privateKey };
}

async function ecMaterial(kid: string): Promise<KeyMaterial> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  return { kid, jwk: { ...jwk, kid, alg: "ES256", use: "sig" } as JsonWebKey, private: pair.privateKey };
}

function b64url(bytes: Uint8Array | string): string {
  const buf = typeof bytes === "string" ? Buffer.from(bytes, "utf8") : Buffer.from(bytes);
  return buf.toString("base64url");
}

/** Sign a genuine provider-shaped id_token with the test key. */
async function signToken(
  key: KeyMaterial,
  alg: "RS256" | "ES256",
  payload: Record<string, unknown>,
  headerAlgOverride?: string
): Promise<string> {
  const unsigned = `${b64url(JSON.stringify({ alg: headerAlgOverride ?? alg, kid: key.kid, typ: "JWT" }))}.${b64url(JSON.stringify(payload))}`;
  const encoder = new TextEncoder();
  const data = new ArrayBuffer(unsigned.length);
  new Uint8Array(data).set(encoder.encode(unsigned));
  const sig = await crypto.subtle.sign(
    alg === "RS256" ? "RSASSA-PKCS1-v1_5" : { name: "ECDSA", hash: "SHA-256" },
    key.private,
    data
  );
  return `${unsigned}.${b64url(new Uint8Array(sig))}`;
}

const nowSec = () => Math.floor(Date.now() / 1000);

function googleClaims(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    iss: "https://accounts.google.com",
    aud: GOOGLE_AUD,
    sub: "google-sub-100",
    email: "Rafiq@Example.COM", // mixed case on purpose: linking is case-insensitive
    email_verified: true,
    name: "রাফিকুল ইসলাম",
    exp: nowSec() + 600,
    iat: nowSec(),
    ...over,
  };
}

function appleClaims(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    iss: "https://appleid.apple.com",
    aud: APPLE_AUD,
    sub: "apple-sub-200",
    exp: nowSec() + 600,
    iat: nowSec(),
    ...over,
  };
}

/** POST /api/auth/social helper. */
function social(provider: string, idToken: string, extra: Record<string, unknown> = {}) {
  return http().post("/api/auth/social").send({ provider, idToken, ...extra });
}

// ── Boot + env + fetch mock ──────────────────────────────────────────────────

beforeAll(async () => {
  process.env.GOOGLE_CLIENT_ID = GOOGLE_AUD;
  process.env.GOOGLE_IOS_CLIENT_ID = GOOGLE_IOS_AUD;
  process.env.APPLE_SERVICES_ID = APPLE_AUD;
  process.env.APPLE_IOS_BUNDLE_ID = APPLE_BUNDLE_AUD;
  resetJwksCache();

  googleKey = await rsaMaterial("google-test-key");
  appleKey = await ecMaterial("apple-test-key");

  const realFetch = originalFetch.bind(globalThis);
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    if (url === GOOGLE_JWKS_URL) {
      return new Response(JSON.stringify({ keys: [googleKey.jwk] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (url === APPLE_JWKS_URL) {
      return new Response(JSON.stringify({ keys: [appleKey.jwk] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    // Anything else: keep the real network (nothing else is expected to fetch).
    return realFetch(input, init);
  }) as typeof fetch;

  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer());
  rls = app.get(RlsService);
});

afterAll(async () => {
  // Demo DB hygiene: remove every test-created user + their closure rows.
  if (rls && createdUserIds.size) {
    const ids = [...createdUserIds];
    await rls.system(async (tx) => {
      await tx.referralClosure.deleteMany({ where: { descendantId: { in: ids } } });
      await tx.user.deleteMany({ where: { id: { in: ids } } });
    });
  }
  globalThis.fetch = originalFetch;
  await app.close();
});

/** Full OTP sign-in → access token (for the seeded demo users). */
async function otpToken(phone: string): Promise<string> {
  const otpRes = await http().post("/api/auth/otp/request").send({ phone }).expect(200);
  const verifyRes = await http()
    .post("/api/auth/otp/verify")
    .send({ phone, code: otpRes.body.devCode })
    .expect(200);
  return verifyRes.body.accessToken as string;
}

/** Track + return the user id of a social response for later cleanup. */
function track(body: { user: { id: string } }): string {
  createdUserIds.add(body.user.id);
  return body.user.id;
}

// ── GET /api/auth/providers ──────────────────────────────────────────────────

describe("GET /api/auth/providers", () => {
  it("reports the enabled providers from env", async () => {
    const res = await http().get("/api/auth/providers").expect(200);
    expect(res.body).toEqual({ google: true, apple: true, googleClientId: process.env.GOOGLE_CLIENT_ID });
  });

  it("flips to disabled when the env is cleared at request time", async () => {
    const saved = process.env.GOOGLE_CLIENT_ID;
    const savedIos = process.env.GOOGLE_IOS_CLIENT_ID;
    process.env.GOOGLE_CLIENT_ID = "";
    process.env.GOOGLE_IOS_CLIENT_ID = "";
    try {
      const res = await http().get("/api/auth/providers").expect(200);
      expect(res.body).toEqual({ google: false, apple: true, googleClientId: null });
    } finally {
      process.env.GOOGLE_CLIENT_ID = saved;
      process.env.GOOGLE_IOS_CLIENT_ID = savedIos;
    }
  });
});

// ── POST /api/auth/social — happy paths ──────────────────────────────────────

describe("POST /api/auth/social — happy paths", () => {
  it("google: creates the account when gender rides along (onboarding gender)", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-gender-case" }));
    const res = await social("google", token, { gender: "F", name: "আয়েশা সিদ্দিকা" }).expect(200);
    track(res.body);
    expect(res.body.user.email).toBe("rafiq@example.com"); // normalized lowercase
    expect(res.body.user.phone).toBeNull();
    expect(res.body.user.gender).toBe("F");
    expect(res.body.user.role).toBe("user");
    expect(res.body.user.memberCode).toBeNull(); // memberCode is assigned at daee promotion, like OTP users
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
  });

  it("google: creates WITHOUT gender → \"unspecified\" (mobile runs the completion step)", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-nogender-case", email: "nogender@example.com" }));
    const res = await social("google", token).expect(200);
    track(res.body);
    expect(res.body.user.gender).toBe("unspecified");
    expect(res.body.user.name).toBe("রাফিকুল ইসলাম"); // token name fallback
  });

  it("google: links by email case-insensitively → SAME account, gender payload ignored", async () => {
    const first = await signToken(googleKey, "RS256", googleClaims({ sub: "google-email-link", email: "Same@Person.com" }));
    const r1 = await social("google", first, { gender: "M" }).expect(200);
    track(r1.body);
    // Second sign-in: different casing in the token email + a contradictory
    // gender (must be IGNORED — gender is locked after creation).
    const second = await signToken(googleKey, "RS256", googleClaims({ sub: "other-sub-value", email: "same@person.COM" }));
    const r2 = await social("google", second, { gender: "F" }).expect(200);
    expect(r2.body.user.id).toBe(r1.body.user.id);
    expect(r2.body.user.gender).toBe("M");
  });

  it("google: links onto an EXISTING phone-OTP account by email", async () => {
    // Fresh throwaway phone user (kept for cleanup).
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: THROWAWAY_PHONE }).expect(200);
    const verifyRes = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: THROWAWAY_PHONE, code: otpRes.body.devCode, gender: "M", name: "তানভীর" })
      .expect(200);
    const phoneUserId = verifyRes.body.user.id as string;
    createdUserIds.add(phoneUserId);

    // Give that phone account a VERIFIED email (a provider vouched for it
    // earlier — only such an email links; see the takeover test below).
    await rls.system((tx) =>
      tx.user.update({
        where: { id: phoneUserId },
        data: { email: "tanvir@example.com", emailVerifiedAt: new Date() },
      })
    );

    const token = await signToken(
      googleKey,
      "RS256",
      googleClaims({ sub: "google-phone-link", email: "TANVIR@example.com" })
    );
    const res = await social("google", token, { gender: "F" }).expect(200);
    expect(res.body.user.id).toBe(phoneUserId); // same account regardless of login method
    expect(res.body.user.gender).toBe("M"); // gender payload IGNORED on an existing account
    expect(res.body.user.phone).toBe(THROWAWAY_PHONE);
    expect(res.body.user.email).toBe("tanvir@example.com");

    // The social identity was stamped for direct linking next time.
    const row = await rls.system((tx) => tx.user.findUnique({ where: { id: phoneUserId } }));
    expect(row?.socialProvider).toBe("google");
    expect(row?.socialSub).toBe("google-phone-link");
  });

  it("an UNVERIFIED email typed into a profile never captures the owner's Google sign-in", async () => {
    // A brother types a sister's address into his own profile …
    const otpRes = await http().post("/api/auth/otp/request").send({ phone: SQUATTER_PHONE }).expect(200);
    const verifyRes = await http()
      .post("/api/auth/otp/verify")
      .send({ phone: SQUATTER_PHONE, code: otpRes.body.devCode, gender: "M", name: "স্কোয়াটার" })
      .expect(200);
    const squatterId = verifyRes.body.user.id as string;
    createdUserIds.add(squatterId);
    await http()
      .patch("/api/me")
      .set("Authorization", `Bearer ${verifyRes.body.accessToken}`)
      .send({ email: "Sister.Owner@example.com" })
      .expect(200);
    const typed = await rls.system((tx) => tx.user.findUnique({ where: { id: squatterId } }));
    expect(typed?.email).toBe("sister.owner@example.com");
    expect(typed?.emailVerifiedAt).toBeNull();

    // … then the real owner signs in with Google.
    const token = await signToken(
      googleKey,
      "RS256",
      googleClaims({ sub: "google-sister-owner", email: "sister.owner@example.com", name: "বোন" })
    );
    const res = await social("google", token, { gender: "F" }).expect(200);
    track(res.body);
    expect(res.body.user.id).not.toBe(squatterId); // her own account
    expect(res.body.user.gender).toBe("F");
    expect(res.body.user.email).toBe("sister.owner@example.com");

    // the unproven claim is released; his account gained nothing
    const after = await rls.system((tx) => tx.user.findUnique({ where: { id: squatterId } }));
    expect(after?.email).toBeNull();
    expect(after?.socialSub).toBeNull();
    const owner = await rls.system((tx) => tx.user.findUnique({ where: { id: res.body.user.id } }));
    expect(owner?.emailVerifiedAt).not.toBeNull();
  });

  it("changing the email in the profile drops its verification; another account's email → 409", async () => {
    const token = await signToken(
      googleKey,
      "RS256",
      googleClaims({ sub: "google-email-change", email: "changer@example.com" })
    );
    const res = await social("google", token, { gender: "M" }).expect(200);
    const id = track(res.body);
    const auth = `Bearer ${res.body.accessToken}`;
    await http().patch("/api/me").set("Authorization", auth).send({ email: "sister.owner@example.com" }).expect(409);
    await http().patch("/api/me").set("Authorization", auth).send({ email: "Changer@Example.com" }).expect(200);
    let row = await rls.system((tx) => tx.user.findUnique({ where: { id } }));
    expect(row?.emailVerifiedAt).not.toBeNull(); // same address → still verified
    await http().patch("/api/me").set("Authorization", auth).send({ email: "new@example.com" }).expect(200);
    row = await rls.system((tx) => tx.user.findUnique({ where: { id } }));
    expect(row?.email).toBe("new@example.com");
    expect(row?.emailVerifiedAt).toBeNull();
  });

  it("apple: creates with email; second auth WITHOUT email links by sub (Apple first-auth-only email)", async () => {
    const first = await signToken(appleKey, "ES256", appleClaims({ email: "first@icloud.com" }));
    const r1 = await social("apple", first, { name: "সাইফুল" }).expect(200);
    track(r1.body);
    expect(r1.body.user.email).toBe("first@icloud.com");
    expect(r1.body.user.gender).toBe("unspecified");

    // Apple only includes `email` on the FIRST auth — the returning token has
    // just the stable `sub`. The account must still be found by sub.
    const second = await signToken(appleKey, "ES256", appleClaims());
    const r2 = await social("apple", second).expect(200);
    expect(r2.body.user.id).toBe(r1.body.user.id);
  });

  it("apple: accepts the iOS bundle id audience (native ASAuthorization flow)", async () => {
    const token = await signToken(appleKey, "ES256", appleClaims({ aud: APPLE_BUNDLE_AUD, sub: "apple-native-aud", email: "native@icloud.com" }));
    const res = await social("apple", token).expect(200);
    track(res.body);
    expect(res.body.user.email).toBe("native@icloud.com");
  });

  it("migrates guest amal entries on creation (same rule as otp/verify)", async () => {
    const today = new Date().toISOString().slice(0, 10);
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-guest-merge" }));
    const res = await social("google", token, {
      guestEntries: [
        { amalKey: "salat_fajr", date: today, value: "jamaat", clientUpdatedAt: new Date().toISOString() },
        { amalKey: "tilawat", date: today, value: 2, clientUpdatedAt: new Date().toISOString() },
      ],
    }).expect(200);
    const accessToken = res.body.accessToken as string;

    const entries = await http()
      .get(`/api/amal/entries?from=${today}&to=${today}`)
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);
    const keys = (entries.body.entries as { amalKey: string }[]).map((e) => e.amalKey);
    // THE STRIP-BUG PROOF: this whole request ran through the global
    // whitelist ValidationPipe (APP_PIPE, Phase C/W2g) — `value` and
    // `clientUpdatedAt` survive it only because GuestEntryDto now carries
    // class-validator decorators. Pre-W2g they were silently stripped in
    // production and the merge imported nothing.
    expect(keys).toEqual(expect.arrayContaining(["salat_fajr", "tilawat"]));
  });

  it("clamps a far-future guest clientUpdatedAt to now+5min (no lying clock wins LWW)", async () => {
    const today = new Date().toISOString().slice(0, 10);
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-guest-clamp" }));
    const res = await social("google", token, {
      guestEntries: [
        {
          amalKey: "salat_fajr",
          date: today,
          value: "jamaat",
          // a year in the future — must NOT be stored as-is
          clientUpdatedAt: new Date(Date.now() + 365 * 86_400_000).toISOString(),
        },
      ],
    }).expect(200);
    track(res.body);
    const accessToken = res.body.accessToken as string;

    const entries = await http()
      .get(`/api/amal/entries?from=${today}&to=${today}`)
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);
    const row = (entries.body.entries as { amalKey: string; clientUpdatedAt: string }[]).find(
      (e) => e.amalKey === "salat_fajr"
    );
    expect(row).toBeTruthy();
    // stored clientUpdatedAt ≤ now + 5 min + slack for request latency
    expect(new Date(row!.clientUpdatedAt).getTime()).toBeLessThanOrEqual(Date.now() + 5 * 60_000 + 10_000);
  });

  it("does NOT import guest entries with UNKNOWN amal keys (client-controlled payload)", async () => {
    const today = new Date().toISOString().slice(0, 10);
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-guest-unknown-key" }));
    const res = await social("google", token, {
      guestEntries: [
        { amalKey: "definitely_not_in_catalog", date: today, value: "jamaat", clientUpdatedAt: new Date().toISOString() },
        { amalKey: "salat_fajr", date: today, value: "alone", clientUpdatedAt: new Date().toISOString() },
      ],
    }).expect(200);
    track(res.body);
    const accessToken = res.body.accessToken as string;

    const entries = await http()
      .get(`/api/amal/entries?from=${today}&to=${today}`)
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);
    const keys = (entries.body.entries as { amalKey: string }[]).map((e) => e.amalKey);
    expect(keys).toContain("salat_fajr"); // the known key made it
    expect(keys).not.toContain("definitely_not_in_catalog"); // the unknown one did not
  });

  it("does NOT overwrite a newer SERVER row during the guest merge (LWW at merge)", async () => {
    const today = new Date().toISOString().slice(0, 10);
    // 1) create the account first — no guest entries yet
    const token0 = await signToken(googleKey, "RS256", googleClaims({ sub: "google-guest-lww" }));
    const first = await social("google", token0).expect(200);
    track(first.body);
    const accessToken = first.body.accessToken as string;

    // 2) server row with a NEWER clientUpdatedAt via the real sync route
    // (POST defaults to 201 Created — the body carries {accepted, rejected})
    await http()
      .post("/api/amal/entries")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({
        entries: [
          { amalKey: "salat_fajr", date: today, value: "jamaat", clientUpdatedAt: new Date().toISOString(), source: "manual" },
        ],
      })
      .expect(201);

    // 3) re-sign-in with an OLDER guest entry — the server row must win
    const token1 = await signToken(googleKey, "RS256", googleClaims({ sub: "google-guest-lww" }));
    const res = await social("google", token1, {
      guestEntries: [
        {
          amalKey: "salat_fajr",
          date: today,
          value: "qaza", // would be a regression if this overwrote "jamaat"
          clientUpdatedAt: new Date(Date.now() - 86_400_000).toISOString(), // yesterday
        },
      ],
    }).expect(200);
    expect(res.body.user.id).toBe(first.body.user.id);

    const entries = await http()
      .get(`/api/amal/entries?from=${today}&to=${today}`)
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);
    const row = (entries.body.entries as { amalKey: string; value: string }[]).find(
      (e) => e.amalKey === "salat_fajr"
    );
    expect(row?.value).toBe("jamaat"); // guest "qaza" did NOT overwrite the newer server row
  });

  it("applies referredByCode at creation (referral closure + referredById)", async () => {
    const daee = await rls.system((tx) => tx.user.findUnique({ where: { phone: DAEE } }));
    expect(daee?.memberCode).toBe("DS-000004");

    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-referred", email: "referred@example.com" }));
    const res = await social("google", token, { referredByCode: "ds-000004" }).expect(200);
    const id = track(res.body);
    expect(res.body.user.referredById).toBe(daee!.id);

    const closure = await rls.system((tx) =>
      tx.referralClosure.findUnique({
        where: { ancestorId_descendantId: { ancestorId: daee!.id, descendantId: id } },
      })
    );
    expect(closure?.depth).toBe(1);
  });
});

// ── POST /api/auth/social — reject paths ─────────────────────────────────────

describe("POST /api/auth/social — reject paths", () => {
  it("wrong audience → 400", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ aud: "some-other-app" }));
    const res = await social("google", token).expect(400);
    expect(res.body.error).toContain("যাচাই");
  });

  it("google: unverified email → 400 with the Bengali message", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ email_verified: false, sub: "unv" }));
    const res = await social("google", token).expect(400);
    expect(res.body.error).toBe("Google ইমেইল যাচাই হয়নি — আগে Google-এ ইমেইল নিশ্চিত করুন");
  });

  it("expired token (exp in the past) → 400", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ exp: nowSec() - 3600, sub: "exp" }));
    const res = await social("google", token).expect(400);
    expect(res.body.error).toContain("সময় শেষ");
  });

  it("signature by an UNKNOWN key (kid not in JWKS) → 400", async () => {
    const rogue = await rsaMaterial("rogue-key");
    const token = await signToken(rogue, "RS256", googleClaims({ sub: "rogue" }));
    await social("google", token).expect(400);
  });

  it("alg confusion (header says HS256) → 400", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "alg-confusion" }), "HS256");
    await social("google", token).expect(400);
  });

  it("apple: unknown sub + no email (deleted-account edge) → 400", async () => {
    const token = await signToken(appleKey, "ES256", appleClaims({ sub: "unknown-sub-xyz" }));
    const res = await social("apple", token).expect(400);
    expect(res.body.error).toBe("অ্যাপল অ্যাকাউন্টের ইমেইল পাওয়া যায়নি — অন্য উপায়ে সাইন ইন করুন");
  });

  it("disabled provider (env empty) → 400 with the Bengali message", async () => {
    const savedApple = process.env.APPLE_SERVICES_ID;
    const savedBundle = process.env.APPLE_IOS_BUNDLE_ID;
    process.env.APPLE_SERVICES_ID = "";
    process.env.APPLE_IOS_BUNDLE_ID = "";
    try {
      const token = await signToken(appleKey, "ES256", appleClaims({ email: "disabled@icloud.com" }));
      const res = await social("apple", token).expect(400);
      expect(res.body.error).toBe("এই সাইন-ইন পদ্ধতি এখন চালু নেই");
    } finally {
      process.env.APPLE_SERVICES_ID = savedApple;
      process.env.APPLE_IOS_BUNDLE_ID = savedBundle;
    }
  });

  it("unknown provider value → 400", async () => {
    await social("facebook", "whatever-token").expect(400);
  });

  it("not-a-JWT idToken → 400", async () => {
    await social("google", "garbage").expect(400);
  });
});

// ── Gender onboarding completion (PATCH /api/me) ─────────────────────────────

describe("gender completion — PATCH /api/me (one-time set, then locked)", () => {
  it("sets gender once for an \"unspecified\" social account, then rejects changes", async () => {
    const token = await signToken(googleKey, "RS256", googleClaims({ sub: "google-gender-complete", email: "gendercomplete@example.com" }));
    const res = await social("google", token, { name: "নাজমুল" }).expect(200);
    track(res.body);
    const accessToken = res.body.accessToken as string;
    expect(res.body.user.gender).toBe("unspecified");

    // One-time completion: name + gender together (the onboarding step).
    const patched = await http()
      .patch("/api/me")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ name: "নাজমুল হাসান", gender: "M" })
      .expect(200);
    expect(patched.body.user.gender).toBe("M");
    expect(patched.body.user.name).toBe("নাজমুল হাসান");

    // LOCKED: any later change is rejected with the Bengali error.
    const change = await http()
      .patch("/api/me")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ gender: "F" })
      .expect(400);
    expect(change.body.error).toBe("লিঙ্গ পরিবর্তন করা যায় না");
  });

  it("rejects a gender change for a phone-OTP account (already set at onboarding)", async () => {
    const token = await otpToken(DAEE); // seeded daee — gender M since onboarding
    const res = await http()
      .patch("/api/me")
      .set("Authorization", `Bearer ${token}`)
      .send({ gender: "F" })
      .expect(400);
    expect(res.body.error).toBe("লিঙ্গ পরিবর্তন করা যায় না");
  });

  it("re-sending the SAME gender is a harmless no-op (still 200)", async () => {
    const token = await otpToken(DAEE);
    const res = await http()
      .patch("/api/me")
      .set("Authorization", `Bearer ${token}`)
      .send({ gender: "M", city: "ঢাকা" })
      .expect(200);
    expect(res.body.user.gender).toBe("M");
  });
});
