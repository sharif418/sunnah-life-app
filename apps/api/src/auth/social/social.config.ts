// Social sign-in configuration (Task B5).
//
// Both providers are opt-in via env: GOOGLE_CLIENT_ID / APPLE_SERVICES_ID
// (+ the optional per-platform audience variants). An unset/empty value ⇒ the
// provider is DISABLED: POST /api/auth/social rejects it with a Bengali 400
// and GET /api/auth/providers reports it as off so clients hide the button.
import {
  APPLE_ISSUERS,
  APPLE_JWKS_URL,
  GOOGLE_ISSUERS,
  GOOGLE_JWKS_URL,
} from "./jwks";

export interface SocialProviderConfig {
  enabled: boolean;
  jwksUrl: string;
  alg: "RS256" | "ES256";
  issuers: string[];
  audiences: string[];
}

/** The OAuth client ids whose `aud` claim we accept for Google id_tokens. */
export function googleConfig(): SocialProviderConfig {
  const audiences = [
    process.env.GOOGLE_CLIENT_ID ?? "",
    process.env.GOOGLE_IOS_CLIENT_ID ?? "",
  ]
    .map((s) => s.trim())
    .filter(Boolean);
  return {
    enabled: audiences.length > 0,
    jwksUrl: GOOGLE_JWKS_URL,
    alg: "RS256",
    issuers: GOOGLE_ISSUERS,
    audiences,
  };
}

/**
 * The client ids whose `aud` claim we accept for Apple id_tokens. The
 * Services ID backs the web-style flow; the iOS bundle id backs the native
 * ASAuthorization flow (their tokens carry the bundle id as audience).
 */
export function appleConfig(): SocialProviderConfig {
  const audiences = [
    process.env.APPLE_SERVICES_ID ?? "",
    process.env.APPLE_IOS_BUNDLE_ID ?? "",
  ]
    .map((s) => s.trim())
    .filter(Boolean);
  return {
    enabled: audiences.length > 0,
    jwksUrl: APPLE_JWKS_URL,
    alg: "ES256",
    issuers: APPLE_ISSUERS,
    audiences,
  };
}

export function socialConfig(provider: string): SocialProviderConfig | null {
  if (provider === "google") return googleConfig();
  if (provider === "apple") return appleConfig();
  return null;
}
