#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="$HOME/.local/bin:$PATH"
TMUX_ARGS=(-f /exec-daemon/tmux.portal.conf)
TMUX_ARGS_FALLBACK=()

tmux_has_config=true
if ! tmux "${TMUX_ARGS[@]}" ls >/dev/null 2>&1; then
  tmux_has_config=false
fi

tmux_cmd() {
  if [[ "$tmux_has_config" == true ]]; then
    tmux "${TMUX_ARGS[@]}" "$@"
  else
    tmux "${TMUX_ARGS_FALLBACK[@]}" "$@"
  fi
}

require_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    echo "Hint: $hint"
    exit 1
  fi
}

require_cmd tmux "sudo apt-get install -y tmux"
require_cmd curl "sudo apt-get install -y curl"
require_cmd python3 "Install Python 3.13+"
require_cmd psql "sudo apt-get install -y postgresql postgresql-contrib postgresql-16-pgvector"
require_cmd uv "curl -LsSf https://astral.sh/uv/install.sh | sh"
require_cmd pnpm "npm install -g pnpm"
require_cmd rg "sudo apt-get install -y ripgrep"

if ! sudo -n true >/dev/null 2>&1; then
  echo "This script needs sudo access for local PostgreSQL setup."
  echo "Run once to cache sudo credentials: sudo -v"
  exit 1
fi

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "Created .env from .env.example"
fi

if [[ ! -f "$ROOT_DIR/frontend/.env" ]]; then
  cp "$ROOT_DIR/frontend/.env.example" "$ROOT_DIR/frontend/.env"
  echo "Created frontend/.env from frontend/.env.example"
fi

echo "Ensuring PostgreSQL is running..."
if command -v pg_ctlcluster >/dev/null 2>&1; then
  # Ubuntu/Debian cluster manager
  sudo pg_ctlcluster 16 main start >/dev/null 2>&1 || true
elif command -v brew >/dev/null 2>&1 && [[ "$(uname -s)" == "Darwin" ]]; then
  # Homebrew-managed Postgres on macOS
  brew services start postgresql@17 >/dev/null 2>&1 || true
fi

echo "Preparing local database role and extensions..."
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='local'" | rg "1" >/dev/null || \
  sudo -u postgres psql -c "CREATE ROLE local WITH LOGIN PASSWORD 'local';"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='local'" | rg "1" >/dev/null || \
  sudo -u postgres psql -c "CREATE DATABASE local OWNER local;"
sudo -u postgres psql -d local -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >/dev/null
sudo -u postgres psql -d local -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null

echo "Installing workspace dependencies with uv and pnpm..."
uv sync --all-packages --all-extras --all-groups
pnpm install -r

echo "Applying database migrations..."
export DB_CONNECTION_STRING="postgresql+asyncpg://local:local@localhost:5432/local"
uv run alembic --config ./packages/db/alembic.ini upgrade head

echo "Starting backend in tmux session: backend-local"
SESSION_BACKEND="backend-local"
tmux_cmd has-session -t "=$SESSION_BACKEND" 2>/dev/null || \
  tmux_cmd new-session -d -s "$SESSION_BACKEND" -c "$ROOT_DIR" -- "${SHELL:-bash}" -l
tmux_cmd send-keys -t "$SESSION_BACKEND:0.0" C-c \
  "cd \"$ROOT_DIR\" && export PATH=\"$HOME/.local/bin:\$PATH\" && uv run python scripts/start_backend_local.py" C-m

echo "Starting frontend in tmux session: frontend-local"
SESSION_FRONTEND="frontend-local"
tmux_cmd has-session -t "=$SESSION_FRONTEND" 2>/dev/null || \
  tmux_cmd new-session -d -s "$SESSION_FRONTEND" -c "$ROOT_DIR" -- "${SHELL:-bash}" -l
tmux_cmd send-keys -t "$SESSION_FRONTEND:0.0" C-c \
  "cd \"$ROOT_DIR/frontend\" && pnpm dev" C-m

echo "Waiting for services..."
for _ in $(seq 1 40); do
  if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
for _ in $(seq 1 40); do
  if curl -sf http://localhost:3000 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo ""
echo "Local services are up:"
echo "  Frontend: http://localhost:3000"
echo "  Backend health: http://localhost:8000/health"
echo "  Backend docs: http://localhost:8000/schema/swagger"
echo ""
echo "Tail logs:"
if [[ "$tmux_has_config" == true ]]; then
  echo "  tmux -f /exec-daemon/tmux.portal.conf capture-pane -pt backend-local:0.0 -S -120"
  echo "  tmux -f /exec-daemon/tmux.portal.conf capture-pane -pt frontend-local:0.0 -S -120"
else
  echo "  tmux capture-pane -pt backend-local:0.0 -S -120"
  echo "  tmux capture-pane -pt frontend-local:0.0 -S -120"
fi
