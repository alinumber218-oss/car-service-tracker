#!/bin/bash
# Stops and removes all containers started by dev-up.sh. Data volumes are
# preserved (use `docker compose down -v` manually to wipe them).
set -e

cd "$(dirname "$0")/.."
docker compose down
echo "All containers stopped. Data volumes preserved (postgres-data, rabbitmq-data, minio-data)."
