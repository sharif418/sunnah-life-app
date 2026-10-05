-- Defense in depth (security review 2026-10-05). The app layer already
-- refuses all of these; the database now refuses them too, so a future
-- route that forgets a check cannot open them.

-- ── Announcement ────────────────────────────────────────────────────────────
-- Before: one ALL-commands policy on sl_visible_usrah, so any member could
-- (at the DB level) insert a Foundation-wide notice (usrahId NULL is
-- "visible" to everyone) or edit/delete one, and a gender-addressed notice
-- was readable by the other gender.
DROP POLICY IF EXISTS app_usrah ON "Announcement";

CREATE POLICY ann_read ON "Announcement" FOR SELECT USING (
  sl_visible_usrah("usrahId")
  AND (
    "gender" IS NULL
    OR current_setting('app.role', true) IN ('full_admin', 'system')
    OR "gender" = current_setting('app.gender', true)
  )
);

-- Writing: an admin; or a head/invigilator as the author — for an usrah
-- they lead or invigilate, or (usrahId NULL) addressed to their own gender
-- (the broadcast screen's "my gender" audience).
CREATE POLICY ann_insert ON "Announcement" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR (
    "authorId" = current_setting('app.user_id', true)
    AND current_setting('app.role', true) IN ('usrah_head', 'invigilator')
    AND (
      ("usrahId" IS NOT NULL AND EXISTS (
        SELECT 1 FROM "Usrah" s WHERE s."id" = "Announcement"."usrahId" AND (
          s."headUserId" = current_setting('app.user_id', true)
          OR (current_setting('app.role', true) = 'invigilator'
              AND s."gender" = current_setting('app.gender', true))
        )
      ))
      OR ("usrahId" IS NULL AND "gender" = current_setting('app.gender', true))
    )
  )
);

CREATE POLICY ann_update ON "Announcement" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "authorId" = current_setting('app.user_id', true)
);

CREATE POLICY ann_delete ON "Announcement" FOR DELETE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "authorId" = current_setting('app.user_id', true)
);

-- ── UsrahQuestion ───────────────────────────────────────────────────────────
-- A member asks in their own usrah — and only as themselves.
DROP POLICY IF EXISTS app_member_ask ON "UsrahQuestion";
CREATE POLICY app_member_ask ON "UsrahQuestion" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR (
    "usrahId" = current_setting('app.usrah_id', true)
    AND "authorId" = current_setting('app.user_id', true)
  )
);
