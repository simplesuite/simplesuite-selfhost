# Implementation Plan: Self-Hosting

## Overview

This plan implements self-hosting support for SimpleBudget, enabling backend-only and full-stack self-hosting via Docker Compose. The implementation proceeds from infrastructure scaffolding (env template, scripts, Docker configs) through frontend runtime configuration changes, ending with documentation and integration wiring.

## Tasks

- [x] 1. Set up deployment directory structure and environment template
  - [x] 1.1 Create deploy directory structure and .env.example
    - Create `deploy/` directory with subdirectories `scripts/`
    - Create `deploy/.env.example` with all required variables grouped by category (public, private, optional, frontend) with descriptive comments
    - Set sensible defaults: SUPABASE_PUBLIC_URL=http://localhost:8000, FRONTEND_PORT=8080, DASHBOARD_USERNAME=admin
    - Leave secret values (ANON_KEY, SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD, DASHBOARD_PASSWORD) empty
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 1.2 Add .gitignore entries for secrets
    - Ensure `.env` is in `.gitignore` to prevent accidental secret commits
    - Ensure `deploy/.env` is also covered
    - _Requirements: 7.5_

- [x] 2. Implement secret generation script
  - [x] 2.1 Create deploy/scripts/generate-secrets.sh
    - Implement dependency validation (openssl, base64) at startup with clear error messages
    - Implement .env file existence check with error on missing file
    - Generate POSTGRES_PASSWORD: 32-char cryptographically random alphanumeric via `openssl rand`
    - Generate JWT_SECRET: 32-char cryptographically random alphanumeric via `openssl rand`
    - Generate DASHBOARD_PASSWORD: 32-char cryptographically random alphanumeric via `openssl rand`
    - Generate ANON_KEY: JWT with `{"role":"anon","iss":"supabase","iat":<now>,"exp":<now+10y>}` signed HS256 with JWT_SECRET
    - Generate SERVICE_ROLE_KEY: JWT with `{"role":"service_role","iss":"supabase","iat":<now>,"exp":<now+10y>}` signed HS256 with JWT_SECRET
    - Preserve existing non-empty values without overwriting
    - Print summary of generated vs. existing keys on completion
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

  - [ ]* 2.2 Write property test for JWT generation round-trip
    - **Property 3: JWT generation round-trip**
    - **Validates: Requirements 3.2, 3.3**

  - [ ]* 2.3 Write property test for secret preservation and fill
    - **Property 4: Secret generator preserves existing and fills missing**
    - **Validates: Requirements 3.1, 3.4**

  - [ ]* 2.4 Write property test for generated secrets format constraints
    - **Property 5: Generated secrets format constraints**
    - **Validates: Requirements 3.5, 3.6, 3.9**

- [x] 3. Implement migration runner
  - [x] 3.1 Create migration runner script and schema_migrations table logic
    - Create a shell script or entrypoint for the migration runner container
    - Implement Postgres readiness polling: `pg_isready` every 1 second for up to 30 seconds
    - Create `schema_migrations` tracking table if not exists
    - Apply `.sql` files from `supabase/migrations/` in lexicographic order, skipping already-applied files
    - Wrap each migration in a transaction for atomicity
    - Exit 0 on success (including empty migrations directory)
    - Exit non-zero on failure with filename and error details to stderr
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [ ]* 3.2 Write property test for migration ordering
    - **Property 1: Migration ordering**
    - **Validates: Requirements 2.3**

  - [ ]* 3.3 Write property test for migration idempotence
    - **Property 2: Migration idempotence**
    - **Validates: Requirements 2.4**

- [x] 4. Checkpoint - Ensure scripts work correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement Docker Compose backend stack
  - [ ] 5.1 Create deploy/compose.yml with backend services
    - Define Postgres service (supabase/postgres:15) with health check (`pg_isready -U postgres`) and internal port 5432
    - Define PostgREST service (postgrest/postgrest) with health check (HTTP GET `/` returns 200), depends_on migrations completed
    - Define GoTrue service (supabase/gotrue) with health check (HTTP GET `/health` returns 200), depends_on postgres healthy
    - Define Kong service (kong:3) with health check (HTTP GET `/` returns non-5xx), depends_on postgrest and gotrue healthy, exposed on port 8000
    - Define migrations service (postgres:15-alpine with psql) mounting `./supabase/migrations:/migrations:ro`, depends_on postgres healthy
    - Configure Kong routing: `/rest/v1/*` → PostgREST, `/auth/v1/*` → GoTrue
    - Read environment variables from `.env` file
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 5.2 Create Kong declarative configuration
    - Create Kong declarative config YAML for routing `/rest/v1/` to PostgREST and `/auth/v1/` to GoTrue
    - Configure path stripping and any required plugins
    - _Requirements: 1.3_

