import { z } from "zod";

/**
 * Environment validation (fail-fast at boot). Secrets only via env.
 */
const schema = z.object({
  DATABASE_URL: z.string().url(),
  DIRECT_URL: z.string().url().optional(),
  PORT: z.coerce.number().int().positive().default(3001),
  CORS_ORIGINS: z.string().optional().default(""),
  REDIS_URL: z.string().optional().default("redis://127.0.0.1:6380"),
  MEILI_HOST: z.string().optional().default(""),
  MEILI_KEY: z.string().optional().default(""),
  JWT_SECRET: z.string().min(8, "JWT_SECRET must be set (min 8 chars)").default("dev-only-secret-change-me-in-production"),
  // Empty is a legitimate state: auth.service falls back to JWT_SECRET when
  // JWT_REFRESH_SECRET is empty (documented dev/sandbox default). Explicitly
  // provided values must still be ≥ 8 chars. NOTE: zod validates the default
  // through the inner schema, so a plain .min(8).default("") rejected EVERY
  // boot without the var set (found by CI — runs #23 attempt 2: "JWT_REFRESH_
  // SECRET: String must contain at least 8 character(s)" with zero .env files).
  JWT_REFRESH_SECRET: z
    .string()
    .refine((v) => v.length === 0 || v.length >= 8, "JWT_REFRESH_SECRET must be empty (fallback to JWT_SECRET) or at least 8 chars")
    .optional()
    .default(""),
  ACCESS_TOKEN_TTL_MIN: z.coerce.number().int().positive().default(15),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(7),
  SMS_PROVIDER: z.enum(["mock", "sslwireless", "infobip"]).default("mock"),
  SMS_SSLWIRELESS_URL: z.string().optional().default(""),
  SMS_SSLWIRELESS_USER: z.string().optional().default(""),
  SMS_SSLWIRELESS_PASS: z.string().optional().default(""),
  SMS_INFOBIP_URL: z.string().optional().default(""),
  SMS_INFOBIP_KEY: z.string().optional().default(""),
  CONTENT_DIR: z.string().optional().default(""),
  STORAGE_DIR: z.string().optional().default("./storage"),
  S3_ENDPOINT: z.string().optional().default(""),
  S3_BUCKET: z.string().optional().default(""),
  S3_ACCESS_KEY: z.string().optional().default(""),
  S3_SECRET_KEY: z.string().optional().default(""),
  S3_PUBLIC_BASE: z.string().optional().default(""),
  APP_DOMAIN: z.string().optional().default("sunnahlife.app"),
  // FCM service-account JSON — object string OR a path to the JSON file.
  // Empty/absent ⇒ the no-op push transport (dev/sandbox default).
  FCM_SERVICE_ACCOUNT_JSON: z.string().optional().default(""),
  // ── Social sign-in (Task B5) — all optional; empty ⇒ provider disabled.
  // GOOGLE_CLIENT_ID: OAuth *web* client id — the id_token audience for the
  // Android app (which passes it as serverClientId). Empty ⇒ Google off.
  GOOGLE_CLIENT_ID: z.string().optional().default(""),
  // Optional second Google audience: the iOS OAuth client id (native iOS
  // flow tokens carry it as aud when serverClientId is not used there).
  GOOGLE_IOS_CLIENT_ID: z.string().optional().default(""),
  // APPLE_SERVICES_ID: Apple Services ID — the audience of web-flow id_tokens.
  APPLE_SERVICES_ID: z.string().optional().default(""),
  // Optional Apple audience for the NATIVE iOS flow (bundle id, e.g.
  // bd.asunnah.sunnahLife — native ASAuthorization tokens use it as aud).
  APPLE_IOS_BUNDLE_ID: z.string().optional().default(""),
  // Reserved for the Android/web Apple flow (needs a redirect on our
  // domain) — not required for the current iOS-only Apple button.
  APPLE_TEAM_ID: z.string().optional().default(""),
});

export type Env = z.infer<typeof schema>;

export function validateEnv(config: Record<string, unknown>): Env {
  const parsed = schema.safeParse(config);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
    throw new Error(`Invalid environment configuration → ${issues}`);
  }
  return parsed.data;
}
