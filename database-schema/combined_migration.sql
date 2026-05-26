-- ============================================
-- CanteenPay Combined Database Migration
-- ============================================
-- This file combines all 12 migration files into a single script.
-- Run them in order against a Supabase/PostgreSQL database.


-- ============================================
-- 001: Create Schools Table
-- ============================================

-- 001_create_schools.sql
-- Schools table for the CanteenPay system

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE schools (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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


-- ============================================
-- 002: Create Profiles Table
-- ============================================

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


-- ============================================
-- 003: Create Students Table
-- ============================================

-- 003_create_students.sql
-- Students table with QR code data for canteen payments

CREATE TABLE students (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id           UUID REFERENCES profiles(id) ON DELETE SET NULL,
    school_id            UUID NOT NULL REFERENCES schools(id),
    student_code         TEXT NOT NULL,
    qr_data              UUID NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
    full_name            TEXT NOT NULL,
    full_name_my         TEXT,
    class_name           TEXT,
    grade                TEXT,
    enrollment_year      INT,
    photo_url            TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    daily_spending_limit BIGINT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_school_student_code UNIQUE (school_id, student_code)
);

CREATE INDEX idx_students_school_id ON students(school_id);
CREATE INDEX idx_students_profile_id ON students(profile_id);
CREATE INDEX idx_students_qr_data ON students(qr_data);

CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON students
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE students IS 'Student records with QR card data';
COMMENT ON COLUMN students.qr_data IS 'Random UUID printed on QR card (NOT the student_code, for security)';
COMMENT ON COLUMN students.daily_spending_limit IS 'Max daily spend in smallest currency unit (NULL = unlimited)';
COMMENT ON COLUMN students.profile_id IS 'Links to auth profile if student has app access (nullable)';


-- ============================================
-- 004: Create Parent-Student Links Table
-- ============================================

-- 004_create_parent_student_links.sql
-- Links parents to their children (students)

CREATE TABLE parent_student_links (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL DEFAULT 'parent',
    is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_parent_student UNIQUE (parent_id, student_id)
);

CREATE INDEX idx_parent_student_links_parent_id ON parent_student_links(parent_id);
CREATE INDEX idx_parent_student_links_student_id ON parent_student_links(student_id);

COMMENT ON TABLE parent_student_links IS 'Many-to-many relationship between parents and students';
COMMENT ON COLUMN parent_student_links.relationship IS 'e.g. parent, guardian, relative';
COMMENT ON COLUMN parent_student_links.is_primary IS 'Whether this parent is the primary contact for the student';


-- ============================================
-- 005: Create Wallets Table
-- ============================================

-- 005_create_wallets.sql
-- Student wallets holding canteen balance

CREATE TABLE wallets (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
    balance    BIGINT NOT NULL DEFAULT 0,
    currency   TEXT NOT NULL DEFAULT 'MMK',
    is_frozen  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_balance_non_negative CHECK (balance >= 0)
);

CREATE INDEX idx_wallets_student_id ON wallets(student_id);

CREATE TRIGGER trg_wallets_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-create a wallet when a student is inserted
CREATE OR REPLACE FUNCTION handle_new_student_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO wallets (student_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_student_created_wallet
    AFTER INSERT ON students
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_student_wallet();

COMMENT ON TABLE wallets IS 'Student payment wallets (one per student)';
COMMENT ON COLUMN wallets.balance IS 'Balance in smallest currency unit (e.g. kyats)';
COMMENT ON COLUMN wallets.is_frozen IS 'Frozen wallets cannot be used for purchases';


-- ============================================
-- 006: Create Canteen Sellers Table
-- ============================================

-- 006_create_canteen_sellers.sql
-- Canteen seller/stall records

CREATE TABLE canteen_sellers (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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


-- ============================================
-- 007: Create Transactions Table
-- ============================================

-- 007_create_transactions.sql
-- Transaction ledger for all wallet operations

CREATE TABLE transactions (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id      UUID NOT NULL REFERENCES wallets(id),
    type           TEXT NOT NULL CHECK (type IN ('deposit', 'purchase', 'refund', 'adjustment')),
    amount         BIGINT NOT NULL CHECK (amount > 0),
    balance_before BIGINT NOT NULL,
    balance_after  BIGINT NOT NULL,
    description    TEXT,
    reference_id   TEXT,
    performed_by   UUID NOT NULL REFERENCES profiles(id),
    seller_id      UUID REFERENCES canteen_sellers(id),
    metadata       JSONB DEFAULT '{}'::jsonb,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transactions_wallet_created
    ON transactions(wallet_id, created_at DESC);

CREATE INDEX idx_transactions_created
    ON transactions(created_at DESC);

CREATE INDEX idx_transactions_seller_created
    ON transactions(seller_id, created_at DESC);

CREATE INDEX idx_transactions_performed_by
    ON transactions(performed_by);

COMMENT ON TABLE transactions IS 'Immutable ledger of all wallet transactions';
COMMENT ON COLUMN transactions.amount IS 'Always positive; type indicates direction';
COMMENT ON COLUMN transactions.balance_before IS 'Wallet balance before this transaction';
COMMENT ON COLUMN transactions.balance_after IS 'Wallet balance after this transaction';
COMMENT ON COLUMN transactions.reference_id IS 'External reference (e.g. receipt number)';
COMMENT ON COLUMN transactions.seller_id IS 'Set only for purchase transactions';


-- ============================================
-- 008: Create Announcements Table
-- ============================================

-- 008_create_announcements.sql
-- School announcements (Phase 2 - schema created now)

CREATE TABLE announcements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id       UUID NOT NULL REFERENCES schools(id),
    author_id       UUID NOT NULL REFERENCES profiles(id),
    title           TEXT NOT NULL,
    title_my        TEXT,
    body            TEXT NOT NULL,
    body_my         TEXT,
    target_audience TEXT[] NOT NULL DEFAULT '{all}',
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    published_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_announcements_school_id ON announcements(school_id);
CREATE INDEX idx_announcements_published ON announcements(school_id, is_published, published_at DESC);

CREATE TRIGGER trg_announcements_updated_at
    BEFORE UPDATE ON announcements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE announcements IS 'School announcements (Phase 2 feature)';
COMMENT ON COLUMN announcements.target_audience IS 'Array of audience groups: all, parent, student, seller';
COMMENT ON COLUMN announcements.title_my IS 'Title in Myanmar language';
COMMENT ON COLUMN announcements.body_my IS 'Body in Myanmar language';


-- ============================================
-- 009: Create Functions
-- ============================================

-- 009_create_functions.sql
-- Core business logic functions for CanteenPay

--------------------------------------------------------------------------------
-- PROCESS PURCHASE
-- Called by canteen sellers when scanning a student QR code
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_purchase(
    p_qr_data          TEXT,
    p_amount            BIGINT,
    p_seller_profile_id UUID,
    p_description       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student       RECORD;
    v_wallet        RECORD;
    v_seller        RECORD;
    v_today_spent   BIGINT;
    v_new_balance   BIGINT;
    v_txn_id        UUID;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;

    -- Find student by QR data
    SELECT s.id, s.full_name, s.is_active, s.daily_spending_limit, s.school_id
    INTO v_student
    FROM students s
    WHERE s.qr_data = p_qr_data::uuid;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid QR code');
    END IF;

    IF NOT v_student.is_active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Student account is inactive');
    END IF;

    -- Find the seller record
    SELECT cs.id, cs.school_id
    INTO v_seller
    FROM canteen_sellers cs
    WHERE cs.profile_id = p_seller_profile_id
      AND cs.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Seller not found or inactive');
    END IF;

    -- Ensure seller and student are in the same school
    IF v_seller.school_id <> v_student.school_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Seller and student are not in the same school');
    END IF;

    -- Lock wallet for update
    SELECT w.id, w.balance, w.is_frozen
    INTO v_wallet
    FROM wallets w
    WHERE w.student_id = v_student.id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;

    -- Check frozen
    IF v_wallet.is_frozen THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet is frozen');
    END IF;

    -- Check sufficient balance
    IF v_wallet.balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    -- Check daily spending limit (if set)
    IF v_student.daily_spending_limit IS NOT NULL THEN
        SELECT COALESCE(SUM(t.amount), 0)
        INTO v_today_spent
        FROM transactions t
        WHERE t.wallet_id = v_wallet.id
          AND t.type = 'purchase'
          AND t.created_at >= date_trunc('day', now());

        IF (v_today_spent + p_amount) > v_student.daily_spending_limit THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Daily spending limit exceeded',
                'daily_limit', v_student.daily_spending_limit,
                'spent_today', v_today_spent
            );
        END IF;
    END IF;

    -- Deduct balance
    v_new_balance := v_wallet.balance - p_amount;

    UPDATE wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet.id;

    -- Insert transaction
    INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after,
                              description, performed_by, seller_id)
    VALUES (v_wallet.id, 'purchase', p_amount, v_wallet.balance, v_new_balance,
            COALESCE(p_description, 'Canteen purchase'), p_seller_profile_id, v_seller.id)
    RETURNING id INTO v_txn_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_txn_id,
        'student_name', v_student.full_name,
        'amount', p_amount,
        'new_balance', v_new_balance
    );
END;
$$;

--------------------------------------------------------------------------------
-- PROCESS DEPOSIT
-- Called by counter staff when a parent deposits cash
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_deposit(
    p_student_id      UUID,
    p_amount          BIGINT,
    p_staff_profile_id UUID,
    p_reference       TEXT DEFAULT NULL,
    p_note            TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet      RECORD;
    v_student     RECORD;
    v_new_balance BIGINT;
    v_txn_id      UUID;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;

    -- Get student name
    SELECT s.full_name
    INTO v_student
    FROM students s
    WHERE s.id = p_student_id AND s.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Student not found or inactive');
    END IF;

    -- Lock wallet for update
    SELECT w.id, w.balance
    INTO v_wallet
    FROM wallets w
    WHERE w.student_id = p_student_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;

    -- Add balance
    v_new_balance := v_wallet.balance + p_amount;

    UPDATE wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet.id;

    -- Insert transaction
    INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after,
                              description, reference_id, performed_by)
    VALUES (v_wallet.id, 'deposit', p_amount, v_wallet.balance, v_new_balance,
            COALESCE(p_note, 'Cash deposit'), p_reference, p_staff_profile_id)
    RETURNING id INTO v_txn_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_txn_id,
        'student_name', v_student.full_name,
        'amount', p_amount,
        'new_balance', v_new_balance
    );
END;
$$;

--------------------------------------------------------------------------------
-- PROCESS REFUND
-- Called by admin/staff to reverse a purchase transaction
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_refund(
    p_transaction_id   UUID,
    p_staff_profile_id UUID,
    p_reason           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_original    RECORD;
    v_wallet      RECORD;
    v_new_balance BIGINT;
    v_txn_id      UUID;
    v_student     RECORD;
BEGIN
    -- Find the original transaction
    SELECT t.id, t.wallet_id, t.type, t.amount, t.metadata
    INTO v_original
    FROM transactions t
    WHERE t.id = p_transaction_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
    END IF;

    -- Must be a purchase
    IF v_original.type <> 'purchase' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only purchase transactions can be refunded');
    END IF;

    -- Check if already refunded
    IF EXISTS (
        SELECT 1 FROM transactions t
        WHERE t.type = 'refund'
          AND t.reference_id = p_transaction_id::text
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction has already been refunded');
    END IF;

    -- Lock wallet for update
    SELECT w.id, w.balance, w.student_id
    INTO v_wallet
    FROM wallets w
    WHERE w.id = v_original.wallet_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;

    -- Get student name
    SELECT s.full_name
    INTO v_student
    FROM students s
    WHERE s.id = v_wallet.student_id;

    -- Add refund amount back
    v_new_balance := v_wallet.balance + v_original.amount;

    UPDATE wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet.id;

    -- Insert refund transaction
    INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after,
                              description, reference_id, performed_by)
    VALUES (v_wallet.id, 'refund', v_original.amount, v_wallet.balance, v_new_balance,
            COALESCE(p_reason, 'Purchase refund'), p_transaction_id::text, p_staff_profile_id)
    RETURNING id INTO v_txn_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_txn_id,
        'student_name', v_student.full_name,
        'amount', v_original.amount,
        'new_balance', v_new_balance
    );
END;
$$;

COMMENT ON FUNCTION process_purchase IS 'Deduct balance from student wallet for a canteen purchase';
COMMENT ON FUNCTION process_deposit IS 'Add funds to a student wallet (cash deposit by counter staff)';
COMMENT ON FUNCTION process_refund IS 'Reverse a purchase transaction and restore the balance';


-- ============================================
-- 010: Create RLS Policies
-- ============================================

-- 010_create_rls_policies.sql
-- Row Level Security policies for all tables

--------------------------------------------------------------------------------
-- Enable RLS on all tables
--------------------------------------------------------------------------------
ALTER TABLE schools              ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE students             ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_student_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE canteen_sellers      ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements        ENABLE ROW LEVEL SECURITY;

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = p_user_id
          AND role IN ('admin')
          AND is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION is_staff(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = p_user_id
          AND role IN ('admin', 'counter_staff')
          AND is_active = TRUE
    );
$$;

--------------------------------------------------------------------------------
-- SCHOOLS policies
--------------------------------------------------------------------------------
-- Anyone can read active schools
CREATE POLICY schools_select_active ON schools
    FOR SELECT USING (is_active = TRUE);

-- Admin full access
CREATE POLICY schools_admin_all ON schools
    FOR ALL USING (is_admin(auth.uid()));

--------------------------------------------------------------------------------
-- PROFILES policies
--------------------------------------------------------------------------------
-- Users can read their own profile
CREATE POLICY profiles_select_own ON profiles
    FOR SELECT USING (id = auth.uid());

-- Users can update their own profile
CREATE POLICY profiles_update_own ON profiles
    FOR UPDATE USING (id = auth.uid());

-- Admin full access
CREATE POLICY profiles_admin_all ON profiles
    FOR ALL USING (is_admin(auth.uid()));

--------------------------------------------------------------------------------
-- STUDENTS policies
--------------------------------------------------------------------------------
-- Admin and counter_staff full access
CREATE POLICY students_staff_all ON students
    FOR ALL USING (is_staff(auth.uid()));

-- Parents can read their linked students
CREATE POLICY students_parent_select ON students
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM parent_student_links psl
            WHERE psl.student_id = students.id
              AND psl.parent_id = auth.uid()
        )
    );