- [ ] 6. Implement frontend container and compose override
  - [ ] 6.1 Create deploy/scripts/write-config.sh
    - Validate SUPABASE_PUBLIC_URL is present and non-empty, exit non-zero with error if missing
    - Validate ANON_KEY is present and non-empty, exit non-zero with error if missing
    - Generate `/usr/share/caddy/config.json` with exactly two keys: `supabaseUrl` and `supabaseAnonKey`
    - _Requirements: 4.4, 5.1, 5.5, 7.1, 7.3_

  - [ ]* 6.2 Write property test for config writer output
    - **Property 6: Config writer produces correct and minimal output**
    - **Validates: Requirements 5.1, 7.1, 7.3**

  - [ ] 6.3 Create deploy/Caddyfile
    - Configure Caddy to listen on port 80
    - Serve static files from `/usr/share/caddy`
    - Implement SPA fallback: `try_files {path} /index.html`
    - _Requirements: 4.3, 4.5_

  - [ ] 6.4 Create Dockerfile (multi-stage build)
    - Build stage: node:22-alpine, `npm ci`, `npm run build` → `/app/dist`
    - Runtime stage: caddy:2-alpine, copy dist, Caddyfile, and write-config.sh
    - CMD: run write-config.sh then start Caddy
    - _Requirements: 4.1_

  - [ ] 6.5 Create deploy/compose.frontend.yml
    - Define frontend service building from Dockerfile
    - Pass only SUPABASE_PUBLIC_URL and ANON_KEY as environment variables (no private secrets)
    - Expose FRONTEND_PORT (default 8080) mapped to container port 80
    - Depends_on kong healthy
    - _Requirements: 4.1, 4.2, 7.2, 7.6_

  - [ ]* 6.6 Write property test for SPA routing fallback
    - **Property 9: SPA routing fallback**
    - **Validates: Requirements 4.3**

- [ ] 7. Checkpoint - Ensure Docker configurations are valid
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement frontend runtime configuration
  - [ ] 8.1 Create configuration resolver module in frontend
    - Implement config priority chain: localStorage → config.json → build-time env vars
    - Fetch `config.json` at app initialization; on 404 or parse error, fall back silently with console warning
    - Validate URL format (must be http:// or https://); reject invalid URLs with user-facing error
    - Export resolved `supabaseUrl` and `supabaseAnonKey` for supabase-js initialization
    - _Requirements: 5.2, 5.3, 5.4, 5.6, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 8.2 Write property test for frontend config priority chain
    - **Property 7: Frontend config priority chain**
    - **Validates: Requirements 5.2, 5.3, 5.4, 6.1, 6.2**

  - [ ] 8.3 Write property test for invalid URL rejection
    - **Property 8: Invalid URL rejection**
    - **Validates: Requirements 6.4**

  - [ ] 8.4 Wire configuration resolver into supabase-js client initialization
    - Replace static build-time config with the new resolver module
    - Ensure supabase-js client uses resolved values
    - Ensure existing Vercel deployment still works with build-time env vars as fallback
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 9. Ensure Vercel compatibility
  - [ ] 9.1 Verify Vercel deployment is unaffected
    - Confirm deploy/, Dockerfile, and docs/self-hosting.md are not referenced in package.json scripts or frontend import graph
    - Confirm no new environment variables are required for Vercel deployment
    - Add vercel.json or framework preset override if needed to prevent Dockerfile auto-detection
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 10. Create self-hosting documentation
  - [ ] 10.1 Create docs/self-hosting.md
    - Document backend-only setup procedure (cp .env.example, generate-secrets, docker compose up)
    - Document full self-hosting setup procedure (with compose.frontend.yml)
    - Explain how to connect hosted frontend to self-hosted backend (localStorage config)
    - Document all environment variables and their purposes
    - Include security notes (ANON_KEY is browser-safe; SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD must never be exposed)
    - Include update/redeploy procedure (git pull, rebuild, restart)
    - Include troubleshooting section (Postgres failures, migration errors, frontend not loading, config.json not found)
    - Recommend Tailscale serve for remote access
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_

- [ ] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document using fast-check
- Shell scripts (generate-secrets.sh, write-config.sh, migration runner) are implemented in bash
- Frontend configuration resolver is implemented in TypeScript
- Docker Compose files use YAML with environment variable substitution from .env

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "3.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "3.2", "3.3", "5.2"] },
    { "id": 3, "tasks": ["5.1", "6.1", "6.3"] },
    { "id": 4, "tasks": ["6.2", "6.4", "6.6"] },
    { "id": 5, "tasks": ["6.5", "8.1"] },
    { "id": 6, "tasks": ["8.2", "8.3", "8.4"] },
    { "id": 7, "tasks": ["9.1", "10.1"] }
  ]
}
```
