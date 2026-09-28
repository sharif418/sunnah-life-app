-- ─────────────────────────────────────────────────────────────────────────────
-- Phase C/W2e — RLS tightening (the audit's fourth production blocker).
--
--  (a) the User policy's usrahId-clause applied to EVERY role — a plain
--      member could read same-gender usrah peers' DIARIES through
--      sl_visible_user. Now gated on usrah_head/invigilator. The roster
--      (names only) survives via the new sl_usrah_roster() projection.
--  (b) DayUnlock inserts are usrah_head+ AT THE DATABASE LEVEL (split
--      per-command policies).
--  (c) OtpCode / AuditLog / MasalaQuestion / Feedback hold personal data
--      and had NO RLS — protected now.
--  (d) users cannot change their own role/gender/usrahId at the DB level
--      (BEFORE UPDATE trigger; only full_admin/system contexts may).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── (a) sl_visible_user: gate the same-usrah clause ─────────────────────────
CREATE OR REPLACE FUNCTION sl_visible_user(uid text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM "User" u WHERE u."id" = uid AND (
      current_setting('app.role', true) IN ('full_admin', 'system')
      OR u."id" = current_setting('app.user_id', true)
      OR (
        current_setting('app.gender', true) = u."gender"
        AND (
          current_setting('app.role', true) = 'invigilator'
          OR (
            -- same-usrah visibility is for HEADS and INVIGILATORS, not plain
            -- members: a member must not read peers' diaries [W2e (a)]
            current_setting('app.role', true) = 'usrah_head'
            AND u."usrahId" = current_setting('app.usrah_id', true)
          )
          OR EXISTS (
            SELECT 1 FROM "Usrah" s
            WHERE s."id" = u."usrahId"
              AND s."headUserId" = current_setting('app.user_id', true)
          )
          OR EXISTS (
            SELECT 1 FROM "ReferralClosure" rc
            WHERE rc."ancestorId" = current_setting('app.user_id', true)
              AND rc."descendantId" = u."id"
          )
        )
      )
    )
  )
$$;

DROP POLICY app_self ON "User";
CREATE POLICY app_self ON "User" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "id" = current_setting('app.user_id', true)
  OR (
    current_setting('app.gender', true) = "gender"
    AND (
      current_setting('app.role', true) = 'invigilator'
      OR (
        current_setting('app.role', true) = 'usrah_head'
        AND "usrahId" = current_setting('app.usrah_id', true)
      )
      OR EXISTS (SELECT 1 FROM "Usrah" s WHERE s."id" = "usrahId" AND s."headUserId" = current_setting('app.user_id', true))
      OR EXISTS (SELECT 1 FROM "ReferralClosure" rc WHERE rc."ancestorId" = current_setting('app.user_id', true) AND rc."descendantId" = "id")
    )
  )
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "id" = current_setting('app.user_id', true)
);

-- ── (a-cont) usrah roster projection — names only, never diaries ────────────
-- A member sees WHO is in their own usrah (the paper usrah is a real-life
-- group); diary-level visibility stays governed by sl_visible_user above.
DROP FUNCTION IF EXISTS sl_usrah_roster(text);
CREATE OR REPLACE FUNCTION sl_usrah_roster(usid text)
RETURNS TABLE (id text, name text, member_code text, level text, gender text, category text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u."id", u."name", u."memberCode", u."level", u."gender", u."category"
  FROM "User" u
  WHERE u."usrahId" = usid
    AND (
      usid = current_setting('app.usrah_id', true)
      OR current_setting('app.role', true) IN ('full_admin', 'system')
      OR EXISTS (
        SELECT 1 FROM "Usrah" s
        WHERE s."id" = usid
          AND (
            s."headUserId" = current_setting('app.user_id', true)
            OR (
              current_setting('app.role', true) = 'invigilator'
              AND s."gender" = current_setting('app.gender', true)
            )
          )
      )
    )
$$;

-- ── (b) DayUnlock: reads for the member/supervisors, writes for heads+ ─────
DROP POLICY app_self ON "DayUnlock";
CREATE POLICY dayunlock_read ON "DayUnlock" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
  OR sl_visible_user("userId")
);
CREATE POLICY dayunlock_insert ON "DayUnlock" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR EXISTS (
    SELECT 1
    FROM "User" tu
    JOIN "Usrah" s ON s."id" = tu."usrahId"
    WHERE tu."id" = "userId"
      AND s."headUserId" = current_setting('app.user_id', true)
  )
);
CREATE POLICY dayunlock_update ON "DayUnlock" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR EXISTS (
    SELECT 1
    FROM "User" tu
    JOIN "Usrah" s ON s."id" = tu."usrahId"
    WHERE tu."id" = "userId"
      AND s."headUserId" = current_setting('app.user_id', true)
  )
);
-- no DELETE policy → deletes only via the owner connection (migrations)

