-- ====================================================================
-- MIGRATION: 20261102_02_issue_sla_and_materials.sql
-- GIAI ĐOẠN D3: Cảnh báo SLA đa tầng, phân công chuyên môn và kho vật tư sự cố
-- ====================================================================

-- 1. Mở rộng bảng issue_reports với các cột SLA và category
ALTER TABLE issue_reports
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS sla_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS sla_status TEXT NOT NULL DEFAULT 'on_time';

-- Thêm check constraint cho category và sla_status nếu chưa có
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_issue_reports_category'
    ) THEN
        ALTER TABLE issue_reports
        ADD CONSTRAINT chk_issue_reports_category
        CHECK (category IN ('electrical', 'plumbing', 'construction', 'elevator', 'fire_safety', 'other'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_issue_reports_sla_status'
    ) THEN
        ALTER TABLE issue_reports
        ADD CONSTRAINT chk_issue_reports_sla_status
        CHECK (sla_status IN ('on_time', 'warning', 'breached'));
    END IF;
END $$;

-- 2. Trigger function tự động tính toán sla_deadline và cập nhật sla_status
CREATE OR REPLACE FUNCTION fn_calculate_issue_sla()
RETURNS TRIGGER AS $$
BEGIN
    -- Khi tạo mới sự cố: Tính sla_deadline nếu chưa được cấu hình tường minh
    IF TG_OP = 'INSERT' THEN
        IF NEW.sla_deadline IS NULL THEN
            IF NEW.priority = 'high' THEN
                NEW.sla_deadline := COALESCE(NEW.created_at, NOW()) + INTERVAL '2 hours';
            ELSIF NEW.priority = 'medium' THEN
                NEW.sla_deadline := COALESCE(NEW.created_at, NOW()) + INTERVAL '24 hours';
            ELSE
                NEW.sla_deadline := COALESCE(NEW.created_at, NOW()) + INTERVAL '72 hours';
            END IF;
        END IF;
        NEW.sla_status := 'on_time';
    END IF;

    -- Khi cập nhật sự cố
    IF TG_OP = 'UPDATE' THEN
        -- Ghi nhận thời điểm tiếp nhận khi chuyển sang in_progress
        IF NEW.status = 'in_progress' AND (OLD.status = 'pending' OR OLD.status IS NULL) AND NEW.acknowledged_at IS NULL THEN
            NEW.acknowledged_at := NOW();
        END IF;

        -- Ghi nhận thời điểm giải quyết khi chuyển sang resolved
        IF NEW.status = 'resolved' AND (OLD.status != 'resolved' OR OLD.status IS NULL) AND NEW.resolved_at IS NULL THEN
            NEW.resolved_at := NOW();
        END IF;

        -- Đánh giá trạng thái SLA
        IF NEW.resolved_at IS NOT NULL THEN
            IF NEW.resolved_at > NEW.sla_deadline THEN
                NEW.sla_status := 'breached';
            ELSE
                NEW.sla_status := 'on_time';
            END IF;
        ELSIF NEW.status != 'resolved' THEN
            IF NOW() > NEW.sla_deadline THEN
                NEW.sla_status := 'breached';
            ELSIF NOW() + INTERVAL '2 hours' >= NEW.sla_deadline THEN
                NEW.sla_status := 'warning';
            ELSE
                NEW.sla_status := 'on_time';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_issue_sla ON issue_reports;
CREATE TRIGGER trg_calculate_issue_sla
    BEFORE INSERT OR UPDATE ON issue_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_calculate_issue_sla();

-- 3. Tạo bảng kho vật tư tiêu hao maintenance_materials
CREATE TABLE IF NOT EXISTS maintenance_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'other',
    unit TEXT NOT NULL DEFAULT 'cái',
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    stock_quantity INT NOT NULL DEFAULT 0,
    min_stock_alert INT NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_material_code UNIQUE (building_id, code)
);

ALTER TABLE maintenance_materials ENABLE ROW LEVEL SECURITY;

