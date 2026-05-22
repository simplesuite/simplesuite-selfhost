# SimpleBudget — Self-Hosting

Deploy your own SimpleBudget backend (and optionally the frontend) with Docker Compose.

> **Two deployment modes:**
> - **Backend-only** — Self-host the database and API. Use the hosted frontend at [simplebudget.vercel.app](https://simplebudget.vercel.app).
> - **Full stack** — Self-host everything, including the frontend served via Caddy.

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/simplebudgets/simplebudget-selfhost.git
cd simplebudget-selfhost

# 2. Create and populate your environment file
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..

# 3. Start the backend
docker compose -f deploy/compose.yml up -d

# 4. (Optional) Start with frontend included
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

Run your own Supabase-compatible backend while using the hosted frontend.

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

---

## Full Self-Hosting

Run the entire stack — backend and frontend — on your own machine.

```bash
cp deploy/.env.example deploy/.env
cd deploy && bash scripts/generate-secrets.sh && cd ..
docker compose -f deploy/compose.yml -f deploy/compose.frontend.yml up -d
```

Open **http://localhost:8080** in your browser.

The frontend container clones the latest [simplebudgets/simplebudget](https://github.com/simplebudgets/simplebudget) source, builds it, and serves it via Caddy. The `config.js` is auto-generated from your `.env` values at container startup — no manual configuration needed.

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
| `FRONTEND_PORT` | `8080` | Frontend | Port for the self-hosted frontend |

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
