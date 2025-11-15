#!/usr/bin/env bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# Start dev server with venv activated
if [ -f .venv/bin/activate ]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
fi

export IS_DEBUG=1

# Build front-end (optional)
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  npm run development --silent || true
fi

# Start dev server
python manage.py runserver 0.0.0.0:8000
