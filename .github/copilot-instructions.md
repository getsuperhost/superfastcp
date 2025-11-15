# GitHub Copilot Instructions — FastCP

This file gives quick, actionable guidance for AI coding agents working in the FastCP repo. Focus on doing small, testable changes, and prefer modifications that keep the system safe (avoid running system-level commands during tests).

## High-level architecture
- Backend: Django 3.2 app (project root: `fastcp/`) with apps under `api/` and `core/`.
- Frontend: Vue 2 SPA in `resources/js/` built with Laravel Mix (`webpack.mix.js`) and compiled into `core/static/core/assets/js`.
- System & service layer: `core.utils.system` and `core.utils.filesystem` execute OS-level operations (useradd, setfacl, chown, systemctl restarts). These require root or mocked calls during tests.
- DB and services: Defaults to SQLite for local dev (`fastcp/settings.py`) but MySQL integration exists in `api/databases/services/mysql.py`. Environment variables `FASTCP_SQL_USER` and `FASTCP_SQL_PASSWORD` control production MySQL connection.
- ACME/SSL: ACME client lives under `api/websites/services/fcp_acme.py` and `api/websites/services/ssl.py` implements domain validation + certificate lifecycle. Use `LETSENCRYPT_IS_STAGING` toggle in `settings.py` to avoid production ACME hits.
- Event-driven side effects: Signals handle post-save and pre-delete actions (`core/signals.py`). Do not hard-code system side effects: use signals and service classes.

## Key files and directories (quick reference)
- `core/models.py` — Custom `User`, `Website`, `Domain`, and `Database` models; `User` uses a custom manager that does not rely on emails.
- `core/signals.py` and `core/utils/*` — logic for creating/removing website directories, generating vhost configs, registering PHP-FPM pools and restarting services.
- `core/management/commands` — custom Django commands (e.g., `activate-ssl`).
- `api/` — REST endpoints (subapps: `websites`, `users`, `databases`, `filemanager`), each may use service-layer classes under `api/*/services`.
- `resources/js/` — Vue SPA entry (`fastcp.js`), routes (`routes.js`), and components.
- `templates/` — Django templates (master file references `FASTCP_FM_ROOT` and `PMA_URL` context variables).

## Development environment & common commands
1. Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Database & migrations (default is SQLite)
```bash
python manage.py migrate
python manage.py createsuperuser  # call with username only if manager requires it
```

3. Run backend server
```bash
# enable debug for local dev
export IS_DEBUG=1
python manage.py runserver 0.0.0.0:8000
```

4. Frontend build / development server
```bash
npm install
npm run development     # build once
# or
npm run watch           # dev watch
npm run production      # production build
```

⚠️ Important: Avoid running `npm audit fix --force` blindly.
 - This repository currently uses Vue 2 + Laravel Mix; `npm audit fix --force` often upgrades major frameworks like Vue and Vuex to incompatible major versions and will break the frontend build.
 - If you need to remediate vulnerabilities, prefer targeted dependency updates for minor/patch releases, or open a migration branch and plan a proper Vue 3 upgrade if you want to move to Vue 3 and vue-router v4.

5. Tests
```bash
python manage.py test
```
## Copilot CLI (optional)
- If you want to use the GitHub Copilot CLI locally, prefer installing it via `nvm` with Node >= 22 or use the Docker approach in `DEVELOPMENT.md` to avoid system permission issues. Avoid installing global npm tools with `sudo` in CI or container image builds.
Note: Some tests perform network calls (e.g., WordPress download) or OS commands; prefer mocking or run in a disposable environment.

Docker-based dev environment:
 - If your local Python version is >3.10 or you don't want to install system deps, use the `Dockerfile.dev` and `docker-compose.dev.yml` files. Start with `docker compose -f docker-compose.dev.yml up -d --build` and run `./scripts/dev-docker-setup.sh` to run migrations and create a default admin user.

Special notes:
- `core/models.User` overrides `create_superuser` to not require email. Use `python manage.py createsuperuser` or programmatically create one:
```
python manage.py shell
from core.models import User
User.objects.create_superuser(username='admin')
```
- When working on features that write to system paths or call `run_cmd`, use patching in tests:
```
import core.utils.system as fcpsys
fcpsys.run_cmd = lambda cmd, shell=False: True
```

## Environment variables of interest
- `IS_DEBUG` — toggle Django DEBUG mode
- `FASTCP_APP_SECRET` — secret key override
- `FASTCP_SQL_USER` `FASTCP_SQL_PASSWORD` — MySQL connection for `FastcpSqlService`
- `FILE_MANAGER_ROOT` — local path used for `create_user_dirs` and `get_user_paths` (default `/srv/users`)
- `PHP_INSTALL_PATH`, `NGINX_BASE_DIR`, `APACHE_VHOST_ROOT` — filesystem paths used for FPM and vhost creation
- `LETSENCRYPT_IS_STAGING` — enables Let’s Encrypt staging endpoint for testing

