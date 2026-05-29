-- 020_auto_link_parent_rpc.sql
-- SECURITY DEFINER functions for parent auto-linking.
-- Bypasses RLS so parents can discover students by email/phone
-- even before the parent_student_links row exists.

CREATE OR REPLACE FUNCTION auto_link_parent_by_email(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_parent_id UUID;
    v_student RECORD;
    v_linked INT := 0;
BEGIN
    v_parent_id := auth.uid();
    IF v_parent_id IS NULL THEN
        RETURN jsonb_build_object('linked', 0);
    END IF;

    FOR v_student IN
        SELECT id FROM students
        WHERE parent_email = lower(p_email) AND is_active = true
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM parent_student_links
            WHERE parent_id = v_parent_id AND student_id = v_student.id
        ) THEN
            INSERT INTO parent_student_links (parent_id, student_id)
            VALUES (v_parent_id, v_student.id);
            v_linked := v_linked + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('linked', v_linked);
END;
$$;

CREATE OR REPLACE FUNCTION auto_link_parent_by_phone(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_parent_id UUID;
    v_student RECORD;
    v_linked INT := 0;
BEGIN
    v_parent_id := auth.uid();
    IF v_parent_id IS NULL THEN
        RETURN jsonb_build_object('linked', 0);
    END IF;

    FOR v_student IN
        SELECT id FROM students
        WHERE parent_phone = p_phone AND is_active = true
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM parent_student_links
            WHERE parent_id = v_parent_id AND student_id = v_student.id
        ) THEN
            INSERT INTO parent_student_links (parent_id, student_id)
            VALUES (v_parent_id, v_student.id);
            v_linked := v_linked + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('linked', v_linked);
END;
$$;

COMMENT ON FUNCTION auto_link_parent_by_email IS 'Auto-link parent to students by email (SECURITY DEFINER bypasses RLS)';
COMMENT ON FUNCTION auto_link_parent_by_phone IS 'Auto-link parent to students by phone (SECURITY DEFINER bypasses RLS)';
