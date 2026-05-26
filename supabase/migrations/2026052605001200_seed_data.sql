-- 012_seed_data.sql
-- Seed data for development and testing
-- NOTE: profiles require auth.users entries, so they are created via the app's signup flow.
--       This seed only creates the school and students (which don't require auth).

--------------------------------------------------------------------------------
-- 1. Test school
--------------------------------------------------------------------------------
INSERT INTO schools (id, name, name_my, code, address, phone)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Springfield International School',
    E'\u1005\u1015\u101b\u1004\u1039\u1038\u1016\u102e\u1038\u101c\u1039',
    'SPRING-001',
    '123 Main Street, Yangon',
    '+95-1-234567'
);

--------------------------------------------------------------------------------
-- 2. Three sample students (wallets auto-created by trigger)
--------------------------------------------------------------------------------
INSERT INTO students (id, school_id, student_code, full_name, full_name_my, class_name, grade, enrollment_year)
VALUES
    ('c0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-001', 'Aung Aung', E'\u1021\u1031\u102c\u1004\u1039\u1021\u1031\u102c\u1004\u1039', 'Class A', 'Grade 5', 2025),

    ('c0000000-0000-0000-0000-000000000002',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-002', 'Mya Mya', E'\u1019\u103b\u102c\u1019\u103b\u102c', 'Class A', 'Grade 5', 2025),

    ('c0000000-0000-0000-0000-000000000003',
     'a0000000-0000-0000-0000-000000000001',
     'STU-2025-003', 'Zaw Zaw', E'\u1007\u1031\u102c\u1039\u1007\u1031\u102c\u1039', 'Class B', 'Grade 3', 2025);

-- Set initial balances (10000 kyats each)
UPDATE wallets SET balance = 10000
WHERE student_id IN (
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000003'
);
