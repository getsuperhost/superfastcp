#!/usr/bin/env bash
set -e

# Bring up Dev containers and run initial migrations while creating a dev superuser
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# Build and start the containers
docker compose -f docker-compose.dev.yml up -d --build

# Wait for the db to be healthy
echo "Waiting for MySQL to initialize..."
for i in {1..30}; do
  docker compose -f docker-compose.dev.yml exec -T db mysqladmin ping -uroot -prootpw >/dev/null 2>&1 && break || sleep 2
done

# Run migrations & create superuser
# Use docker compose exec to run commands inside the app container
cat <<'PY' > /tmp/dev_create_superuser.py
from core.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(username='admin')
    print('Created admin user')
else:
    print('Admin user exists')
PY

# Run migrate and create superuser
docker compose -f docker-compose.dev.yml exec -T app sh -c "pip install -r requirements.txt && python manage.py migrate --noinput"
docker compose -f docker-compose.dev.yml exec -T app sh -c "python3 /tmp/dev_create_superuser.py"

# Clean up temp file
docker compose -f docker-compose.dev.yml exec -T app sh -c "rm -f /tmp/dev_create_superuser.py || true"
rm -f /tmp/dev_create_superuser.py

cat <<EOF

Dev Docker setup complete.

Start the containers (if not already running):
  docker compose -f docker-compose.dev.yml up

Access the app at: http://localhost:8000
DB: mysql://fastcp:fastcppw@localhost:3306/fastcp

To stop containers:
  docker compose -f docker-compose.dev.yml down

EOF
