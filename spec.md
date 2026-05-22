# Self-Hosting Specification

## Overview

This document defines the self-hosting architecture and deployment requirements for the budgeting application.

The application currently consists of:

- React frontend
- Vercel-hosted production deployment
- Supabase backend
- Supabase Auth
- Supabase client access directly from frontend
- Existing runtime configuration support through:
  - localhost priority
  - `config.json`
  - runtime Supabase URL
  - runtime Supabase anon key

The goal is to support both:

1. Backend-only self-hosting
2. Full self-hosting

without breaking the existing hosted/Vercel deployment.

---

# Supported Deployment Modes

## Mode A — Backend-only Self-Hosting

User self-hosts:

- Supabase
- Postgres
- migrations

User continues using the hosted frontend.

Frontend connects to the self-hosted backend using:

- Supabase URL
- Supabase anon key

through existing runtime config support.

### User Flow

```sh
cp deploy/.env.example .env
./deploy/scripts/generate-secrets.sh
docker compose -f deploy/compose.yml up -d
```

Then the user copies:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

into the hosted frontend config/settings.

---

## Mode B — Full Self-Hosting

User self-hosts:

- Supabase
- Postgres
- frontend

### User Flow

```sh
cp deploy/.env.example .env
./deploy/scripts/generate-secrets.sh
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
```

Then opens:

```txt
http://localhost:8080
```

No frontend rebuild should be required for runtime config changes.

---

# Architecture Goals

## Goals

- Single codebase
- Vercel deployment remains unchanged
- Runtime frontend configuration
- Automatic migration execution
- Minimal manual setup
- Docker-first self-hosting experience
- Frontend rebuilds not required for config changes
- Self-hosted backend usable with hosted frontend

---

## Non-Goals

- Do not replace Supabase Auth
- Do not remove Supabase client usage yet
- Do not build a custom backend/API layer
- Do not require frontend rebuilds for runtime config changes
- Do not expose private backend secrets to browser clients

---

# Repository Structure

Required structure:

```txt
/
  src/
  public/
  supabase/
    migrations/

  deploy/
    compose.yml
    compose.frontend.yml
    .env.example
    Caddyfile

    scripts/
      generate-secrets.sh
      write-config.sh

  docs/
    self-hosting.md

  Dockerfile
```

---

# Environment Variables

## deploy/.env.example

Create a complete example env file.

Example:

```env
# Public frontend-safe values
SUPABASE_PUBLIC_URL=http://localhost:8000
ANON_KEY=

# Private backend-only values
SERVICE_ROLE_KEY=
JWT_SECRET=
POSTGRES_PASSWORD=

# Optional dashboard/auth values
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=

# Frontend
FRONTEND_PORT=8080
```

---

## Security Rules

### Browser-safe

These values MAY be exposed to frontend clients:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

---

### Private Secrets

These values MUST NEVER be exposed to frontend clients:

```txt
SERVICE_ROLE_KEY
JWT_SECRET
POSTGRES_PASSWORD
DASHBOARD_PASSWORD
```

---

# Secret Generation

## deploy/scripts/generate-secrets.sh

Create a script that:

- Fills missing values in `.env`
- Does not overwrite existing values
- Generates secure random values for:
  - `POSTGRES_PASSWORD`
  - `JWT_SECRET`
  - `SERVICE_ROLE_KEY`
  - `ANON_KEY`
  - `DASHBOARD_PASSWORD`

---

## JWT Requirements

Generated Supabase JWTs must:

### ANON_KEY

Contain:

```json
{
  "role": "anon"
}
```

Signed with:

```txt
JWT_SECRET
```

---

### SERVICE_ROLE_KEY

Contain:

```json
{
  "role": "service_role"
}
```

Signed with:

```txt
JWT_SECRET
```

---

## Script Requirements

Script should:

- Print clear success output
- Validate required dependencies
- Fail loudly on errors
- Be idempotent

---

# Backend Compose Stack

## deploy/compose.yml

This file defines the backend-only stack.

---

## Responsibilities

### Must Start

- Postgres
- Supabase services
- migration runner

---

## Must Support

- Automatic migrations
- Safe reruns
- Local development
- Self-hosting
- Hosted frontend compatibility

---

## Supabase URL

Backend should expose:

```txt
SUPABASE_PUBLIC_URL
```

Default:

```txt
http://localhost:8000
```

---

# Migration Runner

A dedicated migration service is required.

---

## Responsibilities

- Wait for Postgres readiness
- Apply migrations from:

```txt
supabase/migrations
```

- Exit successfully if migrations already exist
- Be safe to rerun

---

## Acceptable Approaches

Either:

```sh
supabase db push
```

or equivalent SQL migration tooling.

