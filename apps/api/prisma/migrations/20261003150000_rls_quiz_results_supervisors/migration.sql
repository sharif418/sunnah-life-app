-- ─────────────────────────────────────────────────────────────────────────────
-- Quiz results for supervisors (2026-10-03 audit: "quiz results are invisible
-- to supervisors").
--
-- QuizAttempt was self-only, so a usrah head could never see how the members
-- did. This adds a READ-ONLY policy through sl_visible_user — the same gate
-- that already lets a head/invigilator read the member's diary (same gender,
-- own usrah / invigilated / referral line). Writes stay self-only: the
-- existing app_self WITH CHECK is untouched, and permissive policies only
-- widen SELECT here.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS supervisor_read ON "QuizAttempt";
CREATE POLICY supervisor_read ON "QuizAttempt" FOR SELECT USING (
  "userId" IS NOT NULL AND sl_visible_user("userId")
);
