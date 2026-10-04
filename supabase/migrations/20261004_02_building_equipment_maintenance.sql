-- ==============================================================================
-- Migration: 20261004_02_building_equipment_maintenance.sql
-- Module: Quản lý thiết bị tòa nhà & bảo trì định kỳ (Building Equipment & Preventive Maintenance)
-- ==============================================================================

-- 1. BẢNG DANH MỤC THIẾT BỊ TÒA NHÀ (building_equipments)
CREATE TABLE IF NOT EXISTS public.building_equipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('elevator', 'fire_safety', 'water_pump', 'generator', 'electrical', 'hvac', 'other')),
    building TEXT NOT NULL DEFAULT 'Toàn khu',
    location TEXT NOT NULL,
    installation_date DATE,
    warranty_until DATE,
    maintenance_interval_days INTEGER NOT NULL DEFAULT 30 CHECK (maintenance_interval_days > 0),
    last_maintenance_date TIMESTAMPTZ,
    next_maintenance_date TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'operational' CHECK (status IN ('operational', 'under_maintenance', 'degraded', 'inactive')),
    specifications TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. BẢNG PHIẾU BẢO TRÌ & NHẬT KÝ SỬA CHỮA (equipment_maintenance_tasks)
CREATE TABLE IF NOT EXISTS public.equipment_maintenance_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_id UUID NOT NULL REFERENCES public.building_equipments(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    task_type TEXT NOT NULL DEFAULT 'scheduled' CHECK (task_type IN ('scheduled', 'unscheduled', 'inspection')),
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    technician_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    vendor_name TEXT,
    vendor_contact TEXT,
    cost NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    affects_service BOOLEAN NOT NULL DEFAULT false,
    service_interruption_note TEXT,
    notes TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_scheduled_dates CHECK (scheduled_end >= scheduled_start)
);

-- 3. INDEXES TỐI ƯU HIỆU NĂNG
CREATE INDEX IF NOT EXISTS idx_building_equipments_building ON public.building_equipments(building);
CREATE INDEX IF NOT EXISTS idx_building_equipments_category ON public.building_equipments(category);
CREATE INDEX IF NOT EXISTS idx_building_equipments_status ON public.building_equipments(status);
CREATE INDEX IF NOT EXISTS idx_building_equipments_next_maint ON public.building_equipments(next_maintenance_date);

CREATE INDEX IF NOT EXISTS idx_equipment_tasks_equipment_id ON public.equipment_maintenance_tasks(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_tasks_status ON public.equipment_maintenance_tasks(status);
CREATE INDEX IF NOT EXISTS idx_equipment_tasks_dates ON public.equipment_maintenance_tasks(scheduled_start, scheduled_end);

-- 4. BẬT ROW LEVEL SECURITY (RLS)
ALTER TABLE public.building_equipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_maintenance_tasks ENABLE ROW LEVEL SECURITY;

-- Hàm trợ giúp kiểm tra quyền kỹ thuật/quản lý
CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND (
        role IN ('management', 'admin', 'technician')
        OR EXISTS (
          SELECT 1 FROM public.role_delegations rd
          WHERE rd.delegate_user_id = auth.uid()
            AND rd.target_role IN ('management', 'admin', 'technician')
            AND rd.status = 'active'
            AND now() BETWEEN rd.start_time AND rd.end_time
        )
      )
  );
$$;

-- RLS: building_equipments
DROP POLICY IF EXISTS "building_equipments_select_policy" ON public.building_equipments;
CREATE POLICY "building_equipments_select_policy"
    ON public.building_equipments
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "building_equipments_modify_policy" ON public.building_equipments;
CREATE POLICY "building_equipments_modify_policy"
    ON public.building_equipments
    FOR ALL
    TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- RLS: equipment_maintenance_tasks
DROP POLICY IF EXISTS "equipment_tasks_select_policy" ON public.equipment_maintenance_tasks;
CREATE POLICY "equipment_tasks_select_policy"
    ON public.equipment_maintenance_tasks
    FOR SELECT
    TO authenticated
    USING (
        public.is_staff_or_management()
        OR affects_service = true
    );

DROP POLICY IF EXISTS "equipment_tasks_modify_policy" ON public.equipment_maintenance_tasks;
CREATE POLICY "equipment_tasks_modify_policy"
    ON public.equipment_maintenance_tasks
    FOR ALL
    TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 5. TRIGGERS TỰ ĐỘNG CẬP NHẬT VÒNG ĐỜI THIẾT BỊ
