-- Migration 021: Enforce daily spending limit in process_purchase
--
-- The students.daily_spending_limit column already exists (BIGINT, nullable).
-- This migration updates process_purchase to check today's total spending
-- against the limit before allowing a purchase.
-- NULL daily_spending_limit means unlimited spending.

CREATE OR REPLACE FUNCTION public.process_purchase(
  p_qr_data text,
  p_amount bigint,
  p_seller_profile_id uuid,
  p_description text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_student RECORD;
  v_wallet RECORD;
  v_seller RECORD;
  v_today_spent BIGINT;
  v_new_balance BIGINT;
  v_txn_id UUID;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL OR auth.uid() <> p_seller_profile_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: caller must match seller_profile_id');
  END IF;

  -- Amount validation
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  -- Look up student by QR data
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

  -- Look up seller
  SELECT cs.id, cs.school_id
    INTO v_seller
    FROM canteen_sellers cs
   WHERE cs.profile_id = p_seller_profile_id
     AND cs.is_active = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seller not found or inactive');
  END IF;

  -- School match check
  IF v_seller.school_id <> v_student.school_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seller and student are not in the same school');
  END IF;

  -- Lock wallet row for atomic update
  SELECT w.id, w.balance, w.is_frozen
    INTO v_wallet
    FROM wallets w
   WHERE w.student_id = v_student.id
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF v_wallet.is_frozen THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet is frozen');
  END IF;

  -- Balance check
  IF v_wallet.balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Daily spending limit check
  IF v_student.daily_spending_limit IS NOT NULL THEN
    SELECT COALESCE(SUM(t.amount), 0)
      INTO v_today_spent
      FROM transactions t
     WHERE t.wallet_id = v_wallet.id
       AND t.type = 'purchase'
       AND t.created_at >= CURRENT_DATE;

    IF (v_today_spent + p_amount) > v_student.daily_spending_limit THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Daily spending limit exceeded. Limit: ' || v_student.daily_spending_limit || ' MMK, spent today: ' || v_today_spent || ' MMK',
        'daily_limit', v_student.daily_spending_limit,
        'spent_today', v_today_spent
      );
    END IF;
  END IF;

  -- Deduct balance
  v_new_balance := v_wallet.balance - p_amount;

  UPDATE wallets
     SET balance = v_new_balance,
         updated_at = now()
   WHERE id = v_wallet.id;

  -- Record transaction
  INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after, description, performed_by, seller_id)
  VALUES (v_wallet.id, 'purchase', p_amount, v_wallet.balance, v_new_balance, COALESCE(p_description, 'Canteen purchase'), p_seller_profile_id, v_seller.id)
  RETURNING id INTO v_txn_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_txn_id,
    'student_name', v_student.full_name,
    'amount', p_amount,
    'new_balance', v_new_balance
  );
END;
$function$;
