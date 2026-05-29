-- 017_add_student_pin_code.sql
-- Add a 4-digit PIN code to students for seller verification after QR scan.

ALTER TABLE students ADD COLUMN pin_code TEXT;

-- Generate random 4-digit PINs for all existing students
UPDATE students SET pin_code = LPAD(floor(random() * 10000)::text, 4, '0');

-- Make it NOT NULL after backfill
ALTER TABLE students ALTER COLUMN pin_code SET NOT NULL;

-- Unique per school (two students in the same school can't share a PIN)
ALTER TABLE students ADD CONSTRAINT uq_school_pin_code UNIQUE (school_id, pin_code);

CREATE INDEX idx_students_pin_code ON students(pin_code);

COMMENT ON COLUMN students.pin_code IS '4-digit verification code seller must enter after scanning QR';
