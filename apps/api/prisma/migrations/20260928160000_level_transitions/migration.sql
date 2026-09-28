-- ─────────────────────────────────────────────────────────────────────────────
-- Task B6 — levels + admin CRUD: LevelTransition provenance + versioned
-- assessment templates.
--
-- LevelTransition already exists (init migration) with RLS app_self
-- (SELECT/WRITE = full_admin | system | sl_visible_user("userId") — member sees
-- own, head+ sees their usrah, full_admin sees all; unchanged here). This adds
-- the columns the nightly "levels" job and the audited admin promote need:
--   method  "auto" (nightly evaluation) | "admin" (manual override, default)
--   reason  required justification for admin promotes (Bengali)
--   actorId the promoting admin (null for auto transitions)
--
-- AssessmentTemplate versioning: `key` stops being globally unique — versions
-- of one template family share the key, differ by (key, version). Exactly one
-- version per key should be active; GET /api/assessments/templates serves the
-- ACTIVE version only, so members are unaffected by draft versions.
-- Applied manually (db execute + migrate resolve) — `migrate dev` is blocked
-- by a pre-existing checksum drift on *_social_auth (B5's file was edited
-- after it was applied; do NOT reset the shared sandbox database).
-- ─────────────────────────────────────────────────────────────────────────────

-- AlterTable
ALTER TABLE "LevelTransition" ADD COLUMN     "actorId" TEXT,
ADD COLUMN     "method" TEXT NOT NULL DEFAULT 'admin',
ADD COLUMN     "reason" TEXT;

-- AlterTable
ALTER TABLE "AssessmentTemplate" ADD COLUMN     "active" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE INDEX "LevelTransition_userId_idx" ON "LevelTransition"("userId");

-- DropIndex
DROP INDEX "AssessmentTemplate_key_key";

-- CreateIndex
CREATE UNIQUE INDEX "AssessmentTemplate_key_version_key" ON "AssessmentTemplate"("key", "version");

-- CreateIndex
CREATE INDEX "AssessmentTemplate_key_active_idx" ON "AssessmentTemplate"("key", "active");
