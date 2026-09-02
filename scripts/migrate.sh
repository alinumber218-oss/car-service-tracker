#!/bin/bash
# Runs each service's migration script against its own database(s), using the
# already-compiled dist/db/migrate.js (production images don't ship tsx/dev
# dependencies). Run this after dev-up.sh, and again any time you add a new
# .sql file under a service's migrations folder.
set -e

cd "$(dirname "$0")/.."

echo "Running Auth Service migrations..."
docker compose exec -T auth-service node dist/db/migrate.js

echo "Running Core Service migrations (vehicle + servicelog databases)..."
docker compose exec -T core-service node dist/db/migrate.js

echo "Migrations complete."
