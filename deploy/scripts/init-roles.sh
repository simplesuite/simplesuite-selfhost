#!/bin/bash
# Sets passwords for internal Supabase roles during Postgres container initialization.
# This runs as the postgres superuser via docker-entrypoint-initdb.d on FIRST START only.
# Uses POSTGRES_PASSWORD env var which is available from the container environment.

set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER ROLE supabase_auth_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
    ALTER ROLE authenticator WITH PASSWORD '${POSTGRES_PASSWORD}';
EOSQL

echo "Internal role passwords configured."
