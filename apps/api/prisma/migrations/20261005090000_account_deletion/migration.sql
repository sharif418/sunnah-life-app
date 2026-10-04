-- Google Play account deletion (DELETE /api/me): the member's own data is
-- removed and the User row is anonymised; deletedAt marks it so the token
-- guard refuses it and admin lists leave it out.
ALTER TABLE "User" ADD COLUMN "deletedAt" TIMESTAMP(3);

-- These tables had no DELETE policy, so under FORCE RLS a deletion silently
-- removed nothing (found by test/account-deletion.spec.ts): the account
-- deletion runs in the system context, admins may also tidy them.
CREATE POLICY feedback_delete ON "Feedback" FOR DELETE
  USING (current_setting('app.role', true) IN ('full_admin', 'system'));
CREATE POLICY masala_delete ON "MasalaQuestion" FOR DELETE
  USING (current_setting('app.role', true) IN ('full_admin', 'system'));
CREATE POLICY dayunlock_delete ON "DayUnlock" FOR DELETE
  USING (current_setting('app.role', true) IN ('full_admin', 'system'));
