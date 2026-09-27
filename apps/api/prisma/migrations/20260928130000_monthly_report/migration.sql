-- ─────────────────────────────────────────────────────────────────────────────
-- Task B3 — monthly Muhasaba PDF report: MonthlyReport table + RLS.
--
-- One row per (user, month): the rendered paper-form PDF's storage pointer
-- (reports/{userId}/{month}.pdf — S3 object key or STORAGE_DIR-relative path)
-- plus status/size bookkeeping. Upserted idempotently by the worker's
-- monthly-report job (1st of month 00:05 BD) and by the full-admin manual
-- trigger POST /api/admin/reports/generate.
--
-- RLS model (same shape as Reminder/AmalEntry — a report is derived diary
-- data owned by the member):
--   SELECT  the owner must be visible to the session (self, full_admin,
--          system, same-gender invigilator / same-or-headed usrah / downline)
--          — a supervisor sees exactly the reports they could have generated.
--   WRITE   same predicate (WITH CHECK) — only the system/worker context and
--          full_admin write rows; the admin/worker paths run inside
--          RlsService.system() / rls.run(full_admin).
-- ─────────────────────────────────────────────────────────────────────────────

-- CreateTable
CREATE TABLE "MonthlyReport" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "month" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ready',
    "errorBn" TEXT,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MonthlyReport_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MonthlyReport_month_idx" ON "MonthlyReport"("month");

-- CreateIndex
CREATE UNIQUE INDEX "MonthlyReport_userId_month_key" ON "MonthlyReport"("userId", "month");

-- AddForeignKey
ALTER TABLE "MonthlyReport" ADD CONSTRAINT "MonthlyReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Grants (belt+suspenders; the *_rls migration's ALTER DEFAULT PRIVILEGES
-- already covers tables created by the postgres migration role).
GRANT SELECT, INSERT, UPDATE, DELETE ON "MonthlyReport" TO sunnah_app;

-- RLS
ALTER TABLE "MonthlyReport" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "MonthlyReport" FORCE ROW LEVEL SECURITY;

CREATE POLICY app_self ON "MonthlyReport" USING (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
) WITH CHECK (
  current_setting('app.role', true) IN ('full_admin', 'system')
  OR sl_visible_user("userId")
);
