-- মাসআলা answers: questions were stored but nobody could read or answer
-- them. full_admin answers (RLS masala_update already allows it); the
-- asker reads their own thread (masala_select: own rows).
ALTER TABLE "MasalaQuestion" ADD COLUMN "answeredAt" TIMESTAMP(3);
ALTER TABLE "MasalaQuestion" ADD COLUMN "answeredById" TEXT;
CREATE INDEX "MasalaQuestion_status_createdAt_idx" ON "MasalaQuestion" ("status", "createdAt");
CREATE INDEX "MasalaQuestion_userId_createdAt_idx" ON "MasalaQuestion" ("userId", "createdAt");
