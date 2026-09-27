-- ─────────────────────────────────────────────────────────────────────────────
-- Task B2 — push notifications: DeviceToken table + RLS.
--
-- One row per (user, FCM registration token). Registration endpoint upserts
-- on this composite natural key and refreshes lastSeenAt; a per-user cap
-- (MAX_TOKENS_PER_USER = 5, enforced in PushService) evicts the stalest rows.
--
-- RLS model (stricter than the generic sl_visible_user pattern — a device
-- token is a direct line to someone's phone lock screen):
--   SELECT  own rows, OR (same-gender AND (invigilator | same usrah | usrah
--           I head)) — heads/invigilators need SELECT to resolve fan-out
--           targets, but the same-gender clause makes a male head's query
--           return ZERO female-member tokens even if membership data drifts
--           (defense in depth on top of the single-gender-usrah design).
--   INSERT / UPDATE / DELETE  own rows only — supervisors can never tamper
--           with a member's device registration.
--   full_admin / system  ⇒ everything (server-side push fan-out runs as
--           the system context, with an application-level usrah-gender
--           filter in PushService.sendToUsrah as a second net).
-- ─────────────────────────────────────────────────────────────────────────────

-- CreateTable
CREATE TABLE "DeviceToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL DEFAULT 'android',
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "DeviceToken_userId_token_key" ON "DeviceToken"("userId", "token");

-- AddForeignKey
ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Grants (idempotent; the *_rls migration's ALTER DEFAULT PRIVILEGES already
-- covers tables created by the postgres migration role — this is belt+suspenders
-- for databases where that role changed).
GRANT SELECT, INSERT, UPDATE, DELETE ON "DeviceToken" TO sunnah_app;

-- RLS
ALTER TABLE "DeviceToken" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DeviceToken" FORCE ROW LEVEL SECURITY;

CREATE POLICY app_self ON "DeviceToken" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
  OR (
    current_setting('app.role', true) IN ('usrah_head', 'invigilator')
    AND EXISTS (
      SELECT 1 FROM "User" u
      WHERE u."id" = "DeviceToken"."userId"
        AND u."gender" = current_setting('app.gender', true)
        AND (
          current_setting('app.role', true) = 'invigilator'
          OR u."usrahId" = current_setting('app.usrah_id', true)
          OR EXISTS (
            SELECT 1 FROM "Usrah" s
            WHERE s."id" = u."usrahId"
              AND s."headUserId" = current_setting('app.user_id', true)
          )
        )
    )
  )
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
