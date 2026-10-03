-- AMOL-17 (upcoming quizzes): a live program can BE a scheduled quiz.
-- The id points at packages/content quizzes.json (validated by the admin API).
ALTER TABLE "LiveProgram" ADD COLUMN "quizId" TEXT;