-- Students can read their own record
CREATE POLICY students_self_select ON students
    FOR SELECT USING (profile_id = auth.uid());

--------------------------------------------------------------------------------
-- PARENT_STUDENT_LINKS policies
--------------------------------------------------------------------------------
-- Parents can read their own links
CREATE POLICY psl_parent_select ON parent_student_links
    FOR SELECT USING (parent_id = auth.uid());

-- Admin full access
CREATE POLICY psl_admin_all ON parent_student_links
    FOR ALL USING (is_admin(auth.uid()));

-- Counter staff can manage links
CREATE POLICY psl_staff_all ON parent_student_links
    FOR ALL USING (is_staff(auth.uid()));

--------------------------------------------------------------------------------
-- WALLETS policies
--------------------------------------------------------------------------------
-- Parents can read wallets of linked students
CREATE POLICY wallets_parent_select ON wallets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM parent_student_links psl
            WHERE psl.student_id = wallets.student_id
              AND psl.parent_id = auth.uid()
        )
    );

-- Students can read their own wallet
CREATE POLICY wallets_student_select ON wallets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM students s
            WHERE s.id = wallets.student_id
              AND s.profile_id = auth.uid()
        )
    );

-- Admin full access
CREATE POLICY wallets_admin_all ON wallets
    FOR ALL USING (is_admin(auth.uid()));