---

# Frontend Compose Override

## deploy/compose.frontend.yml

This file adds frontend hosting support.

---

## Responsibilities

### Must

- Build the React frontend
- Serve static files via Caddy
- Generate runtime config
- Avoid rebuilds for config changes

---

## Runtime Config Inputs

Use:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

to generate frontend runtime config.

---

## Frontend Port

Expose:

```txt
${FRONTEND_PORT:-8080}
```

---

# Frontend Dockerfile

## Requirements

- Multi-stage build
- React production build
- Caddy runtime image
- Runtime config generation before Caddy startup

---

## Example Shape

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM caddy:2-alpine

COPY --from=build /app/dist /usr/share/caddy
COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY deploy/scripts/write-config.sh /usr/bin/write-config.sh

RUN chmod +x /usr/bin/write-config.sh

CMD ["/bin/sh", "-c", "/usr/bin/write-config.sh && caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"]
```

---

# Runtime Frontend Config

## deploy/scripts/write-config.sh

This script must:

- Generate frontend runtime config
- Run during container startup
- Fail loudly if required env vars are missing

---

## Output Format

If frontend uses `config.json`, generate:

```json
{
  "supabaseUrl": "...",
  "supabaseAnonKey": "..."
}
```

from:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

---

# Frontend Config Priority

Frontend configuration priority must remain:

```txt
1. localhost/local override
2. runtime config.json
3. build-time env vars
```

No frontend rebuild should be required when changing runtime config.

---

# Caddy Configuration

## deploy/Caddyfile

Serve React SPA correctly.

Required behavior:

- Static file serving
- SPA routing fallback

Example:

```caddyfile
:80 {
  root * /usr/share/caddy
  try_files {path} /index.html
  file_server
}
```

---

# Hosted Frontend Compatibility

Hosted frontend MUST support:

```txt
Hosted frontend + self-hosted backend
```

through runtime configuration.

User should be able to paste:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

into frontend config/settings without rebuilding anything.

---

# Docker Compose Usage

## Backend-only

```sh
docker compose -f deploy/compose.yml up -d
```

---

## Full Self-Hosting

```sh
docker compose \
  -f deploy/compose.yml \
  -f deploy/compose.frontend.yml \
  up -d
