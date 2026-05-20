#!/bin/bash
set -euo pipefail

# Migration Runner for SimpleBudget Self-Hosting
# Applies SQL migrations from /migrations/ to Postgres in lexicographic order.
# Tracks applied migrations in the schema_migrations table.

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

while [ $attempts -lt $max_attempts ]; do
  if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > /dev/null 2>&1; then
    echo "Postgres is ready."
    break
  fi
  attempts=$((attempts + 1))
  sleep 1
done

if [ $attempts -ge $max_attempts ]; then
  echo "Error: Postgres did not become ready within ${max_attempts} seconds." >&2
  exit 1
fi

# --- Create schema_migrations table ---
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);
SQL

# --- Apply migrations ---
shopt -s nullglob
migration_files=("$MIGRATIONS_DIR"/*.sql)
shopt -u nullglob

if [ ${#migration_files[@]} -eq 0 ]; then
  echo "No migration files found. Nothing to do."
  exit 0
fi

# Sort lexicographically (bash glob already sorts, but be explicit)
IFS=$'\n' sorted_files=($(printf '%s\n' "${migration_files[@]}" | sort))
unset IFS

for filepath in "${sorted_files[@]}"; do
  filename=$(basename "$filepath")

  # Check if already applied
  already_applied=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -tAc \
    "SELECT 1 FROM schema_migrations WHERE filename = '${filename}' LIMIT 1;")

  if [ "$already_applied" = "1" ]; then
    echo "Skipping already applied: $filename"
    continue
  fi

  echo "Applying migration: $filename"

  # Read the migration file content
  migration_sql=$(cat "$filepath")

  # Apply within a transaction (BEGIN/COMMIT) including the tracking insert
  # Use set +e to capture the exit code without triggering errexit
  set +e
  apply_result=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 <<SQL 2>&1
BEGIN;
${migration_sql}
INSERT INTO schema_migrations (filename) VALUES ('${filename}');
COMMIT;
SQL
  )
  apply_exit=$?
  set -e

  if [ $apply_exit -ne 0 ]; then
    echo "Error: Failed to apply migration '${filename}':" >&2
    echo "$apply_result" >&2
    exit 1
  fi

  echo "Applied: $filename"
done

echo "All migrations applied successfully."
exit 0
