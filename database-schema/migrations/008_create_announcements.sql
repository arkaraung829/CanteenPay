-- 008_create_announcements.sql
-- School announcements (Phase 2 - schema created now)

CREATE TABLE announcements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id       UUID NOT NULL REFERENCES schools(id),
    author_id       UUID NOT NULL REFERENCES profiles(id),
    title           TEXT NOT NULL,
    title_my        TEXT,
    body            TEXT NOT NULL,
    body_my         TEXT,
    target_audience TEXT[] NOT NULL DEFAULT '{all}',
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    published_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_announcements_school_id ON announcements(school_id);
CREATE INDEX idx_announcements_published ON announcements(school_id, is_published, published_at DESC);

CREATE TRIGGER trg_announcements_updated_at
    BEFORE UPDATE ON announcements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE announcements IS 'School announcements (Phase 2 feature)';
COMMENT ON COLUMN announcements.target_audience IS 'Array of audience groups: all, parent, student, seller';
COMMENT ON COLUMN announcements.title_my IS 'Title in Myanmar language';
COMMENT ON COLUMN announcements.body_my IS 'Body in Myanmar language';
