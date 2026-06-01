-- Seller Payouts table
CREATE TABLE IF NOT EXISTS seller_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES canteen_sellers(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','completed')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_seller_payouts_seller ON seller_payouts(seller_id);
CREATE INDEX IF NOT EXISTS idx_seller_payouts_status ON seller_payouts(status);

ALTER TABLE seller_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS seller_payouts_seller_select ON seller_payouts;
CREATE POLICY seller_payouts_seller_select ON seller_payouts FOR SELECT USING (
  EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = seller_id AND cs.profile_id = auth.uid())
);

DROP POLICY IF EXISTS seller_payouts_seller_insert ON seller_payouts;
CREATE POLICY seller_payouts_seller_insert ON seller_payouts FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = seller_id AND cs.profile_id = auth.uid())
);

DROP POLICY IF EXISTS seller_payouts_staff_all ON seller_payouts;
CREATE POLICY seller_payouts_staff_all ON seller_payouts FOR ALL USING (is_staff(auth.uid()));

-- Get seller balance RPC
CREATE OR REPLACE FUNCTION get_seller_balance(p_seller_id UUID)
RETURNS JSONB LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT jsonb_build_object(
    'total_sales', COALESCE((
      SELECT SUM(t.amount) FROM transactions t WHERE t.seller_id = p_seller_id AND t.type = 'purchase'
    ), 0),
    'total_refunds', COALESCE((
      SELECT SUM(t.amount) FROM transactions t WHERE t.seller_id = p_seller_id AND t.type = 'refund'
    ), 0),
    'completed_payouts', COALESCE((
      SELECT SUM(sp.amount) FROM seller_payouts sp WHERE sp.seller_id = p_seller_id AND sp.status = 'completed'
    ), 0),
    'pending_payouts', COALESCE((
      SELECT SUM(sp.amount) FROM seller_payouts sp WHERE sp.seller_id = p_seller_id AND sp.status IN ('pending', 'approved')
    ), 0),
    'available_balance', (
      COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.seller_id = p_seller_id AND t.type = 'purchase'), 0)
      - COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.seller_id = p_seller_id AND t.type = 'refund'), 0)
      - COALESCE((SELECT SUM(sp.amount) FROM seller_payouts sp WHERE sp.seller_id = p_seller_id AND sp.status IN ('pending', 'approved', 'completed')), 0)
    )
  );
$$;