Python versions: The project supports Python 3.10 and newer (3.11/3.12). To use Python 3.12 locally, ensure you update `requirements.txt` for `gevent`/`greenlet` versions that support Python 3.12 (this repo has been updated to use more recent versions). If you prefer, use the Docker dev environment which uses Python 3.12.

## Common patterns & conventions AI agents should follow
- Services: Place business logic in service classes in `api/*/services` or in `core/utils`. Avoid side-effects in views. Example: Use `FastcpSqlService.setup_db(...)` to create DB, instead of raw SQL in views.
- Signals: Side effects like filesystem changes, service reloads, and user creation are implemented using Django signals in `core/signals.py`. Connect or call signals instead of duplicating logic.
- File & path helpers: Use `core.utils.filesystem.get_user_paths()` and `get_website_paths()` to compute filesystem paths. Do not hardcode path strings; these functions centralize path calculations.
- System commands: All system-level operations (user creation, chown, setfacl, systemctl) call `core.utils.system.run_cmd`. For tests and safe development, patch `run_cmd` to avoid running commands or use a local Docker/VM environment.
- ACME flow: Use `FastcpAcme` to request and finalize certs. `FastcpSsl.get_ssl(website)` handles verifying domains, token writing, and final certificate creation; it reads/writes to `/var/fastcp` by default.
- DB password rotation: Use `core.utils.system.change_db_password` to update DB passwords via `FastcpSqlService.update_password`.
- Hard crashes: Many system-level functions swallow exceptions. When adding new logic, preserve defensive design and additional logging if necessary.

## Why this structure?
- FastCP modifies system-level resources (users, vhosts, SSLs, DB users) and therefore puts all OS-facing logic in `core.utils.system` so it can be centralized, audited, and tested via single adapters.
- `core.signals` centralizes side-effects: when models change the signals ensure FS templates are regenerated and services are restarted, which follows an event-driven pattern and avoids duplication.

## Areas to pay attention to
- Templates used to generate system configs: `templates/system/*` (nginx-vhost-*.txt, php-fpm-pool.txt, apache-vhost.txt). Use `core.utils.filesystem.get_website_paths()` for path formation and `render_to_string()` to produce these files.
- API base path is `/api/` — frontend uses `window.axios.defaults.baseURL = '/api/';` in `resources/js/fastcp.js`.
- Avoid committing secrets or environment values: `FASTCP_APP_SECRET`, `FASTCP_SQL_PASSWORD`, `FASTCP_SQL_USER`.

## Test & debugging guidance
- Tests may require privileged operations: For unit tests, stub or patch `core.utils.system.run_cmd`, network requests (`requests.get`) and file system operations that write to system paths.
- Example mocking patterns used in tests: Replace or monkeypatch `fcpsys.run_cmd` with a no-op or return True to avoid running system commands while still exercising signal flows.
- When adding tests that invoke ACME, use `LETSENCRYPT_IS_STAGING=1` and mock HTTP endpoints.

## How to change or extend APIs & UI
- Backend: Add serializers/views to `api/<model>/` and register routes in `api/<model>/urls.py`. Respect existing error/response structure (DRF views/serializers in repo).
- Frontend: Add Vue components under `resources/js/components/<app>`, register route in `resources/js/routes.js`, use Vuex store (in `resources/js/store.js`) where appropriate, and use `axios` for `/api/` requests (base set in `fastcp.js`).
- Assets: Update `resources/js` and run `npm run development` to build into `core/static/core/assets/js`.

## Production notes & safety checks
- Avoid running any code that executes OS-level commands or modifies `/etc/*` paths during PR review or automated tests. If a change needs to exercise these flows, implement a mockable adapter (e.g., `system.run_cmd`) or isolate side effects into a small adapter class.
- When working on SSL or ACME code paths, use `LETSENCRYPT_IS_STAGING` and mock remote network calls.

## Example small tasks for AI agents (explicit steps)
1. Add API endpoint for listing website metadata:
   - Add serializer in `api/websites/serializers.py`.
   - Add list/detail view in `api/websites/views.py`.
   - Register route in `api/websites/urls.py`.
   - Add UI component `resources/js/components/websites/MetadataComponent` and a route entry in `routes.js`.
   - Add test cases that avoid system changes (mock filesystem and network).

2. Replace raw `run_cmd` string invocations with a helper in `core/utils/system.py` (for better testability):
   - Add wrapper method in `core/utils/system.py` (exists as `run_cmd`) and update call-sites; add tests that patch the wrapper.

3. Improve `FileManager` file listing to paginate using `api/pagination.py`.

---
If anything in this document is unclear or incomplete, please reply with what you want expanded (examples, a deeper architecture diagram, or specific areas like tests/CI). Please note sensitive operations (system calls) and whether you want mock-safe units to be added for CI or not.
