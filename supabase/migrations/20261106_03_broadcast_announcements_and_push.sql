-- =====================================================================
-- Migration: 20261106_03_broadcast_announcements_and_push.sql
-- Module: Broadcast Announcements & Push Notification Engine
-- Mô tả:
--   1. Nâng cấp bảng announcements: category, event_start_at, event_end_at, is_pinned, broadcast_count, read_count, hotline_contact
--   2. Hàm broadcast_announcement: Tự động quét cư dân theo phạm vi và bulk insert vào bảng notifications
--   3. Hàm mark_announcement_read: Ghi nhận đã đọc trong notifications và cập nhật read_count trong announcements
-- =====================================================================

-- 1. Nâng cấp bảng public.announcements
ALTER TABLE public.announcements
    ADD COLUMN IF NOT EXISTS category VARCHAR(30) NOT NULL DEFAULT 'general',
    ADD COLUMN IF NOT EXISTS event_start_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS event_end_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS broadcast_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS read_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS hotline_contact VARCHAR(20);

ALTER TABLE public.announcements
    DROP CONSTRAINT IF EXISTS chk_announcements_category;

ALTER TABLE public.announcements
    ADD CONSTRAINT chk_announcements_category 
    CHECK (category IN ('emergency', 'elevator_maintenance', 'utility_outage', 'resident_meeting', 'general'));

CREATE INDEX IF NOT EXISTS idx_announcements_category ON public.announcements(category);
CREATE INDEX IF NOT EXISTS idx_announcements_pinned ON public.announcements(is_pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_event_time ON public.announcements(event_start_at, event_end_at);

-- 2. Stored Procedure: broadcast_announcement
CREATE OR REPLACE FUNCTION public.broadcast_announcement(p_announcement_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_ann RECORD;
    v_target_user RECORD;
    v_count INT := 0;
    v_clean_target_val TEXT;
    v_target_floor INT;
    v_building_id UUID;
BEGIN
    -- Lấy thông tin thông báo
    SELECT * INTO v_ann
    FROM public.announcements
    WHERE id = p_announcement_id;

    IF v_ann IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Không tìm thấy thông báo tương ứng.'
        );
    END IF;

    v_building_id := v_ann.building_id;
    v_clean_target_val := UPPER(TRIM(COALESCE(v_ann.target_value, v_ann.target_apartment, '')));

    -- Con trỏ quét danh sách cư dân nhận thông báo
    FOR v_target_user IN
        SELECT DISTINCT
            u.id AS user_id,
            apt.id AS apartment_id,
            apt.building_id
        FROM public.users u
        JOIN public.residents_apartments ra ON u.id = ra.user_id
        JOIN public.apartments apt ON ra.apartment_id = apt.id
        WHERE u.is_active = TRUE
          AND (v_building_id IS NULL OR apt.building_id = v_building_id)
          AND (
              -- 1. Phát toàn tòa / tất cả cư dân
              v_ann.target_type = 'all'
              -- 2. Phát theo Block (Ví dụ: Block A, Block B)
              OR (
                  v_ann.target_type IN ('block', 'block_a', 'block_b')
                  AND (
                      (v_ann.target_type = 'block' AND UPPER(apt.block) = v_clean_target_val)
                      OR (v_ann.target_type = 'block_a' AND (UPPER(apt.block) = 'A' OR apt.code ILIKE 'A%'))
                      OR (v_ann.target_type = 'block_b' AND (UPPER(apt.block) = 'B' OR apt.code ILIKE 'B%'))
                  )
              )
              -- 3. Phát theo Tầng
              OR (
                  v_ann.target_type = 'floor'
                  AND apt.floor = CASE 
                      WHEN v_clean_target_val ~ '^[0-9]+$' THEN v_clean_target_val::INT 
                      ELSE -1 
                  END
              )
              -- 4. Phát theo Căn hộ cụ thể
              OR (
                  v_ann.target_type = 'apartment'
                  AND UPPER(apt.code) = v_clean_target_val
              )
          )
    LOOP
        -- Kiểm tra xem cư dân này đã có notification của announcement này chưa để tránh spam
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications n
            WHERE n.user_id = v_target_user.user_id
              AND (n.payload->>'announcement_id') = p_announcement_id::TEXT
        ) THEN
            INSERT INTO public.notifications (
                id,
                building_id,
                user_id,
                apartment_id,
                title,
                body,
                type,
                payload,
                is_read,
                created_at
            ) VALUES (
                gen_random_uuid(),
                v_target_user.building_id,
                v_target_user.user_id,
                v_target_user.apartment_id,
                CASE 
                    WHEN v_ann.is_urgent THEN '[KHẨN CẤP] ' || v_ann.title
                    ELSE v_ann.title
                END,
                v_ann.content,
                'announcement',
                jsonb_build_object(
                    'announcement_id', v_ann.id,
                    'category', v_ann.category,
                    'is_urgent', v_ann.is_urgent,
                    'event_start_at', v_ann.event_start_at,
                    'event_end_at', v_ann.event_end_at,
                    'hotline_contact', v_ann.hotline_contact
                ),
                FALSE,
                CURRENT_TIMESTAMP
            );

            v_count := v_count + 1;
        END IF;
    END LOOP;

    -- Cập nhật tổng số cư dân đã nhận thông báo
    UPDATE public.announcements
    SET broadcast_count = (
        SELECT COUNT(DISTINCT user_id) 
        FROM public.notifications 
        WHERE (payload->>'announcement_id') = p_announcement_id::TEXT
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE id = p_announcement_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcast_count', v_count,
        'message', 'Đã phát sóng thông báo thành công tới ' || v_count || ' cư dân.'
    );
END;
$function$;

-- 3. Stored Procedure: mark_announcement_read
CREATE OR REPLACE FUNCTION public.mark_announcement_read(
    p_announcement_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_updated_rows INT := 0;
BEGIN
    IF p_user_id IS NULL OR p_announcement_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Thiếu tham số bắt buộc.');
    END IF;

    -- Đánh dấu đã đọc trong bảng notifications
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE user_id = p_user_id
      AND (payload->>'announcement_id') = p_announcement_id::TEXT
      AND is_read = FALSE;

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

    -- Cập nhật tổng số lượt đã đọc trong bảng announcements
    UPDATE public.announcements
    SET read_count = (
        SELECT COUNT(DISTINCT user_id)
        FROM public.notifications
        WHERE (payload->>'announcement_id') = p_announcement_id::TEXT
          AND is_read = TRUE
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE id = p_announcement_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'updated_count', v_updated_rows
    );
END;
$function$;

