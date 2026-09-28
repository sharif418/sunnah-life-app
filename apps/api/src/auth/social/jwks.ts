// ─────────────────────────────────────────────────────────────────────────────
// Social sign-in id_token verification (Task B5) — Google + Apple.
//
// Approach (NO new npm dependencies): fetch the provider's JWKS (public keys
// in JSON Web Key format) with plain `fetch`, then verify the RS256 (Google)
// or ES256 (Apple) signature with WebCrypto (`crypto.subtle`), which both the
// node (>= 18) and bun runtimes expose globally — the same pattern the FCM
// transport (Task B2) uses for its OAuth2 client-credentials JWTs.
//
// Why JWKS + local crypto instead of Google's tokeninfo endpoint: no extra
// network hop per sign-in, one code path for both providers, and Apple has no
// tokeninfo-style endpoint at all. The trust anchors are exactly the ones the
// provider documents:
//   Google — JWKS  https://www.googleapis.com/oauth2/v3/certs   (RS256)
//            iss    https://accounts.google.com  (also "accounts.google.com")
//            aud    the OAuth client id(s) configured in GOOGLE_CLIENT_ID /
//                   GOOGLE_IOS_CLIENT_ID
//   Apple  — JWKS  https://appleid.apple.com/auth/keys           (ES256)
//            iss    https://appleid.apple.com
//            aud    APPLE_SERVICES_ID (web flow) / APPLE_IOS_BUNDLE_ID (native)
//
// JWT ES256 signatures are raw R||S (RFC 7515 / IEEE P1363) — exactly the
// format WebCrypto's ECDSA verify expects, so no DER transcoding is needed.
// ─────────────────────────────────────────────────────────────────────────────
import { ApiError } from "../../common/api-error";

export const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
export const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];
export const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
export const APPLE_ISSUERS = ["https://appleid.apple.com"];

/** JWKS refresh interval. Both providers publish new keys before retiring old
 *  ones; a kid miss always triggers one forced refetch (rotation window). */
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000;
/** Allowed client/server clock skew for the exp check. */
const CLOCK_SKEW_SEC = 60;

export interface JwtStructure {
  header: { alg?: unknown; kid?: unknown; typ?: unknown };
  payload: Record<string, unknown>;
  /** "header.payload" bytes (plain ArrayBuffer — WebCrypto BufferSource). */
  signingInput: ArrayBuffer;
}

export interface JwtVerification {
  idToken: string;
  jwksUrl: string;
  alg: "RS256" | "ES256";
  issuers: string[];
  audiences: string[];
}

/** Parse a compact JWS into header/payload/signature (no verification). */
export function parseJwt(token: string): JwtStructure {
  const parts = (token ?? "").split(".");
  if (parts.length !== 3) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }
  let header: unknown;
  let payload: unknown;
  try {
    header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }
  if (typeof header !== "object" || header === null || typeof payload !== "object" || payload === null) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }
  return { header: header as JwtStructure["header"], payload: payload as Record<string, unknown>, signingInput: toArrayBuffer(new TextEncoder().encode(`${parts[0]}.${parts[1]}`)) };
}

/** Copy a (possibly SharedArrayBuffer-backed) Uint8Array into a plain
 *  ArrayBuffer — the exact type WebCrypto's BufferSource wants. */
function toArrayBuffer(u: Uint8Array): ArrayBuffer {
  const out = new ArrayBuffer(u.byteLength);
  new Uint8Array(out).set(u);
  return out;
}

// ── JWKS fetching + cache ───────────────────────────────────────────────────

interface JwksCacheEntry {
  keys: Map<string, JsonWebKey>;
  fetchedAt: number;
}
const jwksCache = new Map<string, JwksCacheEntry>();

/** Test seam: drop the cached provider keys (jest resets modules per file). */
export function resetJwksCache(): void {
  jwksCache.clear();
}

interface RawJwks {
  keys?: Array<JsonWebKey & { kid?: string }>;
}

