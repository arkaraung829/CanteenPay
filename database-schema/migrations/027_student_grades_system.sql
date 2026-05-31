-- 027_student_grades_system.sql
-- Student grade tracking: subjects, exam types, grades, and report cards

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_my TEXT,
    grade_levels TEXT[] NOT NULL DEFAULT '{}',
    full_marks INTEGER NOT NULL DEFAULT 100,
    pass_marks INTEGER NOT NULL DEFAULT 40,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_subject_school_name UNIQUE (school_id, name)
);

CREATE TABLE IF NOT EXISTS exam_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_my TEXT,
    weight NUMERIC(5,2) NOT NULL DEFAULT 100,
    term TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_exam_type_school_name UNIQUE (school_id, name)
);

CREATE TABLE IF NOT EXISTS student_grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    exam_type_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    academic_year TEXT NOT NULL,
    score NUMERIC(6,2),
    full_marks INTEGER NOT NULL DEFAULT 100,
    letter_grade TEXT,
    remarks TEXT,
    graded_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_student_subject_exam UNIQUE (student_id, subject_id, exam_type_id, academic_year)
);

CREATE TABLE IF NOT EXISTS report_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year TEXT NOT NULL,
    term TEXT NOT NULL,
    total_score NUMERIC(8,2),
    total_full_marks INTEGER,
    percentage NUMERIC(5,2),
    rank_in_class INTEGER,
    overall_grade TEXT,
    result TEXT,
    teacher_comment TEXT,
    principal_comment TEXT,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_report_card UNIQUE (student_id, academic_year, term)
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_subjects_school_id ON subjects(school_id);
CREATE INDEX IF NOT EXISTS idx_subjects_active ON subjects(school_id, is_active);

CREATE INDEX IF NOT EXISTS idx_exam_types_school_id ON exam_types(school_id);
CREATE INDEX IF NOT EXISTS idx_exam_types_active ON exam_types(school_id, is_active);

CREATE INDEX IF NOT EXISTS idx_student_grades_student ON student_grades(student_id);
CREATE INDEX IF NOT EXISTS idx_student_grades_subject ON student_grades(subject_id);
CREATE INDEX IF NOT EXISTS idx_student_grades_exam_type ON student_grades(exam_type_id);
CREATE INDEX IF NOT EXISTS idx_student_grades_year ON student_grades(academic_year);
CREATE INDEX IF NOT EXISTS idx_student_grades_lookup ON student_grades(student_id, academic_year, exam_type_id);

CREATE INDEX IF NOT EXISTS idx_report_cards_student ON report_cards(student_id);
CREATE INDEX IF NOT EXISTS idx_report_cards_school ON report_cards(school_id);
CREATE INDEX IF NOT EXISTS idx_report_cards_year ON report_cards(academic_year, term);

-- ============================================================
-- 3. TRIGGERS for updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subjects_updated_at ON subjects;
CREATE TRIGGER trg_subjects_updated_at
    BEFORE UPDATE ON subjects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_exam_types_updated_at ON exam_types;
CREATE TRIGGER trg_exam_types_updated_at
    BEFORE UPDATE ON exam_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_student_grades_updated_at ON student_grades;
CREATE TRIGGER trg_student_grades_updated_at
    BEFORE UPDATE ON student_grades
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_report_cards_updated_at ON report_cards;
CREATE TRIGGER trg_report_cards_updated_at
    BEFORE UPDATE ON report_cards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. HELPER FUNCTIONS
-- ============================================================

-- Myanmar grading scale:
-- >= 80% = A (Distinction)
-- >= 60% = B (Credit)
-- >= 40% = C (Pass)
-- < 40%  = F (Fail)
CREATE OR REPLACE FUNCTION compute_letter_grade(p_score NUMERIC, p_full_marks INTEGER)
RETURNS TEXT AS $$
DECLARE
    pct NUMERIC;
BEGIN
    IF p_score IS NULL OR p_full_marks IS NULL OR p_full_marks = 0 THEN
        RETURN NULL;
    END IF;
    pct := (p_score / p_full_marks) * 100;
    IF pct >= 80 THEN RETURN 'A';
    ELSIF pct >= 60 THEN RETURN 'B';
    ELSIF pct >= 40 THEN RETURN 'C';
    ELSE RETURN 'F';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION compute_result(p_percentage NUMERIC)
RETURNS TEXT AS $$
BEGIN
    IF p_percentage IS NULL THEN RETURN NULL; END IF;
    IF p_percentage >= 80 THEN RETURN 'Distinction';
    ELSIF p_percentage >= 60 THEN RETURN 'Credit';
    ELSIF p_percentage >= 40 THEN RETURN 'Pass';
    ELSE RETURN 'Fail';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_cards ENABLE ROW LEVEL SECURITY;

-- Staff (admin/counter_staff) have full access
CREATE POLICY subjects_staff_all ON subjects
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('admin', 'counter_staff')
        )
    );

CREATE POLICY exam_types_staff_all ON exam_types
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('admin', 'counter_staff')
        )
    );

CREATE POLICY student_grades_staff_all ON student_grades
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('admin', 'counter_staff')
        )
    );

CREATE POLICY report_cards_staff_all ON report_cards
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid()
            AND p.role IN ('admin', 'counter_staff')
        )
    );

-- Teachers can manage grades for students in their school
CREATE POLICY student_grades_teacher ON student_grades
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            JOIN teachers t ON t.profile_id = p.id
            WHERE p.id = auth.uid()
            AND p.role = 'teacher'
            AND t.is_active = true
        )
    );

CREATE POLICY subjects_teacher_select ON subjects
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            JOIN teachers t ON t.profile_id = p.id
            WHERE p.id = auth.uid()
            AND p.role = 'teacher'
            AND t.is_active = true
            AND t.school_id = subjects.school_id
        )
    );

CREATE POLICY exam_types_teacher_select ON exam_types
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            JOIN teachers t ON t.profile_id = p.id
            WHERE p.id = auth.uid()
            AND p.role = 'teacher'
            AND t.is_active = true
            AND t.school_id = exam_types.school_id
        )
    );

CREATE POLICY report_cards_teacher ON report_cards
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            JOIN teachers t ON t.profile_id = p.id
            WHERE p.id = auth.uid()
            AND p.role = 'teacher'
            AND t.is_active = true
            AND t.school_id = report_cards.school_id
        )
    );

-- Parents can SELECT linked student grades/report cards
CREATE POLICY student_grades_parent_select ON student_grades
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM student_parents sp
            WHERE sp.parent_id = auth.uid()
            AND sp.student_id = student_grades.student_id
        )
    );

CREATE POLICY report_cards_parent_select ON report_cards
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM student_parents sp
            WHERE sp.parent_id = auth.uid()
            AND sp.student_id = report_cards.student_id
        )
    );

-- Students can SELECT their own grades/report cards
CREATE POLICY student_grades_student_select ON student_grades
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM students s
            WHERE s.id = student_grades.student_id
            AND s.profile_id = auth.uid()
        )
    );

CREATE POLICY report_cards_student_select ON report_cards
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM students s
            WHERE s.id = report_cards.student_id
            AND s.profile_id = auth.uid()
        )
    );
