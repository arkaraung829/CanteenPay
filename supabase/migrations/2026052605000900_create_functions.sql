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
