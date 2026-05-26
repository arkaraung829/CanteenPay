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
