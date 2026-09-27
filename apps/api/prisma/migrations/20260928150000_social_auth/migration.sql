-- Social sign-in (Task B5): Google + Apple accounts linked by verified email.
--
-- Adds to "User":
--   socialProvider / socialSub  — the IdP + its stable subject id, so returning
--       Apple users can be found even though Apple includes `email` only on
--       the FIRST authorization.
--
-- Two PARTIAL UNIQUE indexes (raw SQL because Prisma's DSL has no expression
-- or partial indexes):
--   * ("socialProvider", "socialSub")  WHERE both non-null — one account per
--     provider identity (race guard on concurrent sign-ins).
--   * lower("email")                   WHERE email IS NOT NULL — one account
--     per email, case-insensitively. Multiple NULL emails stay allowed (every
--     phone-OTP user has email = NULL).
--
-- Online-safe: both indexes build instantly on the current data (emails are
-- all NULL today) and take no blocking locks on existing traffic.
ALTER TABLE "User" ADD COLUMN "socialProvider" TEXT;
ALTER TABLE "User" ADD COLUMN "socialSub" TEXT;

CREATE UNIQUE INDEX "User_social_identity_key"
  ON "User"("socialProvider", "socialSub")
  WHERE "socialProvider" IS NOT NULL AND "socialSub" IS NOT NULL;

CREATE UNIQUE INDEX "User_email_ci_key"
  ON "User"(lower("email"))
  WHERE "email" IS NOT NULL;

-- Lookup support for the sign-in path (find-by-sub / find-by-email).
CREATE INDEX "User_email_idx" ON "User"("email");
