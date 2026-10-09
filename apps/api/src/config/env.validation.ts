import { z } from "zod";

/**
 * Environment validation (fail-fast at boot). Secrets only via env.
 */
const schema = z
  .object({
  NODE_ENV: z.enum(["development", "test", "production", "staging"]).optional().default("development"),
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
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(60),
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
  THROTTLE_IP_PER_MIN: z.coerce.number().int().positive().default(600),
  THROTTLE_OTP_PER_10MIN: z.coerce.number().int().positive().default(5),
  THROTTLE_OTP_PER_DAY: z.coerce.number().int().positive().default(10),
  THROTTLE_OTP_IP_PER_HOUR: z.coerce.number().int().positive().default(60),
  THROTTLE_OTP_VERIFY_PER_DAY: z.coerce.number().int().positive().default(30),
  THROTTLE_JOIN_PER_MIN: z.coerce.number().int().positive().default(20),
  // HMAC secret of the live-quiz room tokens (quiz-token.ts). Dev fallback
  // "dev-secret"; production refuses to boot without a real value.
  QUIZ_SECRET: z.string().optional().default(""),
  // ── Operations hardening (Phase C/W2h) ──────────────────────────────────
  // Bearer/query token that unlocks GET /metrics. Unset ⇒ /metrics is open in
  // non-production and 403s in production (never accidentally public).
  METRICS_TOKEN: z.string().optional().default(""),
  // "false" disables the Swagger UI (/docs) + /openapi.json entirely; unset
  // they are enabled outside production and disabled in production.
  DOCS_ENABLED: z.string().optional().default(""),
  })
  .superRefine((env, ctx) => {
    // ── Production hardening (Phase C/W2b): a production boot with a mock
    // SMS layer, or a real provider without credentials, is REFUSED. The
    // mock provider returns the OTP in the response — logging anyone in as
    // anyone (the audit's second production blocker).
    if (env.NODE_ENV === "production") {
      // ── Secrets (Phase C/W2c): defaults/missing values refuse boot.
      if (!env.JWT_SECRET || env.JWT_SECRET === "dev-only-secret-change-me-in-production") {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["JWT_SECRET"],
          message: "JWT_SECRET must be set to a real secret in production (not the dev default)",
        });
      }
      if (!env.JWT_REFRESH_SECRET || env.JWT_REFRESH_SECRET.length < 8 || env.JWT_REFRESH_SECRET === env.JWT_SECRET) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["JWT_REFRESH_SECRET"],
          message: "JWT_REFRESH_SECRET must be set in production, ≥ 8 chars, and DIFFERENT from JWT_SECRET (no access-secret fallback)",
        });
      }
      if (!env.QUIZ_SECRET || env.QUIZ_SECRET === "dev-secret") {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["QUIZ_SECRET"],
          message: "QUIZ_SECRET must be set in production (the live-quiz room tokens default to 'dev-secret')",
        });
      }
      if (!env.CORS_ORIGINS || !env.CORS_ORIGINS.includes("http")) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["CORS_ORIGINS"],
          message: "CORS_ORIGINS must list the allowed origins in production (empty = reflect-any with credentials)",
        });
      }
      if (env.SMS_PROVIDER === "mock") {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["SMS_PROVIDER"],
          message: "SMS_PROVIDER=mock is FORBIDDEN in production (OTP would be returned in the response) — set sslwireless or infobip with credentials",
        });
      }
      if (env.SMS_PROVIDER === "sslwireless" && (!env.SMS_SSLWIRELESS_URL || !env.SMS_SSLWIRELESS_USER || !env.SMS_SSLWIRELESS_PASS)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["SMS_SSLWIRELESS_URL"],
          message: "sslwireless selected but SMS_SSLWIRELESS_URL/USER/PASS are incomplete",
        });
      }
      if (env.SMS_PROVIDER === "infobip" && (!env.SMS_INFOBIP_URL || !env.SMS_INFOBIP_KEY)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["SMS_INFOBIP_URL"],
          message: "infobip selected but SMS_INFOBIP_URL/KEY are incomplete",
        });
      }
    }
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
