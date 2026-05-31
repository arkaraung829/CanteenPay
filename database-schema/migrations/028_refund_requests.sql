-- Refund requests table + approval RPC
CREATE TABLE IF NOT EXISTS refund_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID REFERENCES transactions(id) NOT NULL,
  student_id UUID REFERENCES students(id) NOT NULL,
  seller_id UUID NOT NULL,
  amount INT NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_by UUID REFERENCES profiles(id),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_refund_req_unique_pending ON refund_requests(transaction_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_refund_req_seller ON refund_requests(seller_id);
CREATE INDEX IF NOT EXISTS idx_refund_req_status ON refund_requests(status);

ALTER TABLE refund_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS refund_req_staff_select ON refund_requests;
CREATE POLICY refund_req_staff_select ON refund_requests FOR SELECT USING (is_staff(auth.uid()));

DROP POLICY IF EXISTS refund_req_seller_select ON refund_requests;
CREATE POLICY refund_req_seller_select ON refund_requests FOR SELECT USING (
  EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = seller_id AND cs.profile_id = auth.uid())
);

DROP POLICY IF EXISTS refund_req_staff_insert ON refund_requests;
CREATE POLICY refund_req_staff_insert ON refund_requests FOR INSERT WITH CHECK (is_staff(auth.uid()));

DROP POLICY IF EXISTS refund_req_seller_update ON refund_requests;
CREATE POLICY refund_req_seller_update ON refund_requests FOR UPDATE USING (
  EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = seller_id AND cs.profile_id = auth.uid())
);

-- RPC: Seller approves refund
CREATE OR REPLACE FUNCTION approve_refund_request(p_request_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $func$
DECLARE
  v_req RECORD;
  v_wallet RECORD;
  v_tx RECORD;
  v_new_balance BIGINT;
  v_refund_tx_id UUID;
BEGIN
  -- Get and lock request
  SELECT * INTO v_req FROM refund_requests WHERE id = p_request_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request not found or already processed');
  END IF;

  -- Verify seller owns this request
  IF NOT EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = v_req.seller_id AND cs.profile_id = auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Get original transaction
  SELECT * INTO v_tx FROM transactions WHERE id = v_req.transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Original transaction not found');
  END IF;

  -- Lock and update wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  v_new_balance := v_wallet.balance + v_req.amount;

  UPDATE wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet.id;

  -- Create refund transaction
  INSERT INTO transactions (wallet_id, type, amount, balance_before, balance_after, description, reference_id, performed_by, seller_id)
  VALUES (v_wallet.id, 'refund', v_req.amount, v_wallet.balance, v_new_balance, 'Refund approved by seller', v_req.transaction_id, auth.uid(), v_req.seller_id)
  RETURNING id INTO v_refund_tx_id;

  -- Update request status
  UPDATE refund_requests SET status = 'approved', responded_at = now() WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'transaction_id', v_refund_tx_id, 'new_balance', v_new_balance);
END;
$func$;

-- RPC: Seller rejects refund
CREATE OR REPLACE FUNCTION reject_refund_request(p_request_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $func$
DECLARE
  v_req RECORD;
BEGIN
  SELECT * INTO v_req FROM refund_requests WHERE id = p_request_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request not found or already processed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM canteen_sellers cs WHERE cs.id = v_req.seller_id AND cs.profile_id = auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  UPDATE refund_requests SET status = 'rejected', responded_at = now() WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true);
END;
$func$;

ALTER PUBLICATION supabase_realtime ADD TABLE refund_requests;
