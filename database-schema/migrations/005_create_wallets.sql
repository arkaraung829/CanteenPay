-- 005_create_wallets.sql
-- Student wallets holding canteen balance

CREATE TABLE wallets (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
    balance    BIGINT NOT NULL DEFAULT 0,
    currency   TEXT NOT NULL DEFAULT 'MMK',
    is_frozen  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_balance_non_negative CHECK (balance >= 0)
);

CREATE INDEX idx_wallets_student_id ON wallets(student_id);

CREATE TRIGGER trg_wallets_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-create a wallet when a student is inserted
CREATE OR REPLACE FUNCTION handle_new_student_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO wallets (student_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_student_created_wallet
    AFTER INSERT ON students
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_student_wallet();

COMMENT ON TABLE wallets IS 'Student payment wallets (one per student)';
COMMENT ON COLUMN wallets.balance IS 'Balance in smallest currency unit (e.g. kyats)';
COMMENT ON COLUMN wallets.is_frozen IS 'Frozen wallets cannot be used for purchases';
