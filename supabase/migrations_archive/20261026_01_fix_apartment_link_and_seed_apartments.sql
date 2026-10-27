-- ==============================================================================
-- MIGRATION: 20261026_01_fix_apartment_link_and_seed_apartments.sql
-- 1. Bổ sung danh mục căn hộ phòng 06-10 cho các tầng 1-10 (Đặc biệt là A0110 chuẩn mẫu)
-- 2. Cải thiện RPC find_apartment_by_code: Không phân biệt hoa thường và tự động TRIM
-- 3. Bổ sung RPC submit_apartment_link_request nguyên tử, bảo mật (SECURITY DEFINER)
-- 4. Bổ sung RLS policy cho phép Resident xóa yêu cầu cũ bị từ chối / đã hủy
-- ==============================================================================

-- 1. Thêm danh mục căn hộ cho các phòng 06 đến 10 của các Tòa A, B, C (Tầng 1-10)
DO $$
DECLARE
    b_code TEXT;
    f_num INT;
    r_num INT;
    apt_code TEXT;
BEGIN
    FOR b_code IN SELECT unnest(ARRAY['A', 'B', 'C']) LOOP
        FOR f_num IN 1..10 LOOP
            FOR r_num IN 6..10 LOOP
                apt_code := b_code || to_char(f_num, 'FM00') || to_char(r_num, 'FM00');
                INSERT INTO public.apartments (code, building_code, floor_number, area, is_empty)
                VALUES (apt_code, b_code, f_num, 75.0, true)
                ON CONFLICT (code) DO NOTHING;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- 2. Cập nhật RPC find_apartment_by_code để tìm kiếm không phân biệt hoa thường & trim khoảng trắng
CREATE OR REPLACE FUNCTION public.find_apartment_by_code(p_code character varying)
RETURNS TABLE(id uuid, code character varying, is_empty boolean)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY 
  SELECT a.id, a.code, a.is_empty 
  FROM public.apartments a 
  WHERE UPPER(TRIM(a.code)) = UPPER(TRIM(p_code));
END;
$function$;

-- 3. Tạo RPC nguyên tử xử lý gửi yêu cầu liên kết an toàn
CREATE OR REPLACE FUNCTION public.submit_apartment_link_request(
    p_apartment_code text,
    p_relation_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id uuid;
    v_apartment_id uuid;
    v_req_id uuid;
    v_clean_code text;
    v_role public.relation_type;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Vui lòng đăng nhập để thực hiện thao tác này.';
    END IF;

    v_clean_code := UPPER(TRIM(p_apartment_code));
    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RAISE EXCEPTION 'Mã căn hộ không được để trống.';
    END IF;

    -- Chuẩn hóa role
    BEGIN
        v_role := p_relation_role::public.relation_type;
    EXCEPTION WHEN OTHERS THEN
        v_role := 'owner'::public.relation_type;
    END;

    -- Kiểm tra xem cư dân đã liên kết căn hộ nào chưa
    IF EXISTS (SELECT 1 FROM public.residents_apartments WHERE user_id = v_user_id) THEN
        RAISE EXCEPTION 'Bạn đã được liên kết với căn hộ trong hệ thống.';
    END IF;

    -- Kiểm tra xem đang có yêu cầu chờ duyệt nào không
    IF EXISTS (SELECT 1 FROM public.apartment_link_requests WHERE user_id = v_user_id AND status = 'pending') THEN
        RAISE EXCEPTION 'Bạn đang có một yêu cầu liên kết đang chờ Ban quản lý phê duyệt. Vui lòng chờ xử lý trước khi gửi yêu cầu mới.';
    END IF;

    -- Tìm căn hộ theo mã
    SELECT id INTO v_apartment_id 
    FROM public.apartments 
    WHERE UPPER(TRIM(code)) = v_clean_code
    LIMIT 1;

    IF v_apartment_id IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ với mã % trong hệ thống.', v_clean_code;
    END IF;

    -- Xóa các yêu cầu cũ bị từ chối hoặc đã hủy của user này để tránh lỗi unique constraint
    DELETE FROM public.apartment_link_requests 
    WHERE user_id = v_user_id AND status IN ('rejected', 'cancelled');

    -- Chèn yêu cầu mới
    INSERT INTO public.apartment_link_requests (
        user_id,
        apartment_id,
        requested_relation_role,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        v_apartment_id,
        v_role,
        'pending',
        NOW(),
        NOW()
    ) RETURNING id INTO v_req_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_req_id,
        'apartment_id', v_apartment_id,
        'apartment_code', v_clean_code,
        'message', 'Đã gửi yêu cầu liên kết thành công!'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_apartment_link_request(text, text) TO authenticated;

-- 4. Bổ sung policy DELETE cho resident trên apartment_link_requests
DROP POLICY IF EXISTS "Resident xóa yêu cầu bị từ chối hoặc đã hủy của mình" ON public.apartment_link_requests;
CREATE POLICY "Resident xóa yêu cầu bị từ chối hoặc đã hủy của mình" 
ON public.apartment_link_requests FOR DELETE 
USING (user_id = auth.uid() AND status IN ('rejected', 'cancelled'));

-- 5. Cho phép cả anon và authenticated đọc danh mục apartments phục vụ chọn mã căn hộ khi liên kết
DROP POLICY IF EXISTS "Allow authenticated users to select apartments" ON public.apartments;
DROP POLICY IF EXISTS "Allow anon and authenticated to view apartments" ON public.apartments;
CREATE POLICY "Allow anon and authenticated to view apartments"
ON public.apartments FOR SELECT
TO anon, authenticated
USING (true);

-- Ghi nhận migration vào _applied_migrations
INSERT INTO public._applied_migrations (name) 
VALUES ('20261026_01_fix_apartment_link_and_seed_apartments.sql')
ON CONFLICT (name) DO NOTHING;
