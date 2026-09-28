-- Phase C/W1b: admin-editable app configuration (single row, key "app").
-- /api/config serves it; PATCH /api/admin/config writes it.
CREATE TABLE "AppConfigRow" (
    "key" TEXT NOT NULL,
    "valueJson" JSONB NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "AppConfigRow_pkey" PRIMARY KEY ("key")
);

-- runtime role reads/writes it (public config, no personal data; the admin
-- CMS writes through the API which connects as sunnah_app)
GRANT SELECT, INSERT, UPDATE, DELETE ON "AppConfigRow" TO sunnah_app;