-- Counter staff can read/update wallets (for deposits)
CREATE POLICY wallets_staff_select ON wallets
    FOR SELECT USING (is_staff(auth.uid()));

--------------------------------------------------------------------------------
-- TRANSACTIONS policies
--------------------------------------------------------------------------------
-- Parents can read transactions of linked students' wallets
CREATE POLICY txn_parent_select ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM wallets w
            JOIN parent_student_links psl ON psl.student_id = w.student_id
            WHERE w.id = transactions.wallet_id
              AND psl.parent_id = auth.uid()
        )
    );

-- Students can read their own transactions
CREATE POLICY txn_student_select ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM wallets w
            JOIN students s ON s.id = w.student_id
            WHERE w.id = transactions.wallet_id
              AND s.profile_id = auth.uid()
        )
    );

-- Sellers can read transactions they performed
CREATE POLICY txn_seller_select ON transactions
    FOR SELECT USING (performed_by = auth.uid());

-- Admin full access
CREATE POLICY txn_admin_all ON transactions
    FOR ALL USING (is_admin(auth.uid()));

-- Counter staff can read all transactions
CREATE POLICY txn_staff_select ON transactions
    FOR SELECT USING (is_staff(auth.uid()));

--------------------------------------------------------------------------------
-- CANTEEN_SELLERS policies
--------------------------------------------------------------------------------
-- Sellers can read their own record
CREATE POLICY sellers_own_select ON canteen_sellers
    FOR SELECT USING (profile_id = auth.uid());

