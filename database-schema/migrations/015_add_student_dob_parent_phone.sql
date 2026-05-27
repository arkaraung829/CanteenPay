ALTER TABLE students ADD COLUMN IF NOT EXISTS date_of_birth TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_phone TEXT;
CREATE INDEX IF NOT EXISTS idx_students_parent_phone ON students(parent_phone);
