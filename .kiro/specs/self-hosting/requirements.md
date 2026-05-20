# Requirements Document

## Introduction

SimpleBudget is a React-based budgeting application currently deployed on Vercel with a Supabase backend. This feature adds self-hosting support so users can run their own backend (Postgres, PostgREST, GoTrue, Kong) while optionally continuing to use the hosted frontend, or self-host the entire stack including the frontend served via Caddy. The existing Vercel deployment must remain unaffected.

## Glossary

- **Backend_Stack**: The Docker Compose services comprising Postgres, PostgREST, GoTrue, Kong, and the Migration_Runner
- **Frontend_Container**: The Docker container that builds the React application and serves it via Caddy with runtime configuration
- **Migration_Runner**: A dedicated Docker service that waits for Postgres readiness and applies SQL migration files using psql
- **Runtime_Config**: A JSON configuration file (config.json) generated at container startup that provides the frontend with backend connection details without requiring a rebuild
- **Secret_Generator**: The shell script (generate-secrets.sh) that populates missing environment variable values including JWT generation
- **Config_Writer**: The shell script (write-config.sh) that generates the Runtime_Config file from environment variables at container startup
- **Hosted_Frontend**: The production React application deployed on Vercel
- **Self_Hosted_Backend**: A user-operated instance of the Backend_Stack running via Docker Compose
- **SUPABASE_PUBLIC_URL**: The browser-safe URL where the Kong API gateway is accessible (default: http://localhost:8000)
- **ANON_KEY**: A browser-safe JWT with the "anon" role, signed with JWT_SECRET, used by supabase-js for unauthenticated API access
- **SERVICE_ROLE_KEY**: A private JWT with the "service_role" role, signed with JWT_SECRET, that must never be exposed to browser clients
- **JWT_SECRET**: A private cryptographic secret used to sign ANON_KEY and SERVICE_ROLE_KEY
- **POSTGRES_PASSWORD**: The private password for the Postgres database superuser
- **Compose_Override**: A secondary Docker Compose file (compose.frontend.yml) that extends the base compose.yml to add the Frontend_Container

## Requirements

### Requirement 1: Backend Stack Deployment

**User Story:** As a self-hosting user, I want to start the backend services with a single Docker Compose command, so that I can run my own Supabase-compatible backend with minimal effort.

#### Acceptance Criteria

1. WHEN the user runs `docker compose -f deploy/compose.yml up -d`, THE Backend_Stack SHALL start Postgres, PostgREST, GoTrue, and Kong services, with each service reporting a healthy status via Docker health checks within 60 seconds
2. WHEN the Backend_Stack starts, THE Backend_Stack SHALL expose the Kong API gateway at the SUPABASE_PUBLIC_URL (default http://localhost:8000) such that Kong accepts HTTP connections and returns a valid response to requests on port 8000
3. WHEN the Backend_Stack starts, THE Backend_Stack SHALL route supabase-js client requests through Kong to PostgREST for data operations and to GoTrue for auth operations
4. IF Postgres fails to reach a healthy state within 60 seconds, THEN THE Backend_Stack SHALL log an error message indicating the Postgres failure to Docker Compose logs and the dependent services (PostgREST, GoTrue, Kong) SHALL not start
5. IF PostgREST, GoTrue, or Kong fails to reach a healthy state within 60 seconds, THEN THE Backend_Stack SHALL log an error message indicating which service failed to Docker Compose logs
6. WHEN the Backend_Stack starts, THE Backend_Stack SHALL run the migration runner service to completion before PostgREST begins serving data requests

### Requirement 2: Automatic Database Migrations

**User Story:** As a self-hosting user, I want database migrations to run automatically when the stack starts, so that my database schema is always up to date without manual intervention.

#### Acceptance Criteria

1. WHEN the Backend_Stack starts, THE Migration_Runner SHALL attempt to connect to Postgres for up to 30 seconds, retrying every 1 second, before applying migrations
2. IF Postgres does not accept connections within 30 seconds, THEN THE Migration_Runner SHALL exit with a non-zero code and print a connection timeout error to stderr
3. WHEN Postgres is ready, THE Migration_Runner SHALL apply all SQL files from the supabase/migrations/ directory in lexicographic filename order
4. WHEN migrations have already been applied, THE Migration_Runner SHALL complete without error and without re-applying existing migrations
5. WHEN the Migration_Runner completes successfully, THE Migration_Runner SHALL exit with code 0
6. IF a migration file fails to apply, THEN THE Migration_Runner SHALL stop applying further migrations, exit with a non-zero code, and print the error details including the failing filename to stderr
7. WHEN the supabase/migrations/ directory contains no SQL files, THE Migration_Runner SHALL exit with code 0 without error

### Requirement 3: Secret Generation

**User Story:** As a self-hosting user, I want secrets to be generated automatically, so that I do not need to manually create cryptographic keys or JWTs.

#### Acceptance Criteria

1. WHEN the user runs `./deploy/scripts/generate-secrets.sh`, THE Secret_Generator SHALL populate all missing values in the .env file for the following keys: POSTGRES_PASSWORD, JWT_SECRET, SERVICE_ROLE_KEY, ANON_KEY, and DASHBOARD_PASSWORD
2. WHEN generating ANON_KEY, THE Secret_Generator SHALL produce a JWT containing `{"role": "anon", "iss": "supabase", "iat": <current_unix_timestamp>, "exp": <timestamp_at_least_10_years_in_future>}` signed with JWT_SECRET using HS256
3. WHEN generating SERVICE_ROLE_KEY, THE Secret_Generator SHALL produce a JWT containing `{"role": "service_role", "iss": "supabase", "iat": <current_unix_timestamp>, "exp": <timestamp_at_least_10_years_in_future>}` signed with JWT_SECRET using HS256
4. WHEN a value already exists in the .env file, THE Secret_Generator SHALL preserve the existing value without overwriting it
5. WHEN generating POSTGRES_PASSWORD, THE Secret_Generator SHALL produce a cryptographically random alphanumeric string of at least 32 and no more than 64 characters
6. WHEN generating JWT_SECRET, THE Secret_Generator SHALL produce a cryptographically random alphanumeric string of at least 32 and no more than 64 characters
7. IF a required dependency (openssl, base64) is missing, THEN THE Secret_Generator SHALL print an error message indicating which dependency is missing and exit with a non-zero code
8. WHEN generation completes successfully, THE Secret_Generator SHALL print a summary listing each key name and whether it was newly generated or already existed
9. WHEN generating DASHBOARD_PASSWORD, THE Secret_Generator SHALL produce a cryptographically random alphanumeric string of at least 32 and no more than 64 characters
10. IF the .env file does not exist in the working directory, THEN THE Secret_Generator SHALL print an error message indicating the file is missing and exit with a non-zero code

### Requirement 4: Full Self-Hosting with Frontend

**User Story:** As a self-hosting user, I want to self-host the frontend alongside the backend, so that I can run the entire application on my own infrastructure.

#### Acceptance Criteria

1. WHEN the user runs `docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d`, THE Frontend_Container SHALL build the React application using a multi-stage Docker build and serve the production output via Caddy
2. WHEN the Frontend_Container starts, THE Frontend_Container SHALL respond to HTTP requests on the configured FRONTEND_PORT (default 8080) with a 200 status within 30 seconds of container start
3. WHEN a request is made for a path that does not match an existing static file, THE Frontend_Container SHALL respond with the contents of index.html and an HTTP 200 status to support SPA client-side routing
4. WHEN the Frontend_Container starts, THE Config_Writer SHALL generate a config.json file in the Caddy serving directory containing supabaseUrl (from SUPABASE_PUBLIC_URL) and supabaseAnonKey (from ANON_KEY) before Caddy begins serving requests
5. WHEN a request is made for a path that matches an existing static file (JS, CSS, images, fonts), THE Frontend_Container SHALL serve that file directly with the appropriate content-type header

### Requirement 5: Runtime Frontend Configuration

**User Story:** As a self-hosting user, I want the frontend to read configuration at runtime, so that I can change backend connection details without rebuilding the frontend.

#### Acceptance Criteria

1. WHEN the Frontend_Container starts, THE Config_Writer SHALL generate a Runtime_Config JSON file containing "supabaseUrl" and "supabaseAnonKey" fields from the SUPABASE_PUBLIC_URL and ANON_KEY environment variables, and place it in the web-server's static file directory so it is fetchable by the browser
2. WHEN Runtime_Config is present and contains non-empty values, THE Hosted_Frontend SHALL use the supabaseUrl and supabaseAnonKey values from Runtime_Config for supabase-js initialization
3. IF a localStorage override is present for supabaseUrl or supabaseAnonKey, THEN THE Hosted_Frontend SHALL prioritize the localStorage value over the corresponding Runtime_Config value
4. IF neither a localStorage override nor a valid Runtime_Config is present, THEN THE Hosted_Frontend SHALL fall back to build-time environment variables for supabase-js initialization
5. IF SUPABASE_PUBLIC_URL or ANON_KEY is missing or empty at container startup, THEN THE Config_Writer SHALL print an error message indicating which variable is missing and exit with a non-zero code
6. IF Runtime_Config is present but contains empty or unparseable values, THEN THE Hosted_Frontend SHALL fall back to build-time environment variables and log a warning to the browser console

### Requirement 6: Hosted Frontend with Self-Hosted Backend

**User Story:** As a self-hosting user, I want to use the hosted frontend with my self-hosted backend, so that I can self-host only the data layer while using the maintained frontend.

#### Acceptance Criteria

1. THE Hosted_Frontend SHALL allow users to configure a custom SUPABASE_PUBLIC_URL and ANON_KEY via localStorage, which the frontend reads at initialization according to the configuration priority defined in Requirement 5
2. WHEN a custom backend URL is configured, THE Hosted_Frontend SHALL direct all supabase-js requests (auth, data, realtime) to the Self_Hosted_Backend
3. WHEN the user has not configured a custom backend, THE Hosted_Frontend SHALL connect to the production Supabase instance using build-time configuration
4. IF the configured SUPABASE_PUBLIC_URL is not a valid HTTP or HTTPS URL, THEN THE Hosted_Frontend SHALL display an error message indicating the URL format is invalid and SHALL NOT attempt to connect using the malformed value
5. WHEN the user removes the custom SUPABASE_PUBLIC_URL and ANON_KEY from localStorage, THE Hosted_Frontend SHALL revert to the production Supabase instance on the next page load

### Requirement 7: Security and Secret Isolation

**User Story:** As a self-hosting user, I want private secrets to remain isolated from the browser, so that my backend is not compromised by exposed credentials.

#### Acceptance Criteria

1. THE Backend_Stack SHALL expose only SUPABASE_PUBLIC_URL and ANON_KEY to browser clients through Runtime_Config or frontend configuration
2. THE Backend_Stack SHALL not pass SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD, or DASHBOARD_PASSWORD as environment variables to the Frontend_Container or include them in any file served by Caddy
3. THE Runtime_Config SHALL contain only supabaseUrl and supabaseAnonKey fields and no other keys
4. THE deploy/.env.example file SHALL leave secret values empty and SHALL not contain the production Supabase URL or production anon key
5. IF a committed file in the repository contains a non-empty value for SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD, or DASHBOARD_PASSWORD, THEN THE deployment SHALL fail a security review and the repository SHALL include a .gitignore entry for the .env file to prevent accidental commits
6. THE Compose_Override SHALL pass only SUPABASE_PUBLIC_URL and ANON_KEY as environment variables to the Frontend_Container

### Requirement 8: Vercel Deployment Compatibility

**User Story:** As a maintainer, I want the self-hosting additions to not affect the existing Vercel deployment, so that production users experience no disruption.

#### Acceptance Criteria

1. THE Hosted_Frontend SHALL deploy on Vercel using the same build command (npm run build) and framework configuration as before the self-hosting additions
2. WHEN deployed on Vercel, THE Hosted_Frontend SHALL use build-time environment variables for Supabase configuration when no Runtime_Config or localStorage override is present
3. THE self-hosting files (deploy/, Dockerfile, docs/self-hosting.md) SHALL not be referenced in package.json scripts, Vercel project configuration, or the frontend source code's import graph
4. THE Vercel deployment SHALL not require any new environment variables beyond those already configured for the existing production deployment
5. IF Vercel auto-detects the Dockerfile, THEN THE Vercel project configuration SHALL override the build settings to use the existing framework preset rather than container deployment

### Requirement 9: Environment Variable Template

**User Story:** As a self-hosting user, I want a documented environment variable template, so that I know which values to configure before starting the stack.

#### Acceptance Criteria

1. THE deploy/.env.example file SHALL contain all required environment variable names with descriptive comments explaining each variable's purpose
2. THE deploy/.env.example file SHALL provide sensible defaults for SUPABASE_PUBLIC_URL (http://localhost:8000), FRONTEND_PORT (8080), and DASHBOARD_USERNAME (admin)
3. THE deploy/.env.example file SHALL leave secret values (ANON_KEY, SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD, DASHBOARD_PASSWORD) empty for the Secret_Generator to fill
4. THE deploy/.env.example file SHALL group variables by category (public frontend-safe, private backend-only, optional, frontend) with section comments

### Requirement 10: Self-Hosting Documentation

**User Story:** As a self-hosting user, I want comprehensive documentation, so that I can set up, maintain, and troubleshoot my self-hosted instance.

#### Acceptance Criteria

1. THE docs/self-hosting.md file SHALL document the backend-only setup procedure including the commands: cp deploy/.env.example .env, ./deploy/scripts/generate-secrets.sh, and docker compose -f deploy/compose.yml up -d
2. THE docs/self-hosting.md file SHALL document the full self-hosting setup procedure including the commands: cp deploy/.env.example .env, ./deploy/scripts/generate-secrets.sh, and docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
3. THE docs/self-hosting.md file SHALL explain how to connect the hosted frontend to a self-hosted backend by configuring SUPABASE_PUBLIC_URL and ANON_KEY
4. THE docs/self-hosting.md file SHALL explain all environment variables and their purposes in a dedicated section
5. THE docs/self-hosting.md file SHALL include security notes explaining that ANON_KEY is browser-safe and SERVICE_ROLE_KEY, JWT_SECRET, POSTGRES_PASSWORD must never be exposed
6. THE docs/self-hosting.md file SHALL include an update/redeploy procedure covering git pull, rebuild, and restart commands
7. THE docs/self-hosting.md file SHALL include a troubleshooting section covering at minimum: Postgres connection failures, migration errors, frontend not loading, and config.json not found
8. THE docs/self-hosting.md file SHALL suggest Tailscale serve as the recommended approach for remote access without configuring HTTPS or reverse proxies
