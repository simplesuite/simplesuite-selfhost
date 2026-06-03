#!/bin/sh
set -eu

# Migration Runner for SimpleBudget Self-Hosting
# Applies SQL migrations from /migrations/ to Postgres in lexicographic order.
# Tracks applied migrations in the app_schema_migrations table.

PGHOST="${PGHOST:-postgres}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-postgres}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-/migrations}"

export PGPASSWORD="${POSTGRES_PASSWORD}"

# --- Wait for Postgres readiness ---
echo "Waiting for Postgres to be ready..."
attempts=0
max_attempts=30

while [ "$attempts" -lt "$max_attempts" ]; do
  if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > /dev/null 2>&1; then
    echo "Postgres is ready."
    break
  fi
  attempts=$((attempts + 1))
  sleep 1
done

if [ "$attempts" -ge "$max_attempts" ]; then
  echo "Error: Postgres did not become ready within ${max_attempts} seconds." >&2
  exit 1
fi

# --- Note: Role passwords (authenticator, supabase_auth_admin) are set by
# the supabase/postgres image during initialization using POSTGRES_PASSWORD.
# No manual ALTER ROLE needed here.

# --- Create app_schema_migrations table ---
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS public.app_schema_migrations (
  filename TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);
SQL

# --- Apply migrations ---
migration_count=0

for filepath in "$MIGRATIONS_DIR"/*.sql; do
  # Handle case where glob matches nothing
  [ -e "$filepath" ] || continue

  migration_count=$((migration_count + 1))
  filename=$(basename "$filepath")

  # Check if already applied
  already_applied=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -tAc \
    "SELECT 1 FROM public.app_schema_migrations WHERE filename = '${filename}' LIMIT 1;")

  if [ "$already_applied" = "1" ]; then
    echo "Skipping already applied: $filename"
    continue
  fi

  echo "Applying migration: $filename"

  # Build a combined SQL that wraps the migration in a transaction
  # and records it in app_schema_migrations
  tmpfile=$(mktemp)
  printf 'BEGIN;\n' > "$tmpfile"
  cat "$filepath" >> "$tmpfile"
  printf '\nINSERT INTO public.app_schema_migrations (filename) VALUES ('\''%s'\'');\n' "$filename" >> "$tmpfile"
  printf 'COMMIT;\n' >> "$tmpfile"

  if ! psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -f "$tmpfile" 2>&1; then
    echo "Error: Failed to apply migration '${filename}'" >&2
    rm -f "$tmpfile"
    exit 1
  fi

  rm -f "$tmpfile"
  echo "Applied: $filename"
done

if [ "$migration_count" -eq 0 ]; then
  echo "No migration files found. Nothing to do."
fi

echo "All migrations applied successfully."
exit 0
