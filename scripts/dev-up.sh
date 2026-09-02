#!/bin/bash
# Starts every service (infra + app) via docker-compose and waits for
# Postgres to be healthy before continuing. Run this from the project root:
#   ./scripts/dev-up.sh
set -e

cd "$(dirname "$0")/.."

echo "Starting infrastructure and services with docker-compose..."
docker compose up -d --build

echo "Waiting for Postgres to become healthy..."
until docker compose exec -T postgres pg_isready -U app_user > /dev/null 2>&1; do
  sleep 2
done

echo ""
echo "All containers are up. Endpoints:"
echo "  API Gateway:        http://localhost:8080"
echo "  Auth Service:       http://localhost:4001"
echo "  Core Service:       http://localhost:4002"
echo "  RabbitMQ mgmt UI:   http://localhost:15672  (guest/guest)"
echo "  MinIO console:      http://localhost:9001   (minioadmin/minioadmin)"
echo ""
echo "Next: run ./scripts/migrate.sh to create tables in each service database."