-- Admin full access
CREATE POLICY sellers_admin_all ON canteen_sellers
    FOR ALL USING (is_admin(auth.uid()));

--------------------------------------------------------------------------------
-- ANNOUNCEMENTS policies
--------------------------------------------------------------------------------
-- Published announcements readable by school members
CREATE POLICY announcements_published_select ON announcements
    FOR SELECT USING (
        is_published = TRUE
        AND (expires_at IS NULL OR expires_at > now())
        AND EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
              AND p.school_id = announcements.school_id
        )
    );

-- Admin full access
CREATE POLICY announcements_admin_all ON announcements
    FOR ALL USING (is_admin(auth.uid()));


-- ============================================
-- 011: Enable Realtime
-- ============================================

-- 011_enable_realtime.sql
-- Enable Supabase Realtime on key tables for live updates

-- Parents and students see wallet balance changes in real-time
ALTER PUBLICATION supabase_realtime ADD TABLE wallets;

-- Parents see new transactions appear in real-time
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;


-- ============================================
-- 012: Seed Data
-- ============================================

-- 012_seed_data.sql
-- Seed data for development and testing
-- NOTE: This file uses fixed UUIDs for reproducibility in dev environments.
--       Do NOT run this in production.

--------------------------------------------------------------------------------
-- 1. Test school
--------------------------------------------------------------------------------
INSERT INTO schools (id, name, name_my, code, address, phone)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Springfield International School',
    E'\u1005\u1015\u101b\u1004\u1039\u1038\u1016\u102e\u1038\u101c\u1039',
    'SPRING-001',
    '123 Main Street, Yangon',
    '+95-1-234567'
);

