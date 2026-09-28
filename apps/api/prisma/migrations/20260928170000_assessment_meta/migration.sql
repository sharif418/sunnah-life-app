-- Phase C/D: store the client's verbatim form metadata (instructions,
-- category descriptions, scale, header fields, signature labels) next to the
-- criteria so the stored + printed text is exactly the client's.
ALTER TABLE "AssessmentTemplate" ADD COLUMN "metaJson" JSONB;
