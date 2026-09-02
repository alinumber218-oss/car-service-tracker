-- Vehicle DB: initial schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS vehicles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    nickname        VARCHAR(100),
    make            VARCHAR(50) NOT NULL,
    model           VARCHAR(50) NOT NULL,
    year            SMALLINT NOT NULL,
    vin             VARCHAR(17),
    license_plate   VARCHAR(20),
    color           VARCHAR(30),
    photo_url       VARCHAR(500),
    current_mileage INTEGER NOT NULL DEFAULT 0,
    mileage_unit    VARCHAR(3) NOT NULL DEFAULT 'km',
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles(user_id);

CREATE TABLE IF NOT EXISTS mileage_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id  UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    mileage     INTEGER NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source      VARCHAR(20) NOT NULL DEFAULT 'manual'
);

CREATE INDEX IF NOT EXISTS idx_mileage_history_vehicle_id ON mileage_history(vehicle_id, recorded_at DESC);