-- ── (c) personal-data tables get RLS ────────────────────────────────────────
ALTER TABLE "OtpCode"      ENABLE ROW LEVEL SECURITY;
ALTER TABLE "OtpCode"      FORCE ROW LEVEL SECURITY;
ALTER TABLE "AuditLog"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "AuditLog"     FORCE ROW LEVEL SECURITY;
ALTER TABLE "MasalaQuestion" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "MasalaQuestion" FORCE ROW LEVEL SECURITY;
ALTER TABLE "Feedback"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Feedback"    FORCE ROW LEVEL SECURITY;

-- OtpCode: system context only (auth module) — even full_admin has no
-- business reading raw OTP rows.
CREATE POLICY otp_system ON "OtpCode"
  USING (current_setting('app.role', true) = 'system')
  WITH CHECK (current_setting('app.role', true) = 'system');

-- AuditLog: everyone may append ONLY their own actions? No — the audit trail
-- is written by the server (system); reads are full_admin.
CREATE POLICY audit_system ON "AuditLog" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);
CREATE POLICY audit_insert ON "AuditLog" FOR INSERT WITH CHECK (
  current_setting('app.role', true) = 'system'
);

-- MasalaQuestion / Feedback: guests may ASK (userId NULL + anonymous
-- context), users see their own, admins answer (update).
CREATE POLICY masala_select ON "MasalaQuestion" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR ("userId" IS NOT NULL AND "userId" = current_setting('app.user_id', true))
  -- guests see their own freshly-created row: Prisma's INSERT … RETURNING
  -- evaluates the SELECT policy too (the classic RLS+RETURNING trap)
  OR ("userId" IS NULL AND current_setting('app.user_id', true) = '')
);
CREATE POLICY masala_insert ON "MasalaQuestion" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
  OR ("userId" IS NULL AND current_setting('app.user_id', true) = '')
);
CREATE POLICY masala_update ON "MasalaQuestion" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);

CREATE POLICY feedback_select ON "Feedback" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR ("userId" IS NOT NULL AND "userId" = current_setting('app.user_id', true))
  -- guests see their own freshly-created row (INSERT … RETURNING)
  OR ("userId" IS NULL AND current_setting('app.user_id', true) = '')
);
CREATE POLICY feedback_insert ON "Feedback" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
  OR ("userId" IS NULL AND current_setting('app.user_id', true) = '')
);
CREATE POLICY feedback_update ON "Feedback" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);

-- ── (d) users cannot self-promote / self-gender-flip / self-move usrah ──────
-- EXCEPTION: the ONE-TIME gender completion ('unspecified' → M/F) is the
-- documented onboarding step for social-created accounts (PATCH /api/me) —
-- that single direction stays allowed for the user themself.
CREATE OR REPLACE FUNCTION sl_guard_user_columns() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('app.role', true) NOT IN ('full_admin', 'system') THEN
    IF NEW."role" IS DISTINCT FROM OLD."role"
       OR NEW."usrahId" IS DISTINCT FROM OLD."usrahId"
       OR (
         NEW."gender" IS DISTINCT FROM OLD."gender"
         AND OLD."gender" IS DISTINCT FROM 'unspecified'
       ) THEN
      RAISE EXCEPTION 'role/gender/usrahId can only be changed by full_admin (RLS column guard)';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER user_column_guard
  BEFORE UPDATE ON "User"
  FOR EACH ROW EXECUTE FUNCTION sl_guard_user_columns();
