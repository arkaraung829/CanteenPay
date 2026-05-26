-- 006_create_canteen_sellers.sql
-- Canteen seller/stall records

CREATE TABLE canteen_sellers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id    UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    school_id     UUID NOT NULL REFERENCES schools(id),
    stall_name    TEXT NOT NULL,
    stall_name_my TEXT,
    stall_number  TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_canteen_sellers_school_id ON canteen_sellers(school_id);
CREATE INDEX idx_canteen_sellers_profile_id ON canteen_sellers(profile_id);

CREATE TRIGGER trg_canteen_sellers_updated_at
    BEFORE UPDATE ON canteen_sellers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE canteen_sellers IS 'Canteen stall operators who accept QR payments';
COMMENT ON COLUMN canteen_sellers.stall_name_my IS 'Stall name in Myanmar language';
