# Development Install & Run — FastCP

This document explains how to set up a local development environment for FastCP and run the project safely.

## Quick start (one-liners)

1) Bootstrap all deps (Python env + npm and migrations):
```bash
./scripts/dev-setup.sh
```

2) Start the dev server:
```bash
./scripts/dev-run.sh
```

## Manual steps (expanded)

1) Python environment
```bash
# Recommended: use Python 3.12 or newer in dev; we support Python 3.10+.
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

Python version note: If you can't use Python 3.12 locally, consider using `pyenv` or Docker to run the project with a supported Python version; newer builds should work with updated `gevent`/`greenlet` pinned versions in `requirements.txt`.

Installing Python 3.12 (Ubuntu/Debian):
```bash
# If you have sudo
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3.12-dev build-essential libssl-dev libffi-dev
```

Using `pyenv` (no sudo):
```bash
curl https://pyenv.run | bash
# follow the printed steps to add pyenv to shell profile (restart shell or source the profile file)
pyenv install 3.10.12
pyenv local 3.10.12
```

2) Database & migrations (default uses local SQLite)
```bash
python manage.py migrate
```

3) Create a dev superuser (the project uses a custom user manager which doesn't require an email):
```bash
python manage.py shell -c "from core.models import User; User.objects.create_superuser(username='admin')"
```

4) Start the backend dev server
```bash
export IS_DEBUG=1
python manage.py runserver 0.0.0.0:8000
```

5) Frontend (optional)

Install Node.js and npm if you want to build the SPA assets:
```bash
npm install
npm run development
⚠️ Important: Avoid running `npm audit fix --force` blindly.
 - `npm audit fix --force` may upgrade major framework packages (like Vue) and break the frontend build.
 - Prefer targeted upgrades for minor/patch versions or open a migration branch for framework major upgrades.
```

The frontend bundle is generated to `core/static/core/assets/js/fastcp.js` which is referenced from templates.

## Testing

Run unit tests:
```bash
python manage.py test
```

Notes:
- Tests that perform network calls (e.g., downloading WordPress in `core.utils.system.setup_wordpress`) or run system commands may fail on CI; prefer patching or mocking `core.utils.system.run_cmd` and network requests.
- For ACME tests, set `LETSENCRYPT_IS_STAGING=1` to avoid production API hits.

## Environment variables of interest during development
- `IS_DEBUG=1` — enable debug settings
- `FASTCP_APP_SECRET` — override Django secret key
- `FASTCP_SQL_USER` and `FASTCP_SQL_PASSWORD` — set these if you want to test with MySQL instead of SQLite
- `FILE_MANAGER_ROOT` — default `/srv/users`. If you change this, ensure tests/shell operations use a temporary path.
- `LETSENCRYPT_IS_STAGING=1` — enable ACME staging endpoint

## Safety and system operations

FastCP interacts with OS-level resources (useradd, chown, setfacl, systemctl) via `core.utils.system.run_cmd`. By default, the dev scripts and tests should not execute root-level commands, but if you run tests or management commands that call `run_cmd`, they will try to execute shell commands:

- To avoid making system changes in your dev machine or CI, patch `run_cmd` for tests, e.g.,
```python
import core.utils.system as fcpsys
fcpsys.run_cmd = lambda *args, **kwargs: True
```

## Troubleshooting
- If you encounter permission errors when the app tries to create directory paths under `FILE_MANAGER_ROOT` (default `/srv/users`), set `FILE_MANAGER_ROOT` to a directory you own for local dev:
```
export FILE_MANAGER_ROOT=$PWD/tmp_files
mkdir -p $FILE_MANAGER_ROOT
```

- If the ACME code tries to make network calls that you don't want, set `LETSENCRYPT_IS_STAGING=1` or mock the `requests` library for tests.

## What to do on `npm audit` findings
- Run `npm audit` locally and inspect fix suggestions.
- If `npm audit` identifies **minor** or **patch** updates: apply them, run `npm install`, and verify `npm run development` and UI works.
- If it suggests **major** updates (e.g., `vue` v3 migration): open a `feat/migrate-vue3` branch and follow a migration plan. Do not apply the major update to master.
- For dev-only dependencies (e.g. `webpack-dev-server`) evaluate risk (not critical for production if only used in dev) and confirm mitigations: CI runs `npm audit --audit-level=high`.

## Installing GitHub Copilot CLI (optional)

The GitHub Copilot CLI requires Node.js >= 22. If you want a local copy of the CLI, install it safely:

1) Recommended: Use `nvm` (no root privileges required)
```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
# Then (restart your shell or source ~/.nvm/nvm.sh), then:
nvm install 22
nvm use 22
npm install -g @github/copilot
copilot --version
```

2) If you prefer a Docker-based approach (no global install):
```bash
docker run --rm -it node:22 bash -lc "npm install -g @github/copilot && copilot --version"
```

3) If installing globally with `npm install -g` fails because of permissions, prefer `nvm` or use `sudo` (but be careful — installing npm packages with sudo may modify system directories):
```bash
sudo npm install -g @github/copilot
```

4) If you only need to run a Copilot command once, you can try a temporary exec with `npx` after installing a local Node 22 (npx may also enforce the node engine):
```bash
npx @github/copilot --version
```

If you want me to add a `scripts/install-copilot.sh` maker to the repo, I’ve added one under `/scripts/install-copilot.sh` which checks Node version and suggests / runs installation safely.


## Optional: Using MySQL for local development
- Create a local MySQL server and set environment variables `FASTCP_SQL_USER` and `FASTCP_SQL_PASSWORD` before running migrations. Also update `fastcp/settings.py` or set `DATABASES` via environment variables if needed.

## Docker dev environment (recommended if you cannot install Python 3.10 locally)

We provide a simple Docker-based dev environment using Python 3.10 and MySQL. It builds a development container that includes build tools and Node.js so `gevent`/`greenlet` can compile.

1) Build and start containers (first run builds images):
```bash
docker compose -f docker-compose.dev.yml up -d --build
```

2) Run the Docker setup script to migrate DB and create `admin` user:
```bash
./scripts/dev-docker-setup.sh
```

3) Open the app at http://localhost:8001 (if your host port is 8001) — adjust the port if changed in `docker-compose.dev.yml`.

To stop/remove containers:
```bash
docker compose -f docker-compose.dev.yml down --volumes --remove-orphans
```

Notes:
- `docker compose -f docker-compose.dev.yml up` maps host `8001` to container `8000` by default.
- To use a different host port, edit `docker-compose.dev.yml`.

## How to test changes safely
- For unit tests that touch `filesystem` or `system` utilities, implement mocks using `unittest.mock.patch` or monkey patch `fcpsys.run_cmd` and `requests.get`.

## Further work
- Add a Docker Compose file for a fully isolated development environment including `mysqld`, `php`, and NGINX if desired.

---
If you'd like, I can also:
- Add a `docker-compose.yml` and `Dockerfile` for dev
- Add tests to patch `run_cmd` in a `tests/conftest.py`
- Add safer integration tests that use a temporary `FILE_MANAGER_ROOT` and mocked system commands
