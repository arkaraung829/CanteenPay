-- 012_seed_data.sql
-- Seed data for development and testing
-- NOTE: This file uses fixed UUIDs for reproducibility in dev environments.
--       Do NOT run this in production.

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
-- 2. Admin user profile (manually inserted; in production, auth.users triggers this)
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, full_name_my, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'admin',
    'a0000000-0000-0000-0000-000000000001',
    'Admin User',
    E'\u1021\u1000\u103a\u1019\u1004\u1039',
    '+95-9-111111111'
);

--------------------------------------------------------------------------------
-- 3. Counter staff profile
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'counter_staff',
    'a0000000-0000-0000-0000-000000000001',
    'Counter Staff One',
    '+95-9-222222222'
);

--------------------------------------------------------------------------------
-- 4. Three sample students (wallets auto-created by trigger)
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

--------------------------------------------------------------------------------
-- 5. Sample canteen seller
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'seller',
    'a0000000-0000-0000-0000-000000000001',
    'Daw Khin',
    '+95-9-333333333'
);

INSERT INTO canteen_sellers (id, profile_id, school_id, stall_name, stall_name_my, stall_number)
VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Daw Khin Snacks',
    E'\u1012\u1031\u102b\u1039\u1001\u1004\u1039\u1019\u102f\u1014\u1039\u1038',
    'A-1'
);

--------------------------------------------------------------------------------
-- 6. Sample parent with links to 2 students
--------------------------------------------------------------------------------
INSERT INTO profiles (id, role, school_id, full_name, phone)
VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'parent',
    'a0000000-0000-0000-0000-000000000001',
    'U Kyaw',
    '+95-9-444444444'
);

INSERT INTO parent_student_links (parent_id, student_id, relationship, is_primary)
VALUES
    ('b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'parent', TRUE),
    ('b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'parent', TRUE);