```

---

# Documentation Requirements

Create:

```txt
docs/self-hosting.md
```

---

## Required Sections

### Overview

Explain supported deployment modes.

---

### Backend-only Setup

Document:

```sh
cp deploy/.env.example .env
./deploy/scripts/generate-secrets.sh
docker compose -f deploy/compose.yml up -d
```

Explain how to use:

```txt
SUPABASE_PUBLIC_URL
ANON_KEY
```

with hosted frontend.

---

### Full Self-Hosting

Document:

```sh
cp deploy/.env.example .env
./deploy/scripts/generate-secrets.sh
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
```

Then open:

```txt
http://localhost:8080
```

---

### Environment Variables

Explain all env vars.

---

### Security Notes

Clearly explain:

```txt
ANON_KEY is safe for browser use.
SERVICE_ROLE_KEY must never be exposed.
```

---

### Updating

Document update/redeploy flow.

---

### Troubleshooting

Include common issues.

---

# Acceptance Criteria

The implementation is complete when:

- Backend-only stack starts successfully
- Full self-host stack starts successfully
- Migrations run automatically
- Migration reruns are safe
- Runtime frontend config works
- Frontend does not require rebuilds for config changes
- Hosted frontend can connect to self-hosted backend
- No private secrets leak to frontend
- Vercel deployment remains unaffected
- Documentation is complete and accurate

# Other information
- simplebudget primary repo for front end: https://github.com/simplebudgets/simplebudget/
- production supabase url: https://psdmjjcvaxejxktqwdcm.supabase.co
- production key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzZG1qamN2YXhlanhrdHF3ZGNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NzAzMzA0ODMsImV4cCI6MTk4NTkwNjQ4M30.7Uqw2v3Ny5FvPBRBbbvtcUxJj_ReNDjRBUn6cWlal_o





TABLE INFORMATIONS
Definitions
table name: budgets
column_name,data_type,is_nullable,column_default
recordID,character varying,NO,null
creatorID,uuid,NO,null
budgetName,character varying,YES,null
 
table name: categories
column_name,data_type,is_nullable,column_default
recordID,character varying,NO,null
sectionID,character varying,NO,null
categoryName,character varying,NO,null
amount,numeric,NO,null
categoryNote,text,YES,null
 
table name: sections
column_name,data_type,is_nullable,column_default
recordID,character varying,NO,null
sectionName,character varying,NO,null
budgetID,character varying,NO,null
sectionType,character varying,NO,null
sectionYear,numeric,NO,null
sectionMonth,character varying,NO,null
 
table name: shared
column_name,data_type,is_nullable,column_default
recordID,character varying,NO,null
budgetID,character varying,NO,null
sharedToID,uuid,NO,null
 
table name: transactions
column_name,data_type,is_nullable,column_default
recordID,character varying,NO,null
budgetID,character varying,NO,null
categoryID,character varying,YES,null
amount,numeric,NO,null
title,character varying,NO,null
transactionType,character varying,NO,null
creatorID,uuid,YES,null
transactionDate,numeric,NO,null
 
table name: users
column_name,data_type,is_nullable,column_default
recordID,uuid,NO,null
fullName,character varying,NO,null
userType,character varying,NO,null


Table Policies:
schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
public,budgets,DELETE -> creators + authenticated ./,PERMISSIVE,{authenticated},DELETE,"( SELECT (auth.uid() = budgets.""creatorID""))",null
public,budgets,INSERT -> authenticated ./,PERMISSIVE,{authenticated},INSERT,null,true
public,budgets,SELECT -> authenticated ./,PERMISSIVE,{authenticated},SELECT,true,null
public,budgets,UPDATE -> creators + authenticated ./,PERMISSIVE,{authenticated},UPDATE,"( SELECT (auth.uid() = budgets.""creatorID""))","( SELECT (auth.uid() = budgets.""creatorID""))"
public,categories,ALL - creator/shared + authenticated ./,PERMISSIVE,{authenticated},ALL,"((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text IN ( SELECT sections.""budgetID""
           FROM sections
          WHERE ((sections.""recordID"")::text = (categories.""sectionID"")::text))))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text IN ( SELECT sections.""budgetID""
           FROM sections
          WHERE ((sections.""recordID"")::text = (categories.""sectionID"")::text))))))","((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text IN ( SELECT sections.""budgetID""
           FROM sections
          WHERE ((sections.""recordID"")::text = (categories.""sectionID"")::text))))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text IN ( SELECT sections.""budgetID""
           FROM sections
          WHERE ((sections.""recordID"")::text = (categories.""sectionID"")::text))))))"
public,sections,ALL - creator/shared + authenticated ./,PERMISSIVE,{authenticated},ALL,"((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((sections.""budgetID"")::text = (sections.""budgetID"")::text))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text = (shared.""budgetID"")::text))))","((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((sections.""budgetID"")::text = (sections.""budgetID"")::text))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text = (shared.""budgetID"")::text))))"
public,shared,DELETE -> creator + authenticated,PERMISSIVE,{authenticated},DELETE,"(auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (shared.""budgetID"")::text)))",null
public,shared,INSERT -> creator + authenticated,PERMISSIVE,{authenticated},INSERT,null,"(auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (shared.""budgetID"")::text)))"
public,shared,SELECT -> authenticated,PERMISSIVE,{authenticated},SELECT,true,null
public,shared,UPDATE -> creator + authenticated,PERMISSIVE,{authenticated},UPDATE,"(auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (shared.""budgetID"")::text)))","(auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (shared.""budgetID"")::text)))"
public,transactions,ALL -> creator/shared + authenticated ./,PERMISSIVE,{authenticated},ALL,"((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (transactions.""budgetID"")::text))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text = (shared.""budgetID"")::text))))","((auth.uid() IN ( SELECT budgets.""creatorID""
   FROM budgets
  WHERE ((budgets.""recordID"")::text = (transactions.""budgetID"")::text))) OR (auth.uid() IN ( SELECT shared.""sharedToID""
   FROM shared
  WHERE ((shared.""budgetID"")::text = (shared.""budgetID"")::text))))"
public,users,INSERT -> authenticated,PERMISSIVE,{public},INSERT,null,true
public,users,SELECT -> authenticated,PERMISSIVE,{authenticated},SELECT,true,null
public,users,UPDATE -> creator,PERMISSIVE,{authenticated},UPDATE,"(auth.uid() = ""recordID"")","(auth.uid() = ""recordID"")"

Table Relationships:
relationships:
source_table,source_column,target_table,target_column,constraint_name
transactions,creatorID,users,recordID,transactions_creatorID_fkey
shared,budgetID,budgets,recordID,shared_budgetID_fkey
shared,sharedToID,users,recordID,shared_sharedToID_fkey
budgets,creatorID,users,recordID,budgets_creatorID_fkey
categories,sectionID,sections,recordID,categories_sectionID_fkey
transactions,budgetID,budgets,recordID,transactions_budgetID_fkey
sections,budgetID,budgets,recordID,sections_budgetID_fkey
transactions,categoryID,categories,recordID,transactions_categoryID_fkey