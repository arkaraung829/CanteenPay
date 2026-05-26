-- 002_create_profiles.sql
-- User profiles extending Supabase auth.users

CREATE TABLE profiles (
    id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role         TEXT NOT NULL CHECK (role IN ('student', 'parent', 'seller', 'admin', 'counter_staff')),
    school_id    UUID REFERENCES schools(id),
    full_name    TEXT NOT NULL,
    full_name_my TEXT,
    phone        TEXT,
    avatar_url   TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    fcm_token    TEXT,
    locale       TEXT DEFAULT 'en',
    metadata     JSONB DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_school_id ON profiles(school_id);
CREATE INDEX idx_profiles_role ON profiles(role);

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-create a profile row when a new auth user is inserted.
-- The raw_user_meta_data from Supabase sign-up must include: role, full_name, school_id.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, role, school_id, full_name, full_name_my, phone, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'role', 'parent'),
        (NEW.raw_user_meta_data ->> 'school_id')::uuid,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        NEW.raw_user_meta_data ->> 'full_name_my',
        NEW.raw_user_meta_data ->> 'phone',
        NEW.raw_user_meta_data ->> 'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

COMMENT ON TABLE profiles IS 'Extended user profiles linked to Supabase auth.users';
COMMENT ON COLUMN profiles.role IS 'User role: student, parent, seller, admin, or counter_staff';
COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
COMMENT ON COLUMN profiles.locale IS 'Preferred language locale (en or my)';
