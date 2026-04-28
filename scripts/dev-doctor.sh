#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }

missing=0
warn=0

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    green "✓ $label ($cmd)"
  else
    red "✗ Missing $label ($cmd)"
    missing=$((missing + 1))
  fi
}

check_optional_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    green "✓ $label ($cmd)"
  else
    yellow "⚠ Missing optional $label ($cmd)"
    warn=$((warn + 1))
  fi
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    green "✓ Found $path"
  else
    red "✗ Missing $path"
    missing=$((missing + 1))
  fi
}

warn_if_placeholder() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if grep -En "$pattern" "$path" >/dev/null 2>&1; then
    yellow "⚠ $label looks like placeholder values in $path"
    warn=$((warn + 1))
  fi
}

check_port() {
  local port="$1"
  local name="$2"
  if command -v lsof >/dev/null 2>&1 && lsof -iTCP:"$port" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
    yellow "⚠ Port $port already in use ($name)"
    warn=$((warn + 1))
  else
    green "✓ Port $port available ($name)"
  fi
}

echo "GrantFlow dev doctor"
echo "===================="

check_cmd node "Node.js runtime"
check_cmd pnpm "pnpm package manager"
check_cmd python3 "Python runtime"
check_cmd uv "uv Python package manager"
check_cmd psql "PostgreSQL client"
check_cmd openssl "OpenSSL"
check_cmd tmux "tmux terminal multiplexer"
check_optional_cmd docker "Docker engine"

check_file ".env"
check_file "frontend/.env"

if [[ -f ".env" ]]; then
  warn_if_placeholder ".env" "^FIREBASE_SERVICE_ACCOUNT_CREDENTIALS=.*YOUR_PRIVATE_KEY" "Firebase service account"
fi

if [[ -f "frontend/.env" ]]; then
  warn_if_placeholder "frontend/.env" "^NEXT_PUBLIC_FIREBASE_API_KEY=YOUR_" "Frontend Firebase API key"
fi

check_port 3000 "frontend"
check_port 8000 "backend"
check_port 5432 "postgres"

echo
if [[ "$missing" -gt 0 ]]; then
  red "Doctor failed: $missing missing prerequisite(s), $warn warning(s)."
  exit 1
fi

if [[ "$warn" -gt 0 ]]; then
  yellow "Doctor passed with $warn warning(s)."
else
  green "Doctor passed with no warnings."
fi