-- Policy RLS cho maintenance_materials
DROP POLICY IF EXISTS "Public authenticated users can read materials" ON maintenance_materials;
CREATE POLICY "Public authenticated users can read materials"
    ON maintenance_materials FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Management and technicians can manage materials" ON maintenance_materials;
CREATE POLICY "Management and technicians can manage materials"
    ON maintenance_materials FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'management', 'technician')
        )
    );

-- 4. Tạo bảng chi tiết vật tư sử dụng cho sự cố issue_materials
CREATE TABLE IF NOT EXISTS issue_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL REFERENCES issue_reports(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES maintenance_materials(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    is_chargeable BOOLEAN NOT NULL DEFAULT false,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE issue_materials ENABLE ROW LEVEL SECURITY;

-- Policy RLS cho issue_materials
DROP POLICY IF EXISTS "Users can read materials of their apartment issues" ON issue_materials;
CREATE POLICY "Users can read materials of their apartment issues"
    ON issue_materials FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM issue_reports ir
            JOIN residents_apartments ra ON ra.apartment_id = ir.apartment_id
            WHERE ir.id = issue_materials.issue_report_id
            AND ra.user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'management', 'technician')
        )
    );

DROP POLICY IF EXISTS "Staff can insert issue materials" ON issue_materials;
CREATE POLICY "Staff can insert issue materials"
    ON issue_materials FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role IN ('admin', 'management', 'technician')
        )
    );

-- 5. RPC thống kê SLA sự cố: get_issue_sla_stats
CREATE OR REPLACE FUNCTION get_issue_sla_stats(p_building_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_on_time INT := 0;
    v_warning INT := 0;
    v_breached INT := 0;
    v_compliance_rate NUMERIC(5, 2) := 100.00;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE sla_status = 'on_time'),
        COUNT(*) FILTER (WHERE sla_status = 'warning'),
        COUNT(*) FILTER (WHERE sla_status = 'breached')
    INTO v_total, v_on_time, v_warning, v_breached
    FROM issue_reports ir
    JOIN apartments apt ON apt.id = ir.apartment_id
    WHERE (p_building_id IS NULL OR apt.building_id = p_building_id);

    IF v_total > 0 THEN
        v_compliance_rate := ROUND(((v_on_time + v_warning)::NUMERIC / v_total::NUMERIC) * 100.0, 2);
    END IF;

    RETURN jsonb_build_object(
        'total_issues', v_total,
        'on_time_count', v_on_time,
        'warning_count', v_warning,
        'breached_count', v_breached,
        'compliance_rate', v_compliance_rate
    );
END;
$$;

-- 6. RPC xuất kho vật tư và ghi nhận vào sự cố: record_issue_materials_usage
CREATE OR REPLACE FUNCTION record_issue_materials_usage(
    p_issue_id UUID,
    p_materials JSONB,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item JSONB;
    v_material_id UUID;
    v_qty INT;
    v_is_chargeable BOOLEAN;
    v_note TEXT;
    v_current_stock INT;
    v_unit_price NUMERIC(12, 2);
    v_total_amount NUMERIC(12, 2);
    v_total_items INT := 0;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_materials)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 1);
        v_is_chargeable := COALESCE((v_item->>'is_chargeable')::BOOLEAN, false);
        v_note := v_item->>'note';

        -- Khóa và kiểm tra tồn kho
        SELECT stock_quantity, unit_price INTO v_current_stock, v_unit_price
        FROM maintenance_materials
        WHERE id = v_material_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Vật tư với ID % không tồn tại trong kho', v_material_id;
        END IF;

        IF v_current_stock < v_qty THEN
            RAISE EXCEPTION 'Không đủ tồn kho cho vật tư % (Hiện còn: %, Yêu cầu: %)', v_material_id, v_current_stock, v_qty;
        END IF;

        v_total_amount := v_unit_price * v_qty;

        -- Trừ tồn kho
        UPDATE maintenance_materials
        SET stock_quantity = stock_quantity - v_qty,
            updated_at = NOW()
        WHERE id = v_material_id;

        -- Thêm vào bản ghi nhật ký vật tư sự cố
        INSERT INTO issue_materials (
            issue_report_id,
            material_id,
            quantity,
            unit_price,
            total_amount,
            is_chargeable,
            note
        ) VALUES (
            p_issue_id,
            v_material_id,
            v_qty,
            v_unit_price,
            v_total_amount,
            v_is_chargeable,
            v_note
        );

        v_total_items := v_total_items + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã xuất kho và ghi nhận vật tư thành công',
        'items_recorded', v_total_items
    );
