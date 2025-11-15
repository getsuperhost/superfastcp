#!/usr/bin/env bash
set -e

# Dev setup: Python venv, pip deps, npm deps (if present), db migrations, build static assets
# - Does NOT run OS-level system commands like useradd or restart services
# - Uses SQLite by default, MySQL env variables can be provided when required

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# 1) Python: ensure supported Python version and create venv
PY_VER=$(python3 -c "import sys; print('%s.%s' % (sys.version_info.major, sys.version_info.minor))")
PY_MAJOR=${PY_VER%%.*}
PY_MINOR=${PY_VER##*.}

# check: if Python major is less than 3 or minor < 10, fail; otherwise allow 3.10+ (including 3.11/3.12)
if [ "$PY_MAJOR" -lt "3" ] || { [ "$PY_MAJOR" -eq "3" ] && [ "$PY_MINOR" -lt "10" ]; }; then
  echo "ERROR: Detected Python $PY_MAJOR.$PY_MINOR. This project requires Python 3.10 or newer. Please install Python >= 3.10." >&2
  exit 1
fi

if [ ! -d ".venv" ]; then
  # Prefer python3.12 if available, else python3.11, else python3.10, default to python3
  if command -v python3.12 >/dev/null 2>&1; then
    PY_CMD=python3.12
  elif command -v python3.11 >/dev/null 2>&1; then
    PY_CMD=python3.11
  elif command -v python3.10 >/dev/null 2>&1; then
    PY_CMD=python3.10
  else
    PY_CMD=python3
  fi
  $PY_CMD -m venv .venv
fi

# Activate venv for the rest of this script
# shellcheck source=/dev/null
source .venv/bin/activate

# 2) Install Python packages
pip install --upgrade pip
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi

# 3) Optional: Node.js & front-end dependencies
if [ -f package.json ]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm not installed; skipping frontend install. Install Node.js if you need to run the SPA." >&2
  else
    export NODE_OPTIONS=--openssl-legacy-provider
    npm install
    npm run development --silent || true
  fi
fi

# 4) Run Django migrations and create a development superuser
export IS_DEBUG=1
python manage.py migrate --noinput

# Create a default admin user programmatically (username: admin) if not exists
python manage.py shell -c "from core.models import User; User.objects.create_superuser(username='admin') if not User.objects.filter(username='admin').exists() else print('Dev superuser exists')"

# 5) Reminder: env variables that might be required for MySQL
cat <<EOF

Dev setup complete.

Notes:
- Default SQLite DB is created at db.sqlite3. To use MySQL in development set FASTCP_SQL_USER and FASTCP_SQL_PASSWORD in your environment before running migrations.
- The script does not call root/system commands. To test system commands in code (e.g., run_cmd, useradd), mock or patch these functions in tests (e.g., fcpsys.run_cmd = lambda *args, **kwargs: True).
- To enable ACME staging for local tests, export LETSENCRYPT_IS_STAGING=1

Try starting the dev server:
  source .venv/bin/activate
  export IS_DEBUG=1
  python manage.py runserver

EOF
