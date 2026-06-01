-- Financial Data Integrity Fixes
-- 1. Make performed_by nullable for system/admin operations
ALTER TABLE transactions ALTER COLUMN performed_by DROP NOT NULL;

-- 2. Prevent double-refund via unique index on reference_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_unique_refund
ON transactions(reference_id) WHERE type = 'refund' AND reference_id IS NOT NULL;

-- 3. Reconciliation function — compare wallet balance vs transaction sum
CREATE OR REPLACE FUNCTION reconcile_wallets()
RETURNS TABLE(
  wallet_id UUID,
  student_name TEXT,
  actual_balance BIGINT,
  expected_balance BIGINT,
  difference BIGINT
) LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT
    w.id as wallet_id,
    s.full_name as student_name,
    w.balance as actual_balance,
    COALESCE(
      (SELECT SUM(CASE
        WHEN t.type = 'purchase' THEN -t.amount
        ELSE t.amount
      END) FROM transactions t WHERE t.wallet_id = w.id),
      0
    )::BIGINT as expected_balance,
    w.balance - COALESCE(
      (SELECT SUM(CASE
        WHEN t.type = 'purchase' THEN -t.amount
        ELSE t.amount
      END) FROM transactions t WHERE t.wallet_id = w.id),
      0
    )::BIGINT as difference
  FROM wallets w
  JOIN students s ON s.id = w.student_id
  WHERE w.balance != COALESCE(
    (SELECT SUM(CASE
      WHEN t.type = 'purchase' THEN -t.amount
      ELSE t.amount
    END) FROM transactions t WHERE t.wallet_id = w.id),
    0
  );
$$;
