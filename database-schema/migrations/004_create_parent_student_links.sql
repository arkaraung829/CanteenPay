-- 004_create_parent_student_links.sql
-- Links parents to their children (students)

CREATE TABLE parent_student_links (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL DEFAULT 'parent',
    is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_parent_student UNIQUE (parent_id, student_id)
);

CREATE INDEX idx_parent_student_links_parent_id ON parent_student_links(parent_id);
CREATE INDEX idx_parent_student_links_student_id ON parent_student_links(student_id);

COMMENT ON TABLE parent_student_links IS 'Many-to-many relationship between parents and students';
COMMENT ON COLUMN parent_student_links.relationship IS 'e.g. parent, guardian, relative';
COMMENT ON COLUMN parent_student_links.is_primary IS 'Whether this parent is the primary contact for the student';
