-- AlterTable
ALTER TABLE "PersonalGoal" ADD COLUMN     "decidedAt" TIMESTAMP(3),
ADD COLUMN     "decidedById" TEXT,
ADD COLUMN     "reason" TEXT,
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'proposed';
