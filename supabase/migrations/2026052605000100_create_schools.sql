-- 001_create_schools.sql
-- Schools table for the CanteenPay system

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE schools (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    name_my    TEXT,
    code       TEXT NOT NULL UNIQUE,
    address    TEXT,
    phone      TEXT,
    logo_url   TEXT,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    settings   JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_schools_updated_at
    BEFORE UPDATE ON schools
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE schools IS 'Registered schools using CanteenPay';
COMMENT ON COLUMN schools.name_my IS 'School name in Myanmar language';
COMMENT ON COLUMN schools.code IS 'Unique school identifier code';
COMMENT ON COLUMN schools.settings IS 'School-specific configuration (JSON)';
