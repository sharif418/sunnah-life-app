-- ─────────────────────────────────────────────────────────────────────────────
-- RLS: the reviewer/assessor clauses ignored the gender rule (2026-10-03 audit).
--
-- WeeklyReview and Assessment allowed a row whenever "reviewerId" /
-- "assessorId" was the current user — in USING *and* WITH CHECK. A male
-- reviewer could therefore INSERT a review or an assessment naming himself
-- as reviewer for a FEMALE member (and read it back), bypassing
-- sl_visible_user's gender gate entirely.
--
-- The self clause now also requires the subject to share the session's
-- gender. full_admin/system and sl_visible_user are unchanged, so every
-- legitimate flow (head/invigilator reviewing their own gender, a reviewer
-- still reading reviews of a member who left the usrah) keeps working.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sl_same_gender_user(uid text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM "User" u
    WHERE u."id" = uid
      AND u."gender" = current_setting('app.gender', true)
  );
$$;

DROP POLICY IF EXISTS app_self ON "WeeklyReview";
CREATE POLICY app_self ON "WeeklyReview" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
  OR ("reviewerId" = current_setting('app.user_id', true) AND sl_same_gender_user("userId"))
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
  OR ("reviewerId" = current_setting('app.user_id', true) AND sl_same_gender_user("userId"))
);

DROP POLICY IF EXISTS app_self ON "Assessment";
CREATE POLICY app_self ON "Assessment" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("assesseeId")
  OR ("assessorId" = current_setting('app.user_id', true) AND sl_same_gender_user("assesseeId"))
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("assesseeId")
  OR ("assessorId" = current_setting('app.user_id', true) AND sl_same_gender_user("assesseeId"))
);
