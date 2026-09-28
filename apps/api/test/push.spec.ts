// Unit tests for the push module (Task B2) — transport selection (no-op vs
// FCM), the token-cap helper, FCM message/claims builders, the RS256 JWT
// signing roundtrip, and PushService fan-out semantics (gender filter +
// gender-isolated usrah fan-out) against a scripted RlsService.
import { generateKeyPairSync, createVerify } from "node:crypto";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ApiError } from "src/common/api-error";
import type { RlsService } from "src/common/rls.service";
import type { Gender, User } from "src/shared/domain";
import { DeviceTokensService, selectTokensToEvict, MAX_TOKENS_PER_USER } from "src/push/device-tokens.service";
import {
  FcmTransport,
  buildFcmMessage,
  buildJwtClaims,
  signRsaJwt,
} from "src/push/fcm.transport";
import { NoopPushTransport } from "src/push/push.transport";
import { createPushTransport, PushService } from "src/push/push.service";
import { DEEP_LINKS, deepLinkData } from "src/push/deep-links";

const user = (overrides: Partial<User>): User =>
  ({
    id: "u1",
    phone: "01000000001",
    email: null,
    name: "টেস্ট",
    photoUrl: null,
    gender: "M",
    role: "user",
    category: "general",
    memberCode: null,
    referredById: null,
    usrahId: null,
    level: "none",
    levelStartedAt: null,
    district: null,
    workplace: null,
    department: null,
    language: "bn",
    madhhab: "hanafi",
    calcMethod: "karachi",
    lat: null,
    lng: null,
    city: null,
    createdAt: new Date().toISOString(),
    lastActiveAt: new Date().toISOString(),
    ...overrides,
  }) as unknown as User;

