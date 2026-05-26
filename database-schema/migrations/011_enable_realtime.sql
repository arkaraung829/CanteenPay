-- 011_enable_realtime.sql
-- Enable Supabase Realtime on key tables for live updates

-- Parents and students see wallet balance changes in real-time
ALTER PUBLICATION supabase_realtime ADD TABLE wallets;

-- Parents see new transactions appear in real-time
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
