-- 013_tighten_rls_policies.sql
-- Tighten Row Level Security policies to close identified gaps
-- Date: 2026-05-25

--------------------------------------------------------------------------------
-- 1. RESTRICT RPC FUNCTION EXECUTE PERMISSIONS
--    process_purchase: only authenticated (further restricted inside function)
--    process_deposit:  only authenticated (further restricted inside function)
--    process_refund:   only authenticated (further restricted inside function)
--    Remove EXECUTE from PUBLIC and anon to prevent unauthenticated calls.
--------------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION process_purchase(TEXT, BIGINT, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION process_purchase(TEXT, BIGINT, UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION process_deposit(UUID, BIGINT, UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION process_deposit(UUID, BIGINT, UUID, TEXT, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION process_refund(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION process_refund(UUID, UUID, TEXT) TO authenticated;

--------------------------------------------------------------------------------
-- 2. ADD CALLER VERIFICATION TO RPC FUNCTIONS
--    Prevent users from passing someone else's profile_id.
--    process_purchase: caller must be a seller
--    process_deposit:  caller must be admin or counter_staff
--    process_refund:   caller must be admin
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
    -- SECURITY: Verify caller is the seller they claim to be
    IF auth.uid() IS NULL OR auth.uid() <> p_seller_profile_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: caller must match seller_profile_id');
    END IF;

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

    -- Find the seller record (also verifies caller is actually a seller)
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
    -- SECURITY: Verify caller is the staff member they claim to be
    IF auth.uid() IS NULL OR auth.uid() <> p_staff_profile_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: caller must match staff_profile_id');
    END IF;

    -- SECURITY: Verify caller is admin or counter_staff
    IF NOT is_staff(auth.uid()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: only admin or counter_staff can process deposits');
    END IF;

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
    -- SECURITY: Verify caller is the staff member they claim to be
    IF auth.uid() IS NULL OR auth.uid() <> p_staff_profile_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: caller must match staff_profile_id');
    END IF;

    -- SECURITY: Verify caller is admin (only admins can refund)
    IF NOT is_admin(auth.uid()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: only admin can process refunds');
    END IF;

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

--------------------------------------------------------------------------------
-- 3. WALLETS: Remove admin FOR ALL, replace with SELECT-only for admin.
--    No direct INSERT/UPDATE/DELETE by anyone via RLS.
--    All mutations must go through SECURITY DEFINER functions.
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS wallets_admin_all ON wallets;

-- Admin can SELECT wallets
CREATE POLICY wallets_admin_select ON wallets
    FOR SELECT USING (is_admin(auth.uid()));

--------------------------------------------------------------------------------
-- 4. TRANSACTIONS: Remove admin FOR ALL, replace with SELECT-only.
--    Transactions are immutable -- no INSERT/UPDATE/DELETE via RLS.
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS txn_admin_all ON transactions;

-- Admin can SELECT all transactions
CREATE POLICY txn_admin_select ON transactions
    FOR SELECT USING (is_admin(auth.uid()));

--------------------------------------------------------------------------------
-- 5. STUDENTS: Add seller SELECT policy scoped to same school
--------------------------------------------------------------------------------

CREATE POLICY students_seller_select ON students
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM canteen_sellers cs
            WHERE cs.profile_id = auth.uid()
              AND cs.school_id = students.school_id
              AND cs.is_active = TRUE
        )
    );

--------------------------------------------------------------------------------
-- 6. PROFILES: Replace unrestricted UPDATE with column-safe version
--    Users must NOT be able to change their role or school_id.
--    We drop the old policy and create a new one with WITH CHECK.
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_update_own ON profiles;

-- Users can update their own profile but role and school_id must remain unchanged
CREATE POLICY profiles_update_own ON profiles
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        AND role = (SELECT p.role FROM profiles p WHERE p.id = auth.uid())
        AND school_id = (SELECT p.school_id FROM profiles p WHERE p.id = auth.uid())
    );

--------------------------------------------------------------------------------
-- 7. SELLERS can see wallets of students in their school (for purchase flow)
--------------------------------------------------------------------------------

CREATE POLICY wallets_seller_select ON wallets
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM canteen_sellers cs
            JOIN students s ON s.school_id = cs.school_id
            WHERE cs.profile_id = auth.uid()
              AND cs.is_active = TRUE
              AND s.id = wallets.student_id
        )
    );

--------------------------------------------------------------------------------
-- 8. PARENT_STUDENT_LINKS: parents can INSERT their own links
--    (for link request flow), but only with their own parent_id
--------------------------------------------------------------------------------

CREATE POLICY psl_parent_insert ON parent_student_links
    FOR INSERT WITH CHECK (parent_id = auth.uid());
