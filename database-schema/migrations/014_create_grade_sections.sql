-- Migration: Create school_grades and school_sections tables
-- These allow schools to configure their own grade levels and class sections

-- School Grades
CREATE TABLE IF NOT EXISTS school_grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_school_grades_school_id ON school_grades(school_id);
CREATE INDEX idx_school_grades_display_order ON school_grades(school_id, display_order);

-- School Sections
CREATE TABLE IF NOT EXISTS school_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_school_sections_school_id ON school_sections(school_id);
CREATE INDEX idx_school_sections_display_order ON school_sections(school_id, display_order);

-- Enable RLS
ALTER TABLE school_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_sections ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Allow service role full access (admin dashboard uses service role key)
CREATE POLICY "Service role has full access to school_grades"
  ON school_grades
  FOR ALL
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to school_sections"
  ON school_sections
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Seed default grades (assumes a school already exists)
DO $$
DECLARE
  v_school_id UUID;
BEGIN
  SELECT id INTO v_school_id FROM schools WHERE is_active = true LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    -- Seed grades: KG, Grade 1 through Grade 11
    INSERT INTO school_grades (school_id, name, display_order, is_active) VALUES
      (v_school_id, 'KG', 0, true),
      (v_school_id, 'Grade 1', 1, true),
      (v_school_id, 'Grade 2', 2, true),
      (v_school_id, 'Grade 3', 3, true),
      (v_school_id, 'Grade 4', 4, true),
      (v_school_id, 'Grade 5', 5, true),
      (v_school_id, 'Grade 6', 6, true),
      (v_school_id, 'Grade 7', 7, true),
      (v_school_id, 'Grade 8', 8, true),
      (v_school_id, 'Grade 9', 9, true),
      (v_school_id, 'Grade 10', 10, true),
      (v_school_id, 'Grade 11', 11, true)
    ON CONFLICT DO NOTHING;

    -- Seed sections: A through E
    INSERT INTO school_sections (school_id, name, display_order, is_active) VALUES
      (v_school_id, 'A', 0, true),
      (v_school_id, 'B', 1, true),
      (v_school_id, 'C', 2, true),
      (v_school_id, 'D', 3, true),
      (v_school_id, 'E', 4, true)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
