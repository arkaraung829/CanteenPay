-- 019_admin_process_deposit.sql
-- Admin deposit function that does NOT require auth.uid()
-- Used by the Next.js admin dashboard via service_role key

CREATE OR REPLACE FUNCTION admin_process_deposit(
    p_student_id   UUID,
    p_amount       BIGINT,
    p_note         TEXT DEFAULT 'Admin deposit'
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

    -- Calculate new balance
    v_new_balance := v_wallet.balance + p_amount;

    -- Update wallet
    UPDATE wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet.id;

    -- Insert transaction
    INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after,
                              description, performed_by)
    VALUES (v_wallet.id, 'deposit', p_amount, v_wallet.balance, v_new_balance,
            COALESCE(p_note, 'Admin deposit'), NULL)
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

COMMENT ON FUNCTION admin_process_deposit IS 'Atomic deposit for admin dashboard — no auth.uid() required, SECURITY DEFINER';
