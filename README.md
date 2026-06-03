<p align="center">
<img width="250" height="250" alt="logo" src="https://github.com/user-attachments/assets/57426cb2-3e99-45ba-918c-8d79126c6571" />
</p>

# simpleSuite — Self-Hosting
Deploy your own simpleSuite backend (and optionally the frontend) with Docker Compose. Supports both **simpleBudget** and **simpleTracker**.

> **Two deployment modes:**
> - **Backend-only** — Self-host the database and API. Use the hosted frontends at [budget.simplesuite.dev](https://budget.simplesuite.dev) or [tracker.simplesuite.dev](https://tracker.simplesuite.dev).
> - **Full stack** — Self-host everything, including the frontend served via Caddy.

---

## Supported Apps

| App | Frontend Repo | Hosted URL |
|-----|---------------|------------|
| simpleBudget | [simplesuite/simplebudget](https://github.com/simplesuite/simplebudget) | [budget.simplesuite.dev](https://budget.simplesuite.dev) |
| simpleTracker | [simplesuite/simpletracker](https://github.com/simplesuite/simpletracker) | [tracker.simplesuite.dev](https://tracker.simplesuite.dev) |

Both apps share the same Supabase backend. A single self-hosted instance supports both.

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/simplesuite/simplesuite-selfhost.git
cd simplesuite-selfhost

# 2. Create and populate your environment file
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..

# 3. Start the backend
docker compose -f deploy/compose.yml up -d

# 4. (Optional) Start with a frontend included
#    Set FRONTEND_APP in deploy/.env to: simplebudget or simpletracker
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
```

The API gateway will be available at **http://localhost:8000**.  
The frontend (if enabled) will be at **http://localhost:8080**.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| [Docker](https://docs.docker.com/get-docker/) + Compose v2 | `docker compose version` should return 2.x+ |
| Bash shell | Git Bash on Windows; native on macOS/Linux |
| `openssl`, `base64` | Required by the secret generator script |

> **Windows users:** Run all `bash` commands from Git Bash, not PowerShell or CMD.

---

## Backend-Only Setup

Run your own Supabase-compatible backend while using the hosted frontends.

```bash
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..
docker compose -f deploy/compose.yml up -d
```

Verify everything is healthy:

```bash
docker compose -f deploy/compose.yml ps
```

Then open the hosted frontend and use the **Config Backend** page to enter:
- **URL:** `http://localhost:8000` (or your server's address)
- **Anon Key:** The `ANON_KEY` value from `deploy/.env`

This works for both simpleBudget and simpleTracker — they share the same backend.

---

## Full Self-Hosting

Run the entire stack — backend and frontend — on your own machine.

```bash
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..

# Edit deploy/.env to set which app to deploy:
#   FRONTEND_APP=simplebudget   (default)
#   FRONTEND_APP=simpletracker

docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
```

Open **http://localhost:8080** in your browser.

The frontend container clones the latest source from the selected app's repo, builds it, and serves it via Caddy. The `config.js` is auto-generated from your `.env` values at container startup — no manual configuration needed.

### Hosting Both Frontends

To self-host both apps simultaneously, use the all-frontends compose file:

```bash
docker compose -f deploy/compose.yml -f deploy/compose.allfrontends.yml up -d
```

This starts:
- simpleBudget at **http://localhost:8080** (configurable via `SIMPLEBUDGET_PORT`)
- simpleTracker at **http://localhost:8081** (configurable via `SIMPLETRACKER_PORT`)

---

## Environment Variables

All config lives in `deploy/.env`. Run `generate-secrets.sh` to auto-fill secrets.

| Variable | Default | Scope | Description |
|----------|---------|-------|-------------|
| `SUPABASE_PUBLIC_URL` | `http://localhost:8000` | Public | Kong API gateway URL (browser-accessible) |
| `ANON_KEY` | *(generated)* | Public | Browser-safe JWT for unauthenticated API access |
| `SERVICE_ROLE_KEY` | *(generated)* | **Private** | Elevated JWT — bypasses RLS |
| `JWT_SECRET` | *(generated)* | **Private** | Signs all JWTs |
| `POSTGRES_PASSWORD` | *(generated)* | **Private** | Database password |
| `DASHBOARD_USERNAME` | `admin` | Optional | Studio dashboard username |
| `DASHBOARD_PASSWORD` | *(generated)* | Optional | Studio dashboard password |
| `FRONTEND_APP` | `simplebudget` | Frontend | Which app to build: `simplebudget` or `simpletracker` |
| `FRONTEND_PORT` | `8080` | Frontend | Port for single-app mode (`compose.frontend.yml`) |
| `SIMPLEBUDGET_PORT` | `8080` | Frontend | simpleBudget port for both-apps mode (`compose.allfrontends.yml`) |
| `SIMPLETRACKER_PORT` | `8081` | Frontend | simpleTracker port for both-apps mode (`compose.allfrontends.yml`) |

---

## Security

| Safe for browsers | Never expose |
|-------------------|--------------|
| `SUPABASE_PUBLIC_URL` | `SERVICE_ROLE_KEY` |
| `ANON_KEY` | `JWT_SECRET` |
| | `POSTGRES_PASSWORD` |

- `deploy/.env` is in `.gitignore` — never commit it.
- The frontend container only receives `SUPABASE_PUBLIC_URL` and `ANON_KEY`.

---

## Database Access

Connect with pgAdmin or any Postgres client:

| Setting | Value |
|---------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `postgres` |
| Username | `supabase_admin` |
| Password | Your `POSTGRES_PASSWORD` |

---

## Updating

```bash
git pull origin main

# Backend-only
docker compose -f deploy/compose.yml down
docker compose -f deploy/compose.yml up -d

# Full stack (rebuilds frontend with latest source)
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml down
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d --build
```

Migrations run automatically on every startup.

---

## Remote Access with Tailscale

The simplest way to access your instance from other devices — no port forwarding, no reverse proxy, automatic HTTPS.

```bash
tailscale serve 8000          # Expose API gateway
tailscale serve --https 8080  # Expose frontend
```

Update `SUPABASE_PUBLIC_URL` in `deploy/.env` to your Tailscale URL and restart.

---

## Troubleshooting

<details>
<summary><strong>Postgres won't start</strong></summary>

```bash
docker compose -f deploy/compose.yml logs postgres
```
Ensure `POSTGRES_PASSWORD` is set. To reset completely:
```bash
docker compose -f deploy/compose.yml down -v
docker compose -f deploy/compose.yml up -d
```
</details>

<details>
<summary><strong>Migration errors</strong></summary>

```bash
docker compose -f deploy/compose.yml logs migrations
```
To re-run from scratch (destroys data):
```bash
docker compose -f deploy/compose.yml down -v
docker compose -f deploy/compose.yml up -d
```
</details>

<details>
<summary><strong>GoTrue (auth) fails</strong></summary>

```bash
docker compose -f deploy/compose.yml logs gotrue
```
Usually caused by role passwords not being set. Fix with a full reset:
```bash
docker compose -f deploy/compose.yml down -v
docker compose -f deploy/compose.yml up -d
```
</details>

<details>
<summary><strong>CORS errors in browser</strong></summary>

Handled by the Kong CORS plugin in `deploy/kong.yml`. If a header is blocked, add it to the `headers` list and restart:
```bash
docker compose -f deploy/compose.yml restart kong
```
</details>

<details>
<summary><strong>Complete reset</strong></summary>

```bash
docker compose -f deploy/compose.yml down -v
rm deploy/.env
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..
docker compose -f deploy/compose.yml up -d
```
</details>

---

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │          Docker Compose              │
                    │                                     │
 Browser ──────────►│  Kong :8000 (API Gateway)           │
                    │    ├── /rest/v1/* → PostgREST :3000  │
                    │    └── /auth/v1/* → GoTrue :9999     │
                    │                                     │
                    │  Postgres :5432                      │
                    │  Migrations (runs once at startup)   │
                    │  Frontend :8080 (optional, Caddy)    │
                    └─────────────────────────────────────┘
```

---

## License

See [LICENSE](LICENSE).
