#!/bin/bash
# Runs automatically on first container start (mounted into
# /docker-entrypoint-initdb.d/). Creates one database per service, matching
# the "database-per-service" pattern used across the microservices.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE auth;
    CREATE DATABASE vehicle;
    CREATE DATABASE servicelog;
    CREATE DATABASE reminder;
    CREATE DATABASE notification;

    GRANT ALL PRIVILEGES ON DATABASE auth TO app_user;
    GRANT ALL PRIVILEGES ON DATABASE vehicle TO app_user;
    GRANT ALL PRIVILEGES ON DATABASE servicelog TO app_user;
    GRANT ALL PRIVILEGES ON DATABASE reminder TO app_user;
    GRANT ALL PRIVILEGES ON DATABASE notification TO app_user;
EOSQL
