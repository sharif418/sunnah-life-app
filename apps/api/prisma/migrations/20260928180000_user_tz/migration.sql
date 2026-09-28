-- Phase C/W1a: every wall-clock computation (prayer pushes, week starts,
-- diary day-lock) must run in the USER's zone, not a hard-coded UTC+6.
ALTER TABLE "User" ADD COLUMN "tz" TEXT NOT NULL DEFAULT 'Asia/Dhaka';
