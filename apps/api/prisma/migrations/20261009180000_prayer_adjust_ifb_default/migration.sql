-- Prayer times (2026-10-09):
--   · User.prayerAdjust — the member's own mosque: whole minutes added to each
--     of the five start times, e.g. {"fajr":2,"maghrib":5}; {} = none. The
--     server's prayer pushes use it so they ring with the mosque, not before.
--   · The Islamic Foundation Bangladesh method becomes the default. Karachi
--     was only ever the default (nobody could pick IFB before today), so
--     those rows move too; IFB is Karachi's angles with the start times
--     rounded up — at most a minute later, never earlier.

ALTER TABLE "User" ADD COLUMN "prayerAdjust" JSONB NOT NULL DEFAULT '{}';
ALTER TABLE "User" ALTER COLUMN "calcMethod" SET DEFAULT 'ifb';
UPDATE "User" SET "calcMethod" = 'ifb' WHERE "calcMethod" = 'karachi';
