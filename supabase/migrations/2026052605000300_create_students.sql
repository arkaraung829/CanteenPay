-- 003_create_students.sql
-- Students table with QR code data for canteen payments

CREATE TABLE students (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id           UUID REFERENCES profiles(id) ON DELETE SET NULL,
    school_id            UUID NOT NULL REFERENCES schools(id),
    student_code         TEXT NOT NULL,
    qr_data              UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    full_name            TEXT NOT NULL,
    full_name_my         TEXT,
    class_name           TEXT,
    grade                TEXT,
    enrollment_year      INT,
    photo_url            TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    daily_spending_limit BIGINT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_school_student_code UNIQUE (school_id, student_code)
);

CREATE INDEX idx_students_school_id ON students(school_id);
CREATE INDEX idx_students_profile_id ON students(profile_id);
CREATE INDEX idx_students_qr_data ON students(qr_data);

CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON students
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE students IS 'Student records with QR card data';
COMMENT ON COLUMN students.qr_data IS 'Random UUID printed on QR card (NOT the student_code, for security)';
COMMENT ON COLUMN students.daily_spending_limit IS 'Max daily spend in smallest currency unit (NULL = unlimited)';
COMMENT ON COLUMN students.profile_id IS 'Links to auth profile if student has app access (nullable)';
