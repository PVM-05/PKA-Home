-- ============================================================================
-- Migration: 20261030_02_residents_apartments_lifecycle_and_batch_import.sql
-- Mô tả: Nâng cấp vòng đời liên kết cư dân (start_date, end_date, status) để bảo toàn
--        lịch sử khi cư dân chuyển đi, và các RPC nhập liệu hàng loạt (Căn hộ, Cư dân, Điện nước).
-- Thuộc: Giai đoạn B2 Commercial Roadmap.
-- ============================================================================

-- 1. Nâng cấp bảng residents_apartments (Vòng đời cư dân & Audit)
ALTER TABLE public.residents_apartments
ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'ended'));

CREATE INDEX IF NOT EXISTS idx_residents_apartments_status ON public.residents_apartments(apartment_id, status);

-- 2. RPC Nhập hàng loạt Căn Hộ (batch_import_apartments)
CREATE OR REPLACE FUNCTION public.batch_import_apartments(
    p_building_id UUID,
    p_apartments JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN;
    v_apt JSONB;
    v_code TEXT;
    v_area NUMERIC;
    v_is_empty BOOLEAN;
    v_success_count INT := 0;
    v_imported_codes JSONB := '[]'::jsonb;
BEGIN
    v_calling_user_id := auth.uid();

    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized AND v_calling_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập căn hộ hàng loạt';
    END IF;

    FOR v_apt IN SELECT * FROM jsonb_array_elements(p_apartments)
    LOOP
        v_code := UPPER(TRIM(v_apt->>'code'));
        v_area := COALESCE((v_apt->>'area')::numeric, 50.0);
        v_is_empty := COALESCE((v_apt->>'is_empty')::boolean, TRUE);

        IF v_code IS NOT NULL AND v_code != '' THEN
            INSERT INTO public.apartments (building_id, code, area, is_empty, created_at, updated_at)
            VALUES (p_building_id, v_code, v_area, v_is_empty, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (code) DO UPDATE
            SET area = EXCLUDED.area,
                building_id = EXCLUDED.building_id,
                updated_at = CURRENT_TIMESTAMP;

            v_success_count := v_success_count + 1;
            v_imported_codes := v_imported_codes || jsonb_build_array(v_code);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_codes', v_imported_codes
    );
END;
$$;

-- 3. RPC Nhập hàng loạt Cư Dân (batch_import_residents)
CREATE OR REPLACE FUNCTION public.batch_import_residents(
    p_building_id UUID,
    p_residents JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN;
    v_res JSONB;
    v_apt_code TEXT;
    v_full_name TEXT;
    v_phone TEXT;
    v_role TEXT;
    v_apt_id UUID;
    v_user_id UUID;
    v_success_count INT := 0;
    v_imported_phones JSONB := '[]'::jsonb;
BEGIN
    v_calling_user_id := auth.uid();

    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized AND v_calling_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập cư dân hàng loạt';
    END IF;

    FOR v_res IN SELECT * FROM jsonb_array_elements(p_residents)
    LOOP
        v_apt_code := UPPER(TRIM(v_res->>'apartment_code'));
        v_full_name := TRIM(v_res->>'full_name');
        v_phone := TRIM(v_res->>'phone');
        v_role := COALESCE(NULLIF(TRIM(v_res->>'relation_role'), ''), 'member');

        -- 1. Tìm căn hộ
        SELECT id INTO v_apt_id
        FROM public.apartments
        WHERE UPPER(code) = v_apt_code
          AND (p_building_id IS NULL OR building_id = p_building_id)
        LIMIT 1;

        IF v_apt_id IS NOT NULL AND v_phone IS NOT NULL AND v_phone != '' THEN
            -- 2. Tìm hoặc tạo User
            SELECT id INTO v_user_id
            FROM public.users
            WHERE phone = v_phone
            LIMIT 1;

            IF v_user_id IS NULL THEN
                v_user_id := gen_random_uuid();
                INSERT INTO public.users (id, full_name, phone, role, created_at, updated_at)
                VALUES (v_user_id, v_full_name, v_phone, 'resident', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
            ELSE
                UPDATE public.users
                SET full_name = COALESCE(NULLIF(v_full_name, ''), full_name),
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_user_id;
            END IF;

            -- 3. Nếu là chủ hộ mới (owner), kết thúc chủ hộ cũ của căn hộ này
            IF v_role = 'owner' THEN
                UPDATE public.residents_apartments
                SET status = 'ended',
                    end_date = CURRENT_TIMESTAMP
                WHERE apartment_id = v_apt_id
                  AND relation_role = 'owner'
                  AND status = 'active'
                  AND user_id != v_user_id;
            END IF;

            -- 4. Thêm hoặc cập nhật liên kết
            INSERT INTO public.residents_apartments (
                user_id, apartment_id, relation_role, status, start_date, created_at
            )
            VALUES (
                v_user_id, v_apt_id, v_role, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            )
            ON CONFLICT (user_id, apartment_id) DO UPDATE
            SET relation_role = EXCLUDED.relation_role,
                status = 'active',
                end_date = NULL;

            -- Cập nhật căn hộ không còn trống
            UPDATE public.apartments
            SET is_empty = FALSE
            WHERE id = v_apt_id;

            v_success_count := v_success_count + 1;
            v_imported_phones := v_imported_phones || jsonb_build_array(v_phone);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_phones', v_imported_phones
    );
END;
$$;

-- 4. RPC Nhập hàng loạt Chỉ Số Điện Nước (batch_import_meter_readings)
CREATE OR REPLACE FUNCTION public.batch_import_meter_readings(
    p_building_id UUID,
    p_period TEXT,
    p_readings JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN;
    v_item JSONB;
    v_apt_code TEXT;
    v_elec NUMERIC;
    v_water NUMERIC;
    v_apt_id UUID;
    v_success_count INT := 0;
    v_imported_codes JSONB := '[]'::jsonb;
BEGIN
    v_calling_user_id := auth.uid();

    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized AND v_calling_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập chỉ số điện nước hàng loạt';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_readings)
    LOOP
        v_apt_code := UPPER(TRIM(v_item->>'apartment_code'));
        v_elec := COALESCE((v_item->>'electric_reading')::numeric, 0.0);
        v_water := COALESCE((v_item->>'water_reading')::numeric, 0.0);

        SELECT id INTO v_apt_id
        FROM public.apartments
        WHERE UPPER(code) = v_apt_code
          AND (p_building_id IS NULL OR building_id = p_building_id)
        LIMIT 1;

        IF v_apt_id IS NOT NULL THEN
            -- Tạo hoặc cập nhật chỉ số điện nước
            INSERT INTO public.meter_reading_submissions (
                apartment_id,
                period,
                electric_reading,
                water_reading,
                status,
                submitted_by,
                reviewed_by,
                reviewed_at,
                created_at,
                updated_at
            )
            VALUES (
                v_apt_id,
                p_period,
                v_elec,
                v_water,
                'approved',
                v_calling_user_id,
                v_calling_user_id,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            )
            ON CONFLICT (apartment_id, period) DO UPDATE
            SET electric_reading = EXCLUDED.electric_reading,
                water_reading = EXCLUDED.water_reading,
                status = 'approved',
                reviewed_by = EXCLUDED.reviewed_by,
                reviewed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP;

            v_success_count := v_success_count + 1;
            v_imported_codes := v_imported_codes || jsonb_build_array(v_apt_code);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_codes', v_imported_codes
    );
END;
$$;

-- Cấp quyền gọi RPC
GRANT EXECUTE ON FUNCTION public.batch_import_apartments(UUID, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.batch_import_residents(UUID, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.batch_import_meter_readings(UUID, TEXT, JSONB) TO authenticated, service_role;

