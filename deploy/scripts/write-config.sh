#!/bin/sh
# write-config.sh
# Generates runtime config.js from environment variables for the frontend container.
# Runs inside the Caddy container at startup before Caddy begins serving.
# Output: /usr/share/caddy/config.js

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

# --- Generate config.js ---

cat > /usr/share/caddy/config.js <<EOF
window.__SUPABASE_CONFIG__ = {
  url: "${SUPABASE_PUBLIC_URL}",
  key: "${ANON_KEY}"
};
EOF

echo "config.js written to /usr/share/caddy/config.js"
