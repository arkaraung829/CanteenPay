-- 025: Attendance tracking table
-- Tracks daily attendance for each student (present/absent/late)

CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id),
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late')),
    notes TEXT,
    marked_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_student_date UNIQUE (student_id, date)
);

CREATE INDEX idx_attendance_school_date ON attendance(school_id, date);
CREATE INDEX idx_attendance_student_date ON attendance(student_id, date);

CREATE TRIGGER trg_attendance_updated_at BEFORE UPDATE ON attendance FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY attendance_staff_all ON attendance FOR ALL USING (is_staff(auth.uid()));
CREATE POLICY attendance_parent_select ON attendance FOR SELECT USING (EXISTS (SELECT 1 FROM parent_student_links psl WHERE psl.student_id = attendance.student_id AND psl.parent_id = auth.uid()));
CREATE POLICY attendance_student_select ON attendance FOR SELECT USING (EXISTS (SELECT 1 FROM students s WHERE s.id = attendance.student_id AND s.profile_id = auth.uid()));
