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
