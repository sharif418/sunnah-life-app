-- ─────────────────────────────────────────────────────────────────────────────
-- Sunnah Life — Row-Level Security (the crown jewel).
--
-- Runtime app role `sunnah_app` (NOBYPASSRLS) connects via DATABASE_URL;
-- migrations/seed use the postgres superuser via DIRECT_URL.
--
-- Session GUCs set per request inside the Prisma transaction (set_config with
-- is_local = true, so they reset at commit):
--   app.user_id  — cuid of the acting user ('' for anonymous)
--   app.gender   — 'M' | 'F' ('' for anonymous)
--   app.usrah_id — acting user's own usrah id ('' when none)
--   app.role     — user | daee | usrah_head | invigilator | full_admin
--                  | system (auth/worker bootstrap context, controlled server-side)
--
-- Policy model (mirrors src/lib/server/guard.ts assertCanAccess):
--   full_admin / system  ⇒ everything
--   self                 ⇒ own rows
--   same gender AND (invigilator | same/headed usrah | downline) ⇒ rows
-- Everything else — including the opposite gender — is refused by the database
-- itself, even if application code forgets the filter (proven in test/rls.e2e-spec.ts).
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1) Application role + grants ────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sunnah_app') THEN
    CREATE ROLE sunnah_app LOGIN PASSWORD 'sunnah_app_dev' NOSUPERUSER NOBYPASSRLS;
  END IF;
END
$$;

GRANT CONNECT ON DATABASE sunnahlife TO sunnah_app;
GRANT USAGE ON SCHEMA public TO sunnah_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sunnah_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sunnah_app;

-- ── 2) Visibility helpers (SECURITY DEFINER → no RLS recursion) ─────────────

-- True when the user identified by `uid` is visible to the current session.
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
          OR u."usrahId" = current_setting('app.usrah_id', true)
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

-- True when the usrah identified by `usid` is visible to the current session
-- (NULL = global → visible to everyone).
CREATE OR REPLACE FUNCTION sl_visible_usrah(usid text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT usid IS NULL
  OR current_setting('app.role', true) IN ('full_admin', 'system')
  OR usid = current_setting('app.usrah_id', true)
  OR EXISTS (
    SELECT 1 FROM "Usrah" s WHERE s."id" = usid AND (
      s."headUserId" = current_setting('app.user_id', true)
      OR (current_setting('app.role', true) = 'invigilator' AND s."gender" = current_setting('app.gender', true))
    )
  )
$$;

-- ── 3) Enable + FORCE RLS on user-scoped tables ────────────────────────────
ALTER TABLE "User"             ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User"             FORCE ROW LEVEL SECURITY;
ALTER TABLE "Session"          ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Session"          FORCE ROW LEVEL SECURITY;
ALTER TABLE "RefreshToken"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "RefreshToken"     FORCE ROW LEVEL SECURITY;
ALTER TABLE "ReferralClosure"  ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ReferralClosure"  FORCE ROW LEVEL SECURITY;
ALTER TABLE "Usrah"            ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Usrah"            FORCE ROW LEVEL SECURITY;
ALTER TABLE "AmalEntry"        ENABLE ROW LEVEL SECURITY;
ALTER TABLE "AmalEntry"        FORCE ROW LEVEL SECURITY;
ALTER TABLE "PersonalGoal"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "PersonalGoal"     FORCE ROW LEVEL SECURITY;
ALTER TABLE "DayUnlock"        ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DayUnlock"        FORCE ROW LEVEL SECURITY;
ALTER TABLE "WeeklyReview"    ENABLE ROW LEVEL SECURITY;
ALTER TABLE "WeeklyReview"    FORCE ROW LEVEL SECURITY;
ALTER TABLE "Assessment"       ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Assessment"       FORCE ROW LEVEL SECURITY;
ALTER TABLE "LevelTransition"  ENABLE ROW LEVEL SECURITY;
ALTER TABLE "LevelTransition"  FORCE ROW LEVEL SECURITY;
ALTER TABLE "Announcement"    ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Announcement"    FORCE ROW LEVEL SECURITY;
ALTER TABLE "Reminder"         ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Reminder"         FORCE ROW LEVEL SECURITY;
ALTER TABLE "Enrollment"      ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Enrollment"      FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuizAttempt"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuizAttempt"     FORCE ROW LEVEL SECURITY;

