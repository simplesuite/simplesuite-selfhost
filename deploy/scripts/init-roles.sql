-- Set passwords for internal Supabase roles
-- Runs as postgres superuser via docker-entrypoint-initdb.d on first start
-- Uses the POSTGRES_PASSWORD env var (available as :'pg_password' won't work here,
-- so we use a workaround via environment variable substitution)

-- Note: This file is executed by psql as part of the Postgres container init.
-- The password is set via the migration runner instead since docker-entrypoint-initdb.d
-- only runs on first database initialization and doesn't support env var substitution
-- in plain .sql files without a wrapper script.

-- Placeholder: actual password setting is handled by init-roles.sh
