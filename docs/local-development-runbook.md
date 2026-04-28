# Local Development Runbook

This runbook is the fastest path to get GrantFlow running locally with consistent startup behavior.

## Quick Start (recommended)

From repository root:

```bash
./scripts/dev-doctor.sh
./scripts/dev-up.sh
```

Open:

- Frontend: http://localhost:3000
- Backend health: http://localhost:8000/health
- Backend docs: http://localhost:8000/schema/swagger

Stop everything:

```bash
./scripts/dev-down.sh
```

## What these scripts handle

- Tooling checks (Node, pnpm, Python, uv, Docker, Postgres client)
- `.env` and `frontend/.env` bootstrapping if missing
- PostgreSQL startup (`pg_ctlcluster` when available)
- local DB/user setup (`local:local`) and required extensions (`uuid-ossp`, `vector`)
- workspace dependency install (`uv sync`, `pnpm install -r`)
- database migrations
- backend + frontend startup in tmux sessions (`backend-local`, `frontend-local`)

## Common troubleshooting

### Backend fails on Firebase credentials

`scripts/start_backend_local.py` automatically detects placeholder
`FIREBASE_SERVICE_ACCOUNT_CREDENTIALS` values and generates temporary local credentials for startup.

For production-like behavior, replace with a real service account JSON string in `.env`.

### Port already in use

`./scripts/dev-doctor.sh` warns if ports are occupied:

- `3000` (frontend)
- `8000` (backend)
- `5432` (postgres)

Either stop competing processes or change exposed ports before running `dev-up`.

### Cloud preview asks for network token

When using cloud-hosted previews, `localhost` URLs are not directly reachable from your laptop.
Use the IDE's Ports/Preview UI and complete ingress authentication when prompted.

## Equivalent Task commands

If your machine already has Docker, Task, and all dependencies:

```bash
task setup
task dev
task frontend:dev
```

The script path (`dev-up`) exists for machines where environment drift makes Task-based startup brittle.