-- Exempt (public/audit tables — no RLS):
--   AmalDefinition, AssessmentTemplate, OtpCode, AuditLog, MasalaQuestion,
--   Feedback, LiveProgram.

-- ── 4) Policies ─────────────────────────────────────────────────────────────

-- Identity
CREATE POLICY app_self ON "User" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "id" = current_setting('app.user_id', true)
  OR (
    current_setting('app.gender', true) = "gender"
    AND (
      current_setting('app.role', true) = 'invigilator'
      OR "usrahId" = current_setting('app.usrah_id', true)
      OR EXISTS (SELECT 1 FROM "Usrah" s WHERE s."id" = "usrahId" AND s."headUserId" = current_setting('app.user_id', true))
      OR EXISTS (SELECT 1 FROM "ReferralClosure" rc WHERE rc."ancestorId" = current_setting('app.user_id', true) AND rc."descendantId" = "id")
    )
  )
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "id" = current_setting('app.user_id', true)
  OR (
    current_setting('app.gender', true) = "gender"
    AND (
      current_setting('app.role', true) = 'invigilator'
      OR "usrahId" = current_setting('app.usrah_id', true)
      OR EXISTS (SELECT 1 FROM "Usrah" s WHERE s."id" = "usrahId" AND s."headUserId" = current_setting('app.user_id', true))
      OR EXISTS (SELECT 1 FROM "ReferralClosure" rc WHERE rc."ancestorId" = current_setting('app.user_id', true) AND rc."descendantId" = "id")
    )
  )
);

CREATE POLICY app_self ON "Session" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);

CREATE POLICY app_self ON "RefreshToken" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);

-- Referral closure: rows where I am the ancestor (my downline), or the
-- descendant is otherwise visible to me (admin / same-gender invigilator).
CREATE POLICY app_closure ON "ReferralClosure" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "ancestorId" = current_setting('app.user_id', true)
  OR sl_visible_user("descendantId")
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "ancestorId" = current_setting('app.user_id', true)
  OR sl_visible_user("descendantId")
);

-- Usrah: own usrah, usrahs I head, same-gender invigilator oversight, admin.
CREATE POLICY app_usrah ON "Usrah" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "id" = current_setting('app.usrah_id', true)
  OR "headUserId" = current_setting('app.user_id', true)
  OR (current_setting('app.role', true) = 'invigilator' AND "gender" = current_setting('app.gender', true))
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
);

-- Muhasaba diary + per-user engagement tables: owner must be visible.
CREATE POLICY app_self ON "AmalEntry" USING (
  sl_visible_user("userId")
) WITH CHECK (
  sl_visible_user("userId")
);

CREATE POLICY app_self ON "PersonalGoal" USING (
  sl_visible_user("userId")
) WITH CHECK (
  sl_visible_user("userId")
);

CREATE POLICY app_self ON "DayUnlock" USING (
  sl_visible_user("userId")
) WITH CHECK (
  sl_visible_user("userId")
);

CREATE POLICY app_self ON "WeeklyReview" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
  OR "reviewerId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
  OR "reviewerId" = current_setting('app.user_id', true)
);

CREATE POLICY app_self ON "Assessment" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("assesseeId")
  OR "assessorId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("assesseeId")
  OR "assessorId" = current_setting('app.user_id', true)
);

CREATE POLICY app_self ON "LevelTransition" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
);

CREATE POLICY app_usrah ON "Announcement" USING (
  sl_visible_usrah("usrahId")
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_usrah("usrahId")
);

CREATE POLICY app_self ON "Reminder" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
);

CREATE POLICY app_self ON "Enrollment" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);

CREATE POLICY app_self ON "QuizAttempt" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
