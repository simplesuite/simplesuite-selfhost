-- Set passwords for internal Supabase roles using POSTGRES_PASSWORD
-- This runs as part of the Postgres init process

ALTER ROLE supabase_auth_admin WITH PASSWORD :'pg_password';
ALTER ROLE supabase_storage_admin WITH PASSWORD :'pg_password';
ALTER ROLE authenticator WITH PASSWORD :'pg_password';
