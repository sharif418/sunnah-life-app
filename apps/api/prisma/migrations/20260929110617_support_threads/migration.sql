-- CreateTable
CREATE TABLE "SupportThread" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "closedAt" TIMESTAMP(3),
    "closedById" TEXT,

    CONSTRAINT "SupportThread_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SupportMessage" (
    "id" TEXT NOT NULL,
    "threadId" TEXT NOT NULL,
    "authorId" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "isAdmin" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SupportMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UsrahJoinRequest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "message" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "handledById" TEXT,
    "handledAt" TIMESTAMP(3),
    "usrahId" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsrahJoinRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "SupportThread_userId_createdAt_idx" ON "SupportThread"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "SupportMessage_threadId_createdAt_idx" ON "SupportMessage"("threadId", "createdAt");

-- CreateIndex
CREATE INDEX "UsrahJoinRequest_userId_createdAt_idx" ON "UsrahJoinRequest"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "UsrahJoinRequest_status_createdAt_idx" ON "UsrahJoinRequest"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "SupportThread" ADD CONSTRAINT "SupportThread_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportMessage" ADD CONSTRAINT "SupportMessage_threadId_fkey" FOREIGN KEY ("threadId") REFERENCES "SupportThread"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportMessage" ADD CONSTRAINT "SupportMessage_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UsrahJoinRequest" ADD CONSTRAINT "UsrahJoinRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- W4d — RLS for the three new tables (the *_usrah_questions pattern).
--
--   SupportThread / SupportMessage: user ↔ admin live support. Members see
--   and write ONLY their own rows (thread owner / message author inside an
--   own thread); full_admin/system read + moderate everything. A member
--   never sees another member's thread, even same-usrah — support is
--   private, not usrah-scoped.
--
--   UsrahJoinRequest: the member sees their own request(s); only
--   full_admin/system decide (UPDATE) — heads do not manage membership
--   assignment (mission decision: assignment is a tarbiyah-office action).
-- ─────────────────────────────────────────────────────────────────────────────

-- Grants (idempotent; on top of the *_rls default privileges).
GRANT SELECT, INSERT, UPDATE, DELETE ON "SupportThread" TO sunnah_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON "SupportMessage" TO sunnah_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON "UsrahJoinRequest" TO sunnah_app;

-- ── SupportThread: own threads; admin moderates ─────────────────────────────
ALTER TABLE "SupportThread" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "SupportThread" FORCE ROW LEVEL SECURITY;

CREATE POLICY support_thread_select ON "SupportThread" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
-- a member opens their OWN thread; admins may open one on a member's behalf.
CREATE POLICY support_thread_insert ON "SupportThread" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
-- the owner flips back to "open" when they reply on an answered thread; the
-- admin answers/closes. Reassignment is impossible (userId is not updatable
-- through any app route; RLS keeps the row owned by its creator).
CREATE POLICY support_thread_update ON "SupportThread" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
-- deletion is an admin/server matter only.
CREATE POLICY support_thread_delete ON "SupportThread" FOR DELETE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);

-- ── SupportMessage: messages of threads I own (author = me); admin moderates ──
ALTER TABLE "SupportMessage" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "SupportMessage" FORCE ROW LEVEL SECURITY;

CREATE POLICY support_message_select ON "SupportMessage" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR EXISTS (
    SELECT 1 FROM "SupportThread" t
    WHERE t."id" = "SupportMessage"."threadId"
      AND t."userId" = current_setting('app.user_id', true)
  )
);
-- a member writes INTO their own thread as themselves; the admin (full_admin)
-- writes the replies (isAdmin = true).
CREATE POLICY support_message_insert ON "SupportMessage" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR (
    "authorId" = current_setting('app.user_id', true)
    AND EXISTS (
      SELECT 1 FROM "SupportThread" t
      WHERE t."id" = "SupportMessage"."threadId"
        AND t."userId" = current_setting('app.user_id', true)
    )
  )
);
-- messages are immutable once sent (edit/retract is an admin/server matter).
CREATE POLICY support_message_update ON "SupportMessage" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);
CREATE POLICY support_message_delete ON "SupportMessage" FOR DELETE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);

-- ── UsrahJoinRequest: own request visible; decisions are full_admin ──────────
ALTER TABLE "UsrahJoinRequest" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "UsrahJoinRequest" FORCE ROW LEVEL SECURITY;

CREATE POLICY join_request_select ON "UsrahJoinRequest" FOR SELECT USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
CREATE POLICY join_request_insert ON "UsrahJoinRequest" FOR INSERT WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR "userId" = current_setting('app.user_id', true)
);
-- approve/reject (handledById/handledAt/status/usrahId/reason) is admin-only.
CREATE POLICY join_request_update ON "UsrahJoinRequest" FOR UPDATE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);
CREATE POLICY join_request_delete ON "UsrahJoinRequest" FOR DELETE USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
);
