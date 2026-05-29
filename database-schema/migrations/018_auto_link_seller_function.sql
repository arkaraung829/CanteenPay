-- Auto-link seller function
-- Called from the mobile app after login to link a user to their seller record
-- by matching email or phone. Uses SECURITY DEFINER to bypass RLS so it can
-- update the user's role and school_id (which the user cannot change themselves).

CREATE OR REPLACE FUNCTION auto_link_seller(
    p_user_id UUID,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_seller RECORD;
    v_linked BOOLEAN := FALSE;
BEGIN
    -- Try to find a matching seller by email
    IF p_email IS NOT NULL AND p_email != '' THEN
        FOR v_seller IN
            SELECT id, school_id, profile_id
            FROM canteen_sellers
            WHERE email = LOWER(p_email)
              AND is_active = TRUE
        LOOP
            -- Link seller record to this user
            IF v_seller.profile_id IS NULL OR v_seller.profile_id != p_user_id THEN
                UPDATE canteen_sellers
                SET profile_id = p_user_id
                WHERE id = v_seller.id;
            END IF;

            -- Update user profile role and school
            IF v_seller.school_id IS NOT NULL THEN
                UPDATE profiles
                SET role = 'seller', school_id = v_seller.school_id
                WHERE id = p_user_id;
                v_linked := TRUE;
            END IF;
        END LOOP;
    END IF;

    -- Try phone if email didn't match
    IF NOT v_linked AND p_phone IS NOT NULL AND p_phone != '' THEN
        FOR v_seller IN
            SELECT id, school_id, profile_id
            FROM canteen_sellers
            WHERE phone = p_phone
              AND is_active = TRUE
        LOOP
            IF v_seller.profile_id IS NULL OR v_seller.profile_id != p_user_id THEN
                UPDATE canteen_sellers
                SET profile_id = p_user_id
                WHERE id = v_seller.id;
            END IF;

            IF v_seller.school_id IS NOT NULL THEN
                UPDATE profiles
                SET role = 'seller', school_id = v_seller.school_id
                WHERE id = p_user_id;
                v_linked := TRUE;
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object('linked', v_linked);
END;
$$;
