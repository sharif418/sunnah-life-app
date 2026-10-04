-- The feedback inbox: app feedback (POST /api/feedback) was stored but no
-- screen ever read it. full_admin now lists and resolves it; the app sends
-- its version + OS with each message. (RLS from *_rls_tightening already
-- lets full_admin SELECT/UPDATE every row.)
ALTER TABLE "Feedback" ADD COLUMN "context" TEXT;
ALTER TABLE "Feedback" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'new';
CREATE INDEX "Feedback_status_createdAt_idx" ON "Feedback" ("status", "createdAt");
