-- Content workflow (2026-10-09): content roles + versioned content packs.
--   · User.contentRole — null | 'editor' | 'reviewer', set only by full_admin
--     (the column guard trigger below now covers it too).
--   · ContentRevision — every version of a content pack: draft → in_review →
--     published | rejected; older published versions stay for rollback.
--     System-only RLS: the CMS endpoints check the caller's content role and
--     then work in the system context.

ALTER TABLE "User" ADD COLUMN "contentRole" TEXT;

CREATE TABLE "ContentRevision" (
    "id" TEXT NOT NULL,
    "pack" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "dataJson" JSONB NOT NULL,
    "itemCount" INTEGER NOT NULL DEFAULT 0,
    "note" TEXT,
    "reviewNote" TEXT,
    "authorId" TEXT NOT NULL,
    "reviewerId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "publishedAt" TIMESTAMP(3),
    CONSTRAINT "ContentRevision_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ContentRevision_pack_version_key" ON "ContentRevision"("pack", "version");
CREATE INDEX "ContentRevision_pack_status_idx" ON "ContentRevision"("pack", "status");

GRANT SELECT, INSERT, UPDATE, DELETE ON "ContentRevision" TO sunnah_app;
ALTER TABLE "ContentRevision" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ContentRevision" FORCE ROW LEVEL SECURITY;
CREATE POLICY content_revision_system ON "ContentRevision"
  USING (current_setting('app.role', true) = 'system')
  WITH CHECK (current_setting('app.role', true) = 'system');

-- the column guard: contentRole joins role/usrahId (no self-granting)
CREATE OR REPLACE FUNCTION sl_guard_user_columns() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('app.role', true) NOT IN ('full_admin', 'system') THEN
    IF NEW."role" IS DISTINCT FROM OLD."role"
       OR NEW."usrahId" IS DISTINCT FROM OLD."usrahId"
       OR NEW."contentRole" IS DISTINCT FROM OLD."contentRole"
       OR (
         NEW."gender" IS DISTINCT FROM OLD."gender"
         AND OLD."gender" IS DISTINCT FROM 'unspecified'
       ) THEN
      RAISE EXCEPTION 'role/gender/usrahId/contentRole can only be changed by full_admin (RLS column guard)';
    END IF;
    IF NEW."emailVerifiedAt" IS NOT NULL
       AND NEW."emailVerifiedAt" IS DISTINCT FROM OLD."emailVerifiedAt" THEN
      RAISE EXCEPTION 'emailVerifiedAt is set only by sign-in (RLS column guard)';
    END IF;
  END IF;
  RETURN NEW;
END $$;
