-- Foundation-wide announcements reach everyone in the app (NAV-03): the
-- audience gender is stored so GET /api/announcements can show a sisters-
-- only notice to sisters only (guests see the everyone ones).
ALTER TABLE "Announcement" ADD COLUMN "gender" TEXT;
CREATE INDEX "Announcement_usrahId_createdAt_idx" ON "Announcement" ("usrahId", "createdAt");
