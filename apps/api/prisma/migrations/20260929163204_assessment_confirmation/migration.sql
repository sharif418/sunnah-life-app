-- AlterTable
ALTER TABLE "Assessment" ADD COLUMN     "confirmedAt" TIMESTAMP(3),
ADD COLUMN     "decisionNote" TEXT,
ADD COLUMN     "declinedAt" TIMESTAMP(3),
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'pending_confirmation';

-- Backfill (W4i): historical rows the assessee already SIGNED were confirmed
-- by the pre-W4i submit flow — their signature is the acknowledgment. Rows
-- without an assessee signature honestly become pending_confirmation (the
-- member gets the OTP-acknowledge CTA; until then the result is not final).
UPDATE "Assessment" SET "status" = 'confirmed' WHERE "assesseeSignedAt" IS NOT NULL;

