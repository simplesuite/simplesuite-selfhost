-- Set passwords for internal Supabase roles using POSTGRES_PASSWORD
-- This runs during docker-entrypoint-initdb.d as superuser on first start
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
