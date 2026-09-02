-- Service-Log DB: initial schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS service_types (
    id          SMALLSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    category    VARCHAR(50),
    is_custom   BOOLEAN NOT NULL DEFAULT FALSE,
    icon_key    VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS service_logs (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id         UUID NOT NULL,
    user_id            UUID NOT NULL,
    service_type_id    SMALLINT REFERENCES service_types(id),
    custom_type_name   VARCHAR(100),
    service_date       DATE NOT NULL,
    mileage_at_service INTEGER,
    cost               NUMERIC(10,2),
    currency           VARCHAR(3) NOT NULL DEFAULT 'EUR',
    shop_name          VARCHAR(150),
    notes              TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_logs_vehicle_id ON service_logs(vehicle_id, service_date DESC);
CREATE INDEX IF NOT EXISTS idx_service_logs_user_id ON service_logs(user_id);

CREATE TABLE IF NOT EXISTS service_log_attachments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_log_id  UUID NOT NULL REFERENCES service_logs(id) ON DELETE CASCADE,
    file_key        VARCHAR(500) NOT NULL,
    file_type       VARCHAR(20) NOT NULL,
    uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attachments_service_log_id ON service_log_attachments(service_log_id);

INSERT INTO service_types (name, category, is_custom) VALUES
    ('Oil Change', 'Engine', FALSE),
    ('Oil Filter Replacement', 'Engine', FALSE),
    ('Air Filter Replacement', 'Engine', FALSE),
    ('Brake Pads', 'Brakes', FALSE),
    ('Brake Fluid Flush', 'Brakes', FALSE),
    ('Tire Rotation', 'Tires', FALSE),
    ('Tire Replacement', 'Tires', FALSE),
    ('Wheel Alignment', 'Tires', FALSE),
    ('Battery Replacement', 'Electrical', FALSE),
    ('Spark Plug Replacement', 'Engine', FALSE),
    ('Coolant Flush', 'Engine', FALSE),
    ('Transmission Fluid Change', 'Engine', FALSE),
    ('Timing Belt Replacement', 'Engine', FALSE),
    ('Annual Inspection', 'Compliance', FALSE),
    ('Registration Renewal', 'Compliance', FALSE),
    ('Insurance Renewal', 'Compliance', FALSE),
    ('Windshield Wiper Replacement', 'Other', FALSE),
    ('Cabin Air Filter', 'Other', FALSE)
ON CONFLICT (name) DO NOTHING;
