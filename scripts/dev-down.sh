#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

kill_session_if_exists() {
  local session="$1"
  if tmux_cmd has-session -t "=$session" 2>/dev/null; then
    tmux_cmd kill-session -t "$session"
    echo "✓ Stopped tmux session: $session"
  fi
}

stop_postgres_if_running() {
  if command -v pg_isready >/dev/null 2>&1; then
    if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        if sudo -n true >/dev/null 2>&1; then
          sudo pg_ctlcluster 16 main stop >/dev/null 2>&1 || true
          echo "✓ Stopped local PostgreSQL cluster"
          return
        fi
      fi
      echo "ℹ PostgreSQL appears to be running on :5432 (left running)"
    fi
  fi
}

echo "Stopping GrantFlow local dev services..."
kill_session_if_exists "frontend-local"
kill_session_if_exists "backend-local"

if command -v docker >/dev/null 2>&1; then
  (
    cd "$ROOT_DIR"
    docker compose --profile services down >/dev/null 2>&1 || true
  )
  echo "✓ Stopped Docker compose services profile"
fi

stop_postgres_if_running

echo ""
echo "All requested local services are stopped."