async function fetchJwks(jwksUrl: string, forceRefresh: boolean): Promise<Map<string, JsonWebKey>> {
  const cached = jwksCache.get(jwksUrl);
  const now = Date.now();
  if (!forceRefresh && cached && now - cached.fetchedAt < JWKS_CACHE_TTL_MS) {
    return cached.keys;
  }
  let res: Response;
  try {
    res = await fetch(jwksUrl, { headers: { Accept: "application/json" } });
  } catch {
    throw new ApiError(503, "সাইন-ইন সার্ভারে পৌঁছানো যাচ্ছে না — কিছুক্ষণ পর আবার চেষ্টা করুন");
  }
  if (!res.ok) {
    throw new ApiError(503, "সাইন-ইন সার্ভারে পৌঁছানো যাচ্ছে না — কিছুক্ষণ পর আবার চেষ্টা করুন");
  }
  const body = (await res.json().catch(() => null)) as RawJwks | null;
  if (!body || !Array.isArray(body.keys)) {
    throw new ApiError(503, "সাইন-ইন সার্ভারে পৌঁছানো যাচ্ছে না — কিছুক্ষণ পর আবার চেষ্টা করুন");
  }
  const keys = new Map<string, JsonWebKey>();
  for (const k of body.keys) {
    if (typeof k.kid === "string" && k.kid) keys.set(k.kid, k);
  }
  jwksCache.set(jwksUrl, { keys, fetchedAt: now });
  return keys;
}

// ── WebCrypto key import + signature check ───────────────────────────────────

async function importVerifyKey(alg: "RS256" | "ES256", jwk: JsonWebKey): Promise<CryptoKey> {
  if (alg === "RS256") {
    return crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );
  }
  return crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
}

async function verifySignature(
  alg: "RS256" | "ES256",
  key: CryptoKey,
  signingInput: ArrayBuffer,
  signature: ArrayBuffer
): Promise<boolean> {
  if (alg === "RS256") {
    return crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, signingInput);
  }
  return crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, signature, signingInput);
}

// ── Full verification: signature + iss + aud + exp ──────────────────────────

/**
 * Verify a provider id_token end-to-end and return its decoded payload.
 * Throws ApiError (Bengali) on ANY failure — the caller decides the status.
 */
export async function verifyIdToken(v: JwtVerification): Promise<Record<string, unknown>> {
  const { header, payload, signingInput } = parseJwt(v.idToken);
  const signatureB64 = v.idToken.split(".")[2];

  // 1) Algorithm pinning — never honor whatever alg the attacker picked.
  if (header.alg !== v.alg) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }

  // 2) Key lookup by kid (one forced refetch covers a rotation window).
  const kid = typeof header.kid === "string" ? header.kid : "";
  let keys = await fetchJwks(v.jwksUrl, false);
  let jwk = kid ? keys.get(kid) : undefined;
  if (!jwk && kid) {
    keys = await fetchJwks(v.jwksUrl, true);
    jwk = keys.get(kid);
  }
  if (!jwk) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }

  // 3) Cryptographic signature over "header.payload".
  const signature = Buffer.from(signatureB64, "base64url");
  if (signature.length === 0) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }
  const ok = await verifySignature(
    v.alg, await importVerifyKey(v.alg, jwk), signingInput, toArrayBuffer(signature)
  ).catch(() => false);
  if (!ok) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }

  // 4) iss / aud / exp claim checks.
  const issuers = v.issuers.map((s) => s.toLowerCase());
  const iss = typeof payload.iss === "string" ? payload.iss.toLowerCase() : "";
  if (!issuers.includes(iss)) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }

  const audiences = v.audiences.map((s) => s.toLowerCase());
  const tokenAud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  const audMatch = tokenAud.some(
    (a) => typeof a === "string" && audiences.includes(a.toLowerCase())
  );
  if (!audMatch) {
    throw new ApiError(400, "সাইন-ইন টোকেন যাচাই করা যায়নি — আবার চেষ্টা করুন");
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const exp = typeof payload.exp === "number" ? payload.exp : 0;
  if (!exp || exp + CLOCK_SKEW_SEC < nowSec) {
    throw new ApiError(400, "সাইন-ইন সেশনের সময় শেষ — আবার চেষ্টা করুন");
  }

  return payload;
}

/** Extract a trimmed lowercase email from an id_token payload, if present. */
export function tokenEmail(payload: Record<string, unknown>): string | null {
  const e = payload.email;
  return typeof e === "string" && e.trim() ? e.trim().toLowerCase() : null;
}
