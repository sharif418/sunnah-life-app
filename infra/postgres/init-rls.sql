-- ─────────────────────────────────────────────────────────────────────────────
-- Sunnah Life — PostgreSQL bootstrap for the application role (RLS-enforced).
--
-- Mounted by infra/docker-compose.yml as /docker-entrypoint-initdb.d/10-rls.sql
-- and executed exactly once, on first initialisation of an empty pgdata volume
-- (the official postgres image runs everything in /docker-entrypoint-initdb.d
-- with psql and ON_ERROR_STOP, as the `postgres` superuser).
--
-- Division of responsibility (coordinate with the API workstream — apps/api):
--   * THIS FILE creates the restricted runtime role `sunnah_app` …
--         - NOBYPASSRLS  → Row-Level Security always applies to it
--         - NOSUPERUSER / NOCREATEDB / NOCREATEROLE / NOREPLICATION
--   * The API's Prisma migrations (run as the owner via DIRECT_URL) create the
--     tables, indexes, RLS policies and the `app.*` GUC consumption described
--     in docs/DATA_MODEL.md. This file must stay in sync with those grants.
--
-- Idempotent: every statement is safe to re-run (e.g. if you ever replay this
-- file manually with `docker compose exec -T postgres psql -U postgres -d
-- sunnahlife -f -`). Role creation goes through DO blocks / \gexec so a second
-- run is a no-op.
--
-- The role password is injected from the environment: the compose file passes
-- SUNNAH_APP_PASSWORD to the postgres container and psql's \getenv (psql 16+,
-- verified on 16.10) picks it up here. Keep it in sync with DATABASE_URL in
-- your .env — compose interpolates both from the same SUNNAH_APP_PASSWORD.
-- ─────────────────────────────────────────────────────────────────────────────

\getenv sunnah_app_password SUNNAH_APP_PASSWORD

\if :{?sunnah_app_password}
\else
\echo 'FATAL: SUNNAH_APP_PASSWORD is not set on the postgres container — set it in .env (see .env.example).'
\quit
\endif

-- ── 1) Restricted application role ──────────────────────────────────────────
-- \gexec executes the generated statement only when the WHERE matches, which
-- makes CREATE ROLE idempotent; the ALTER branch keeps passwords in sync on
-- replays. format(%L) safely quotes the password.

SELECT format(
         'CREATE ROLE sunnah_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
         :'sunnah_app_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sunnah_app')
\gexec

SELECT format('ALTER ROLE sunnah_app LOGIN PASSWORD %L', :'sunnah_app_password')
\gexec

DO $$
BEGIN
  -- Keep the privilege profile pinned even if the role pre-existed.
  EXECUTE 'ALTER ROLE sunnah_app NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS';
  RAISE NOTICE 'role sunnah_app ready (NOBYPASSRLS)';
END
$$;

-- ── 2) Database + schema access ─────────────────────────────────────────────
-- current_database() = the db this script was executed against (POSTGRES_DB),
-- so the grant stays correct even if you rename the database. NOTE: the API's
-- own RLS migration hardcodes GRANT … ON DATABASE sunnahlife — keep
-- POSTGRES_DB=sunnahlife in practice (see docs/DEPLOY_COOLIFY.md §4).
SELECT format('GRANT CONNECT ON DATABASE %I TO sunnah_app', current_database()) \gexec
GRANT USAGE ON SCHEMA public TO sunnah_app;

-- ── 3) Privileges on future objects ─────────────────────────────────────────
-- The API's migrations run as the owner (DIRECT_URL = POSTGRES_USER — the
-- default-privilege rules below apply to whichever superuser runs them, not
-- just a role literally named "postgres"), so every table and sequence they
-- create must inherit grants for the runtime role. ALTER DEFAULT PRIVILEGES
-- covers objects created from now on; section 4 covers anything that already
-- exists.

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sunnah_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO sunnah_app;

-- Belt & braces: identical defaults if migrations are ever run by sunnah_app
-- itself (owner of its own objects — no-op grants, kept for symmetry).
ALTER DEFAULT PRIVILEGES FOR ROLE sunnah_app IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sunnah_app;
ALTER DEFAULT PRIVILEGES FOR ROLE sunnah_app IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO sunnah_app;

-- ── 4) Privileges on existing objects (replay safety) ────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sunnah_app';
    EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sunnah_app';
    RAISE NOTICE 'granted on all existing tables/sequences in public';
  ELSE
    RAISE NOTICE 'no tables yet — migrations will inherit the default privileges';
  END IF;
END
$$;

-- ── 5) Sanity report ─────────────────────────────────────────────────────────
SELECT rolname, rolcanlogin, rolsuper, rolbypassrls
FROM pg_roles
WHERE rolname = 'sunnah_app';