CREATE OR REPLACE FUNCTION public.handle_equipment_task_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_eq RECORD;
    v_completed_time TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_eq FROM public.building_equipments WHERE id = NEW.equipment_id;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Trường hợp 1: Task hoàn thành -> cập nhật chu kỳ bảo dưỡng kế tiếp
    IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
        v_completed_time := COALESCE(NEW.actual_end, now());
        
        UPDATE public.building_equipments
        SET 
            last_maintenance_date = v_completed_time,
            next_maintenance_date = v_completed_time + (COALESCE(v_eq.maintenance_interval_days, 30) || ' days')::interval,
            status = 'operational',
            updated_at = now()
        WHERE id = NEW.equipment_id;

    -- Trường hợp 2: Task đang thực hiện và có ảnh hưởng dịch vụ -> chuyển sang under_maintenance
    ELSIF NEW.status = 'in_progress' AND NEW.affects_service = true THEN
        UPDATE public.building_equipments
        SET 
            status = 'under_maintenance',
            updated_at = now()
        WHERE id = NEW.equipment_id;

        -- Gửi thông báo gián đoạn dịch vụ tới cư dân tòa nhà đó
        INSERT INTO public.notifications (user_id, title, content, type, is_read, created_at)
        SELECT DISTINCT
            ra.user_id,
            '[Bảo trì] ' || v_eq.name || ' tạm ngưng phục vụ',
            COALESCE(NEW.service_interruption_note, 'Thiết bị ' || v_eq.name || ' tại ' || v_eq.building || ' đang được bảo trì từ ' || to_char(NEW.scheduled_start, 'HH24:MI DD/MM') || ' đến ' || to_char(NEW.scheduled_end, 'HH24:MI DD/MM') || '.'),
            'maintenance',
            false,
            now()
        FROM public.residents_apartments ra
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE v_eq.building = 'Toàn khu' OR a.building = v_eq.building;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_equipment_task_status_change ON public.equipment_maintenance_tasks;
CREATE TRIGGER trg_equipment_task_status_change
    AFTER INSERT OR UPDATE OF status, affects_service, actual_end
    ON public.equipment_maintenance_tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_equipment_task_status_change();

-- 6. RPC: LẤY DANH SÁCH THIẾT BỊ SẮP ĐẾN HẠN BẢO DƯỠNG (TRONG VÒNG 7 NGÀY)
CREATE OR REPLACE FUNCTION public.get_upcoming_maintenance_equipments(p_days_ahead INTEGER DEFAULT 7)
RETURNS SETOF public.building_equipments
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT *
    FROM public.building_equipments
    WHERE next_maintenance_date IS NOT NULL
      AND next_maintenance_date <= (now() + (p_days_ahead || ' days')::interval)
      AND status != 'inactive'
    ORDER BY next_maintenance_date ASC;
$$;

-- 7. SEED DỮ LIỆU MẪU BAN ĐẦU
INSERT INTO public.building_equipments (code, name, category, building, location, maintenance_interval_days, next_maintenance_date, status, specifications)
VALUES
    ('TM-A01', 'Thang máy chở khách A1', 'elevator', 'Tòa A', 'Trục lõi Block A (Tầng B2 - Tầng 25)', 30, now() + interval '5 days', 'operational', 'Tải trọng 1000kg (13 người), Tốc độ 2.5m/s, Hãng Mitsubishi'),
    ('TM-A02', 'Thang máy tải hàng / PCCC A2', 'elevator', 'Tòa A', 'Trục lõi Block A', 30, now() + interval '12 days', 'operational', 'Tải trọng 1600kg, Chuẩn chống cháy, Hãng Schindler'),
    ('PCCC-A01', 'Hệ thống chuông còi & đầu phun Spinkler Tòa A', 'fire_safety', 'Tòa A', 'Toàn bộ hành lang và tầng hầm Tòa A', 90, now() + interval '2 days', 'operational', 'Áp lực 12 bar, Trung tâm điều khiển Hochiki Nhật Bản'),
    ('MB-B01', 'Máy bơm tăng áp nước sinh hoạt B1', 'water_pump', 'Toàn khu', 'Phòng kỹ thuật nước Tầng hầm B2', 60, now() + interval '20 days', 'operational', 'Công suất 15kW, Lưu lượng 60m3/h, Hãng Grundfos'),
    ('MPD-01', 'Máy phát điện dự phòng Cummins 750kVA', 'generator', 'Toàn khu', 'Phòng máy phát Tầng hầm B2', 90, now() + interval '3 days', 'operational', 'Công suất 750kVA, Nhiên liệu Diesel, Khởi động tự động ATS trong 10s')
ON CONFLICT (code) DO NOTHING;