--------------------------------------------------------------------------------
-- 2. Admin user profile (manually inserted; in production, auth.users triggers this)
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, full_name_my, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'admin',
    'a0000000-0000-0000-0000-000000000001',
    'Admin User',
    E'\u1021\u1000\u103a\u1019\u1004\u1039',
    '+95-9-111111111'
);

--------------------------------------------------------------------------------
-- 3. Counter staff profile
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'counter_staff',
    'a0000000-0000-0000-0000-000000000001',
    'Counter Staff One',
    '+95-9-222222222'
);

--------------------------------------------------------------------------------
-- 4. Three sample students (wallets auto-created by trigger)
--------------------------------------------------------------------------------
INSERT INTO students (id, school_id, student_code, full_name, full_name_my, class_name, grade, enrollment_year)
VALUES
    ('c0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-001', 'Aung Aung', E'\u1021\u1031\u102c\u1004\u1039\u1021\u1031\u102c\u1004\u1039', 'Class A', 'Grade 5', 2025),

    ('c0000000-0000-0000-0000-000000000002',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-002', 'Mya Mya', E'\u1019\u103b\u102c\u1019\u103b\u102c', 'Class A', 'Grade 5', 2025),

    ('c0000000-0000-0000-0000-000000000003',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-003', 'Zaw Zaw', E'\u1007\u1031\u102c\u1039\u1007\u1031\u102c\u1039', 'Class B', 'Grade 3', 2025);

-- Set initial balances (10000 kyats each)
UPDATE wallets SET balance = 10000
WHERE student_id IN (
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000003'
);

--------------------------------------------------------------------------------
-- 5. Sample canteen seller
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'seller',
    'a0000000-0000-0000-0000-000000000001',
    'Daw Khin',
    '+95-9-333333333'
);

INSERT INTO canteen_sellers (id, profile_id, school_id, stall_name, stall_name_my, stall_number)
VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Daw Khin Snacks',
    E'\u1012\u1031\u102b\u1039\u1001\u1004\u1039\u1019\u102f\u1014\u1039\u1038',
    'A-1'
);

--------------------------------------------------------------------------------
-- 6. Sample parent with links to 2 students
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'parent',
    'a0000000-0000-0000-0000-000000000001',
    'U Kyaw',
    '+95-9-444444444'
);

INSERT INTO parent_student_links (parent_id, student_id, relationship, is_primary)
VALUES
    ('b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'parent', TRUE),
    ('b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'parent', TRUE);
