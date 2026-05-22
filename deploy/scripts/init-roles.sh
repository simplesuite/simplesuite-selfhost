#!/bin/sh
# Set passwords for internal Supabase roles
# This runs during Postgres initialization via docker-entrypoint-initdb.d

psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -d postgres <<-SQL
  ALTER ROLE supabase_auth_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
  ALTER ROLE supabase_storage_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
  ALTER ROLE authenticator WITH PASSWORD '${POSTGRES_PASSWORD}';
SQL