END;
$$;

-- 7. RPC kết chuyển vật tư tính phí vào hóa đơn: charge_issue_materials_to_invoice
CREATE OR REPLACE FUNCTION charge_issue_materials_to_invoice(
    p_issue_id UUID,
    p_invoice_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_total_charged NUMERIC(12, 2) := 0;
    v_lines_count INT := 0;
BEGIN
    FOR v_item IN
        SELECT im.id, im.quantity, im.unit_price, im.total_amount, mm.name AS material_name
        FROM issue_materials im
        JOIN maintenance_materials mm ON mm.id = im.material_id
        WHERE im.issue_report_id = p_issue_id
          AND im.is_chargeable = true
    LOOP
        INSERT INTO invoice_items (
            invoice_id,
            fee_type,
            unit_price,
            quantity,
            subtotal,
            description
        ) VALUES (
            p_invoice_id,
            'service',
            v_item.unit_price,
            v_item.quantity,
            v_item.total_amount,
            'Vật tư sửa chữa sự cố: ' || v_item.material_name
        );

        v_total_charged := v_total_charged + v_item.total_amount;
        v_lines_count := v_lines_count + 1;
    END LOOP;

    -- Cập nhật lại total_amount trên hóa đơn
    UPDATE invoices
    SET total_amount = total_amount + v_total_charged,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã kết chuyển vật tư vào hóa đơn thành công',
        'lines_added', v_lines_count,
        'total_charged', v_total_charged
    );
END;
$$;

-- 8. Thêm dữ liệu mẫu vào kho vật tư nếu chưa có
INSERT INTO maintenance_materials (building_id, code, name, category, unit, unit_price, stock_quantity, min_stock_alert)
VALUES
    (NULL, 'MAT-ELEC-01', 'Bóng đèn LED Rạng Đông 18W', 'electrical', 'cái', 65000, 45, 10),
    (NULL, 'MAT-ELEC-02', 'Aptomat tép Schneider 1P 20A', 'electrical', 'cái', 120000, 20, 5),
    (NULL, 'MAT-ELEC-03', 'Dây điện đôi Cadivi 2x2.5mm', 'electrical', 'mét', 18000, 150, 30),
    (NULL, 'MAT-PLUMB-01', 'Van bi đồng Miha D21', 'plumbing', 'cái', 85000, 25, 8),
    (NULL, 'MAT-PLUMB-02', 'Dây cấp nước bồn cầu inox 304', 'plumbing', 'sợi', 45000, 30, 10),
    (NULL, 'MAT-PLUMB-03', 'Keo dán ống PVC Bình Minh 500g', 'plumbing', 'hộp', 55000, 12, 4),
    (NULL, 'MAT-CONST-01', 'Keo silicone Apolo A500', 'construction', 'chai', 58000, 35, 10),
    (NULL, 'MAT-CONST-02', 'Khóa tay gạt cửa thông phòng Hafele', 'construction', 'bộ', 380000, 8, 3),
    (NULL, 'MAT-ELEV-01', 'Đèn chiếu sáng cabin thang máy LED 12V', 'elevator', 'bộ', 220000, 6, 2),
    (NULL, 'MAT-FIRE-01', 'Đầu phun sprinkler chữa cháy quay xuống', 'fire_safety', 'cái', 75000, 15, 5)
ON CONFLICT DO NOTHING;
