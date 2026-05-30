-- Migration 026: Teacher role system
-- Adds teacher role, teachers table, and attendance RLS for teachers

-- 1. Add teacher to role constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('student', 'parent', 'seller', 'admin', 'counter_staff', 'super_admin', 'teacher'));

-- 2. Create teachers table
CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id),
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    assigned_grades TEXT[] NOT NULL DEFAULT '{}',
    assigned_classes TEXT[] NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teachers_profile ON teachers(profile_id);
CREATE INDEX IF NOT EXISTS idx_teachers_school ON teachers(school_id);

-- 3. RLS policies
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;

CREATE POLICY teachers_staff_all ON teachers FOR ALL USING (is_staff(auth.uid()));
CREATE POLICY teachers_self_select ON teachers FOR SELECT USING (profile_id = auth.uid());

-- 4. Allow teachers to manage attendance for their assigned students
CREATE POLICY attendance_teacher_all ON attendance FOR ALL USING (
    EXISTS (
        SELECT 1 FROM teachers t
        WHERE t.profile_id = auth.uid()
        AND t.school_id = attendance.school_id
        AND t.is_active = true
    )
);
