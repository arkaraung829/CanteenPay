-- 022_admin_process_refund.sql
-- Admin refund function that does NOT require auth.uid()
-- Used by the Next.js admin dashboard via service_role key

CREATE OR REPLACE FUNCTION admin_process_refund(
    p_transaction_id UUID,
    p_reason         TEXT DEFAULT 'Admin refund'
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
    -- Get original transaction
    SELECT t.id, t.wallet_id, t.type, t.amount
    INTO v_original
    FROM transactions t
    WHERE t.id = p_transaction_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
    END IF;

    IF v_original.type <> 'purchase' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only purchase transactions can be refunded');
    END IF;

    -- Check if already refunded
    IF EXISTS (
        SELECT 1 FROM transactions t
        WHERE t.type = 'refund' AND t.reference_id = p_transaction_id::text
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction has already been refunded');
    END IF;

    -- Lock wallet
    SELECT w.id, w.balance, w.student_id
    INTO v_wallet
    FROM wallets w
    WHERE w.id = v_original.wallet_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;

    SELECT s.full_name INTO v_student
    FROM students s WHERE s.id = v_wallet.student_id;

    v_new_balance := v_wallet.balance + v_original.amount;

    -- Update wallet
    UPDATE wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet.id;

    -- Insert refund transaction
    INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after,
                              description, reference_id, performed_by)
    VALUES (v_wallet.id, 'refund', v_original.amount, v_wallet.balance, v_new_balance,
            COALESCE(p_reason, 'Admin refund'), p_transaction_id::text, NULL)
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

COMMENT ON FUNCTION admin_process_refund IS 'Atomic refund for admin dashboard — no auth.uid() required';