describe("push: createPushTransport (adapter selection)", () => {
  const saved = process.env.FCM_SERVICE_ACCOUNT_JSON;
  afterEach(() => {
    if (saved === undefined) delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    else process.env.FCM_SERVICE_ACCOUNT_JSON = saved;
  });

  it("absent / empty env → no-op transport", () => {
    expect(createPushTransport(undefined).kind).toBe("noop");
    expect(createPushTransport("").kind).toBe("noop");
    expect(createPushTransport("   ").kind).toBe("noop");
  });

  it("invalid JSON or missing fields → no-op fallback (never throw at boot)", () => {
    expect(createPushTransport("{not json").kind).toBe("noop");
    expect(
      createPushTransport(JSON.stringify({ project_id: "p", client_email: "e@x.iam" }))
        .kind
    ).toBe("noop"); // no private_key
  });

  it("JSON object string → FCM transport with the project id", () => {
    const account = {
      project_id: "sunnah-life-dev",
      client_email: "push@sunnah-life-dev.iam.gserviceaccount.com",
      private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQ\n-----END PRIVATE KEY-----\n",
    };
    const t = createPushTransport(JSON.stringify(account));
    expect(t.kind).toBe("fcm");
  });

  it("file path to the JSON → FCM transport", () => {
    const dir = mkdtempSync(join(tmpdir(), "sl-push-"));
    const file = join(dir, "fcm.json");
    writeFileSync(
      file,
      JSON.stringify({
        project_id: "sunnah-life-file",
        client_email: "a@b.iam.gserviceaccount.com",
        private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQ\n-----END PRIVATE KEY-----\n",
      })
    );
    try {
      expect(createPushTransport(file).kind).toBe("fcm");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("push: NoopPushTransport", () => {
  it("reports every token as sent (so queues don't retry forever)", async () => {
    const out = await new NoopPushTransport().sendAll([
      { token: "t1", title: "নামাজের সময়", body: "ফজর" },
      { token: "t2", title: "নামাজের সময়", body: "ফজর" },
    ]);
    expect(out).toHaveLength(2);
    expect(out.every((o) => o.ok)).toBe(true);
  });
});

describe("push: device token cap (selectTokensToEvict)", () => {
  const row = (id: string, seenMinutesAgo: number) => ({
    id,
    lastSeenAt: new Date(Date.now() - seenMinutesAgo * 60_000),
  });

  it("keeps the newest 5, evicts the rest (default cap)", () => {
    const rows = [1, 2, 3, 4, 5, 6, 7].map((i) => row(`t${i}`, i));
    expect(selectTokensToEvict(rows)).toEqual(["t6", "t7"]);
  });

  it("under the cap → nothing evicted", () => {
    const rows = [1, 2, 3].map((i) => row(`t${i}`, i));
    expect(selectTokensToEvict(rows)).toEqual([]);
  });

  it("equal lastSeenAt ties break deterministically by id", () => {
    const at = new Date("2026-09-28T00:00:00Z");
    const rows = ["b", "a", "c"].map((id) => ({ id, lastSeenAt: at }));
    expect(selectTokensToEvict(rows, 1)).toEqual(["b", "c"]);
  });

  it("MAX_TOKENS_PER_USER is 5", () => {
    expect(MAX_TOKENS_PER_USER).toBe(5);
  });
});

describe("push: FCM message + JWT builders", () => {
  it("buildFcmMessage embeds deepLink data, the Android channel and APNs sound", () => {
    const msg = buildFcmMessage({
      token: "tok-1",
      title: "নতুন ঘোষণা",
      body: "মজলিস আগামীকাল",
      data: deepLinkData(DEEP_LINKS.usrah),
    });
    expect(msg.message.token).toBe("tok-1");
    expect(msg.message.notification).toEqual({ title: "নতুন ঘোষণা", body: "মজলিস আগামীকাল" });
    expect(msg.message.data?.deepLink).toBe("sunnahlife://usrah");
    expect(msg.message.android?.notification?.channel_id).toBe("sunnah_life_push");
    expect(msg.message.android?.notification?.icon).toBe("ic_notification");
    expect(msg.message.apns?.payload?.aps?.sound).toBe("default");
  });

  it("buildJwtClaims produces the client-credentials grant shape", () => {
    const claims = buildJwtClaims("push@proj.iam.gserviceaccount.com", 1_000, 600);
    expect(claims.iss).toBe("push@proj.iam.gserviceaccount.com");
    expect(claims.aud).toBe("https://oauth2.googleapis.com/token");
    expect(claims.scope).toContain("firebase.messaging");
    expect(claims.iat).toBe(1_000);
    expect(claims.exp).toBe(1_600);
  });

  it("signRsaJwt roundtrips through node:crypto verification (RS256)", async () => {
    const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
    const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
    const claims = buildJwtClaims("a@b.iam.gserviceaccount.com", 5, 60);
    const jwt = await signRsaJwt({ alg: "RS256", typ: "JWT" }, claims, pem);
    const [header, payload, signature] = jwt.split(".");
    expect(header).toBe(Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url"));
    const verified = createVerify("RSA-SHA256")
      .update(Buffer.from(`${header}.${payload}`))
      .verify(publicKey, Buffer.from(signature, "base64url"));
    expect(verified).toBe(true);
    expect(JSON.parse(Buffer.from(payload, "base64url").toString("utf8"))).toEqual(claims);
  });
});

describe("push: PushService fan-out (scripted RlsService)", () => {
  const headM = user({ id: "head-m", role: "usrah_head", gender: "M", usrahId: "us1" });
  const usrahF = { id: "us1", name: "আয়েশা সিদ্দিকা", gender: "F", headUserId: "head-f" };

  function makeService(tx: Record<string, unknown>) {
    const rls = {
      run: async (_u: unknown, fn: (t: unknown) => Promise<unknown>) => fn(tx),
      system: async (fn: (t: unknown) => Promise<unknown>) => fn(tx),
    } as unknown as RlsService;
    const svc = new PushService(rls);
    // NOTE: onModuleInit() is deliberately NOT called — the default no-op
    // transport stays in place without touching process.env.
    return svc;
  }

  it("send() resolves tokens through the actor RLS context and reports no-op delivery", async () => {
    let seenWhere: unknown;
    const svc = makeService({
      deviceToken: {
        findMany: async ({ where }: { where: unknown }) => {
          seenWhere = where;
          return [
            { token: "tok-a", userId: "u1" },
            { token: "tok-b", userId: "u1" },
          ];
        },
      },
    });
    const out = await svc.send(["u1", "u1", ""], {
      title: "নতুন ঘোষণা",
      body: "x",
      deepLink: DEEP_LINKS.reviews,
    }, { actor: headM });
    expect(seenWhere).toEqual({ userId: { in: ["u1"] } });
    expect(out).toEqual({ users: 1, sent: 2, failed: 0, pruned: 0, transport: "noop" });
  });

  it("send() with an empty user set short-circuits without touching the DB", async () => {
    const svc = makeService({ deviceToken: { findMany: async () => { throw new Error("must not run"); } } });
    const out = await svc.send([], { title: "t", body: "b" });
    expect(out).toEqual({ users: 0, sent: 0, failed: 0, pruned: 0, transport: "noop" });
  });

  it("send() with a gender filter stamps it onto the token query (defense in depth)", async () => {
    let seenWhere: unknown;
    const svc = makeService({
      deviceToken: {
        findMany: async ({ where }: { where: unknown }) => {
          seenWhere = where;
          return [];
        },
      },
    });
    await svc.send(["u1", "u2"], { title: "t", body: "b" }, { gender: "F" as Gender });
    expect(seenWhere).toEqual({ userId: { in: ["u1", "u2"] }, user: { gender: "F" } });
  });

  it("sendToUsrah() gender-isolates: a male head can never fan out to a female usrah", async () => {
    const svc = makeService({ usrah: { findUnique: async () => usrahF } });
    const err = await svc
      .sendToUsrah("us1", { title: "t", body: "b" }, { actor: headM })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect((err as ApiError).getStatus()).toBe(403);
    expect(JSON.stringify((err as ApiError).getResponse())).toContain(
      "বিপরীত লিঙ্গের উসরায় নোটিফিকেশন পাঠানো যাবে না"
    );
  });

  it("sendToUsrah() resolves member tokens with the usrah gender filter", async () => {
    let tokenWhere: unknown;
    const svc = makeService({
      usrah: { findUnique: async () => usrahF },
      user: { findMany: async () => [{ id: "f1" }, { id: "f2" }] },
      deviceToken: {
        findMany: async ({ where }: { where: unknown }) => {
          tokenWhere = where;
          return [{ token: "tok-f1", userId: "f1" }];
        },
      },
    });
    const out = await svc.sendToUsrah("us1", { title: "সাপ্তাহিক রিভিউ", body: "b" });
    expect(tokenWhere).toEqual({
      userId: { in: ["f1", "f2"] },
      user: { gender: "F" },
    });
    expect(out.sent).toBe(1);
    expect(out.transport).toBe("noop");
  });

  it("sendToUsrah() allows a full_admin to cross gender (tokens still filtered)", async () => {
    const adminF = user({ id: "admin-f", role: "full_admin", gender: "F" });
    let tokenWhere: unknown;
    const svc = makeService({
      usrah: { findUnique: async () => usrahF },
      user: { findMany: async () => [{ id: "f1" }] },
      deviceToken: {
        findMany: async ({ where }: { where: unknown }) => {
          tokenWhere = where;
          return [{ token: "tok-f1", userId: "f1" }];
        },
      },
    });
    const out = await svc.sendToUsrah("us1", { title: "t", body: "b" }, { actor: adminF });
    expect(tokenWhere).toEqual({ userId: { in: ["f1"] }, user: { gender: "F" } });
    expect(out.sent).toBe(1);
  });

  it("sendToUsrah() respects respectGenderIsolation=false (admin tooling)", async () => {
    const adminM = user({ id: "admin-m", role: "full_admin", gender: "M" });
    let tokenWhere: unknown;
    const svc = makeService({
      usrah: { findUnique: async () => usrahF },
      user: { findMany: async () => [{ id: "f1" }] },
      deviceToken: {
        findMany: async ({ where }: { where: unknown }) => {
          tokenWhere = where;
          return [{ token: "tok-f1", userId: "f1" }];
        },
      },
    });
    await svc.sendToUsrah(
      "us1",
      { title: "t", body: "b" },
      { actor: adminM, respectGenderIsolation: false }
    );
    expect(tokenWhere).toEqual({ userId: { in: ["f1"] } });
  });

  it("sendToUsrah() on an invisible usrah → Bengali 403", async () => {
    const svc = makeService({ usrah: { findUnique: async () => null } });
    const err = await svc
      .sendToUsrah("nope", { title: "t", body: "b" })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect((err as ApiError).getStatus()).toBe(403);
  });
});

describe("push: FCM OAuth token exchange (mocked endpoint)", () => {
  it("uses the RFC 7523 jwt-bearer grant and caches until expiry", async () => {
    const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
    const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
    const account = {
      project_id: "p1",
      client_email: "push@p1.iam.gserviceaccount.com",
      private_key: pem,
    };
    const bodies: URLSearchParams[] = [];
    const fetchImpl = (async (url: RequestInfo, init?: RequestInit) => {
      if (String(url).includes("oauth2.googleapis.com/token")) {
        bodies.push(new URLSearchParams(String(init?.body)));
        return new Response(
          JSON.stringify({ access_token: `at-${bodies.length}`, expires_in: 3600 }),
          { status: 200 }
        );
      }
      throw new Error(`unexpected fetch: ${String(url)}`);
    }) as unknown as typeof fetch;
    const transport = new FcmTransport(account, fetchImpl);

    const t1 = await transport.getAccessToken();
    expect(bodies).toHaveLength(1);
    expect(bodies[0].get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
    const assertion = bodies[0].get("assertion") ?? "";
    expect(assertion.split(".")).toHaveLength(3);
    const claims = JSON.parse(Buffer.from(assertion.split(".")[1], "base64url").toString("utf8"));
    expect(claims.iss).toBe(account.client_email);
    expect(claims.scope).toBe("https://www.googleapis.com/auth/firebase.messaging");
    expect(claims.aud).toBe("https://oauth2.googleapis.com/token");

    // cached until expiry: a second call must NOT hit the token endpoint
    const t2 = await transport.getAccessToken();
    expect(t2).toBe(t1);
    expect(bodies).toHaveLength(1);

    // forced refresh (the 401 race path) exchanges again
    const t3 = await transport.getAccessToken(true);
    expect(t3).toBe("at-2");
    expect(bodies).toHaveLength(2);
  });
});

describe("push: device-token registration takes the token over", () => {
  it("register() removes the token from every OTHER user (system context) before upserting", async () => {
    const deletes: unknown[] = [];
    const upserts: unknown[] = [];
    const tx = {
      deviceToken: {
        deleteMany: async ({ where }: { where: unknown }) => {
          deletes.push(where);
          return { count: 1 };
        },
        upsert: async (args: unknown) => {
          upserts.push(args);
          return {};
        },
        findMany: async () => [],
      },
    };
    const rls = {
      run: async (_u: unknown, fn: (t: unknown) => Promise<unknown>) => fn(tx),
      system: async (fn: (t: unknown) => Promise<unknown>) => fn(tx),
    } as unknown as RlsService;
    const svc = new DeviceTokensService(rls);
    const u = user({ id: "u9" });
    const token = "t".repeat(80);

    await svc.register(u, { token, platform: "android" });

    expect(deletes).toContainEqual({ token, userId: { not: "u9" } });
    expect(upserts).toHaveLength(1);
  });
});
