-- Social sign-in linked an account by ANY stored email, including one typed
-- into the profile without proof (PATCH /api/me) or imported from a CSV.
-- Whoever typed someone else's address captured that person's later Google
-- sign-in (and could pull a sister into a brother's account). From now on
-- only an email an identity provider vouched for links accounts.
ALTER TABLE "User" ADD COLUMN "emailVerifiedAt" TIMESTAMP(3);

-- Existing social-linked accounts got their email from the provider.
UPDATE "User" SET "emailVerifiedAt" = now()
 WHERE "email" IS NOT NULL AND "socialSub" IS NOT NULL;

-- Column guard: a member may CLEAR their verification (changing the email
-- does), never set it — only the auth bootstrap (system) vouches.
CREATE OR REPLACE FUNCTION sl_guard_user_columns() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('app.role', true) NOT IN ('full_admin', 'system') THEN
    IF NEW."role" IS DISTINCT FROM OLD."role"
       OR NEW."usrahId" IS DISTINCT FROM OLD."usrahId"
       OR (
         NEW."gender" IS DISTINCT FROM OLD."gender"
         AND OLD."gender" IS DISTINCT FROM 'unspecified'
       ) THEN
      RAISE EXCEPTION 'role/gender/usrahId can only be changed by full_admin (RLS column guard)';
    END IF;
    IF NEW."emailVerifiedAt" IS NOT NULL
       AND NEW."emailVerifiedAt" IS DISTINCT FROM OLD."emailVerifiedAt" THEN
      RAISE EXCEPTION 'emailVerifiedAt is set only by sign-in (RLS column guard)';
    END IF;
  END IF;
  RETURN NEW;
END $$;
