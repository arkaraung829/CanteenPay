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
-- The raw_user_meta_data from Supabase sign-up should include: role, full_name.
-- school_id is optional — defaults to the first active school.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_school_id UUID;
BEGIN
    -- Try to parse school_id from metadata, default to first school if not provided
    BEGIN
        v_school_id := (NEW.raw_user_meta_data ->> 'school_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    IF v_school_id IS NULL THEN
        SELECT id INTO v_school_id FROM public.schools WHERE is_active = true LIMIT 1;
    END IF;

    INSERT INTO public.profiles (id, role, school_id, full_name, full_name_my, phone, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'role', 'parent'),
        v_school_id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', COALESCE(NEW.email, 'User')),
        NEW.raw_user_meta_data ->> 'full_name_my',
        NEW.raw_user_meta_data ->> 'phone',
        NEW.raw_user_meta_data ->> 'avatar_url'
    );
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'handle_new_user failed for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

COMMENT ON TABLE profiles IS 'Extended user profiles linked to Supabase auth.users';
COMMENT ON COLUMN profiles.role IS 'User role: student, parent, seller, admin, or counter_staff';
COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
COMMENT ON COLUMN profiles.locale IS 'Preferred language locale (en or my)';
