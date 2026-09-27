-- ─────────────────────────────────────────────────────────────────────────────
-- Task B4 — usrah question board: UsrahQuestion table + RLS.
--
-- One row per question asked INSIDE an usrah (a member asks, the usrah head
-- answers). The live-quiz room and the leaderboard reuse the same isolation:
-- the usrah is the visibility universe.
--
-- RLS model (per-command policies; permissive policies OR-combine within a
-- command, so each command gets exactly ONE policy):
--   SELECT  own usrah's rows (usrahId = app.usrah_id), or a same-gender
--           invigilator (oversight role — like the other member-data tables),
--           or full_admin/system.
--   INSERT  only for members OF that usrah (WITH CHECK usrahId = own usrah).
--   UPDATE  only the head of THAT usrah (answering sets answer/answeredBy/
--           answeredAt) or full_admin/system. The asker cannot edit after
--           the fact; a plain member cannot answer for the head.
--   DELETE  full_admin/system only (questions are content, not messages).
-- ─────────────────────────────────────────────────────────────────────────────

-- CreateTable
CREATE TABLE "UsrahQuestion" (
    "id" TEXT NOT NULL,
    "usrahId" TEXT NOT NULL,
    "authorId" TEXT NOT NULL,
    "category" TEXT NOT NULL DEFAULT 'general',
    "question" TEXT NOT NULL,
    "answer" TEXT,
    "answeredById" TEXT,
    "answeredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsrahQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "UsrahQuestion_usrahId_createdAt_idx" ON "UsrahQuestion"("usrahId", "createdAt");

-- AddForeignKey
ALTER TABLE "UsrahQuestion" ADD CONSTRAINT "UsrahQuestion_usrahId_fkey" FOREIGN KEY ("usrahId") REFERENCES "Usrah"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "UsrahQuestion" ADD CONSTRAINT "UsrahQuestion_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "UsrahQuestion" ADD CONSTRAINT "UsrahQuestion_answeredById_fkey" FOREIGN KEY ("answeredById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Grants (idempotent; belt+suspenders on top of the *_rls default privileges).
GRANT SELECT, INSERT, UPDATE, DELETE ON "UsrahQuestion" TO sunnah_app;

-- RLS
ALTER TABLE "UsrahQuestion" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "UsrahQuestion" FORCE ROW LEVEL SECURITY;

-- visible = same usrah, or same-gender invigilator, or admin/system.
CREATE POLICY app_usrah ON "UsrahQuestion" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "usrahId" = current_setting('app.usrah_id', true)
  OR (
    current_setting('app.role', true) = 'invigilator'
    AND EXISTS (
      SELECT 1 FROM "Usrah" s
      WHERE s."id" = "UsrahQuestion"."usrahId"
        AND s."gender" = current_setting('app.gender', true)
    )
  )
);

-- asking = a member writes a question INTO their own usrah only.
CREATE POLICY app_member_ask ON "UsrahQuestion" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "usrahId" = current_setting('app.usrah_id', true)
);

-- answering = the head of that usrah (or an admin).
CREATE POLICY app_head_answer ON "UsrahQuestion" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR EXISTS (
    SELECT 1 FROM "Usrah" s
    WHERE s."id" = "UsrahQuestion"."usrahId"
      AND s."headUserId" = current_setting('app.user_id', true)
  )
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR EXISTS (
    SELECT 1 FROM "Usrah" s
    WHERE s."id" = "UsrahQuestion"."usrahId"
      AND s."headUserId" = current_setting('app.user_id', true)
  )
);

-- deletion is an admin/server matter only.
CREATE POLICY app_admin_delete ON "UsrahQuestion" FOR DELETE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);
