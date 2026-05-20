#!/bin/sh
# write-config.sh
# Generates runtime config.json from environment variables for the frontend container.
# Runs inside the Caddy container at startup before Caddy begins serving.
# Output: /usr/share/caddy/config.json

set -eu

# --- Validation ---

if [ -z "${SUPABASE_PUBLIC_URL:-}" ]; then
  echo "Error: SUPABASE_PUBLIC_URL is required" >&2
  exit 1
fi

if [ -z "${ANON_KEY:-}" ]; then
  echo "Error: ANON_KEY is required" >&2
  exit 1
fi

# --- Generate config.json ---

cat > /usr/share/caddy/config.json <<EOF
{
  "supabaseUrl": "${SUPABASE_PUBLIC_URL}",
  "supabaseAnonKey": "${ANON_KEY}"
}
EOF

echo "config.json written to /usr/share/caddy/config.json"
