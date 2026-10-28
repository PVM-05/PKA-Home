# Đặc Tả Thiết Kế: Khai Báo & Phê Duyệt Chỉ Số Điện Nước Thông Minh (Smart Meter Reading)

> **Tài liệu:** Design Specification  
> **Ngày lập:** 2026-10-05  
> **Mục tiêu:** Cung cấp giải pháp tương tác 2 chiều giữa Cư dân và Ban Quản Lý (Admin) trong việc khai báo chỉ số tiêu thụ điện - nước định kỳ. Tích hợp tính năng chụp ảnh công tơ làm bằng chứng minh bạch kèm cơ chế nhận diện mô phỏng thông minh (Smart OCR Demo) giúp tự động điền số liệu mượt mà, phục vụ tối ưu cho buổi bảo vệ đồ án.

---

## 1. Bối Cảnh & Yêu Cầu Nghiệp Vụ

### 1.1. Vấn đề giải quyết
- Trước đây, việc ghi nhận chỉ số điện nước hoặc được thực hiện thủ công bởi BQL đi từng tầng, hoặc BQL tự nhập vào hệ thống.
- Cư dân muốn chủ động khai báo chỉ số đồng hồ điện/nước của căn hộ mình, đồng thời có ảnh chụp công tơ thực tế làm bằng chứng để tránh sai sót, tranh chấp tiền điện nước.
- Ban quản lý cần một màn hình kiểm soát tập trung: xem ảnh chụp đối chiếu, phê duyệt chỉ số để tự động cập nhật vào căn hộ và lập tức phát hành hóa đơn tháng nếu cần.

### 1.2. Tiêu chí thành công
1. **100% Tiếng Việt chuẩn mực**: Toàn bộ giao diện, nhãn, thông báo và trạng thái không dùng tiếng Anh thô cứng.
2. **Không dùng Emoji**: Sử dụng icon Material chuẩn (`Icons.*`).
3. **Mã căn hộ chuẩn**: Luôn tuân thủ quy chuẩn `A0110` / `B0110`.
4. **Smart OCR Demo**: Khi cư dân chụp/tải ảnh công tơ, hệ thống hiển thị hiệu ứng "Đang nhận diện chỉ số qua ảnh..." trong ~1.2 giây và tự động điền giá trị $kWh$ hoặc $m^3$ vào ô nhập, cho phép người dùng kiểm tra và chỉnh sửa.
5. **Duyệt chỉ số & Tích hợp hóa đơn**: Khi BQL duyệt:
   - Cập nhật tức thời `apartments.electric_reading` và `apartments.water_reading`.
   - Có tùy chọn **[ Tạo ngay hóa đơn tháng ]** cho căn hộ vừa duyệt với đầy đủ các khoản: Phí quản lý, Điện, Nước, Xe gửi bãi.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & RPC (Supabase PostgreSQL)

### 2.1. Bảng `meter_reading_submissions`
```sql
CREATE TABLE IF NOT EXISTS public.meter_reading_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    period TEXT NOT NULL, -- Định dạng: '10/2026'
    electric_reading NUMERIC NOT NULL CHECK (electric_reading >= 0),
    water_reading NUMERIC NOT NULL CHECK (water_reading >= 0),
    electric_image_url TEXT,
    water_image_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reject_reason TEXT,
    reviewed_by UUID REFERENCES public.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.meter_reading_submissions ENABLE ROW LEVEL SECURITY;

-- Cư dân chỉ đọc và tạo dữ liệu cho căn hộ của mình
CREATE POLICY "Residents can view their apartment meter submissions"
    ON public.meter_reading_submissions FOR SELECT
    USING (
        apartment_id IN (
            SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('management', 'admin')
        )
    );

CREATE POLICY "Residents can insert meter submissions for their apartment"
    ON public.meter_reading_submissions FOR INSERT
    WITH CHECK (
        apartment_id IN (
            SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
        )
    );

-- BQL có quyền cập nhật trạng thái duyệt
CREATE POLICY "Management can update meter submissions"
    ON public.meter_reading_submissions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('management', 'admin')
        )
    );
```

### 2.2. RPC Phê duyệt chỉ số: `approve_meter_reading`
Hàm nguyên tử PostgreSQL nhận vào ID lượt gửi, cập nhật trạng thái `approved`, cập nhật chỉ số vào bảng `apartments`, và nếu `p_generate_invoice = true` thì tự động tính toán tiêu thụ phát hành hóa đơn cho căn hộ đó:
```sql
CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT FALSE,
    p_due_date DATE DEFAULT (CURRENT_DATE + INTERVAL '15 days')::DATE,
    p_mgmt_rate NUMERIC DEFAULT 10000,
    p_electric_rate NUMERIC DEFAULT 3000,
    p_water_rate NUMERIC DEFAULT 15000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_old_elec NUMERIC;
    v_old_water NUMERIC;
    v_area NUMERIC;
    v_invoice_id UUID;
    v_motorbike_count INT := 0;
    v_car_count INT := 0;
    v_total_amount NUMERIC := 0;
    v_elec_diff NUMERIC := 0;
    v_water_diff NUMERIC := 0;
    v_mgmt_fee NUMERIC := 0;
    v_parking_fee NUMERIC := 0;
BEGIN
    SELECT * INTO v_sub FROM public.meter_reading_submissions WHERE id = p_submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy bản ghi khai báo chỉ số.');
    END IF;

    -- Lấy chỉ số cũ & diện tích căn hộ
    SELECT COALESCE(electric_reading, 0), COALESCE(water_reading, 0), COALESCE(area, 60)
    INTO v_old_elec, v_old_water, v_area
    FROM public.apartments WHERE id = v_sub.apartment_id;

    -- Cập nhật chỉ số mới vào căn hộ
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- Cập nhật trạng thái duyệt
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- Nếu có yêu cầu tạo ngay hóa đơn tháng cho căn hộ này
    IF p_generate_invoice THEN
        v_elec_diff := GREATEST(0, v_sub.electric_reading - v_old_elec);
        v_water_diff := GREATEST(0, v_sub.water_reading - v_old_water);
        v_mgmt_fee := v_area * p_mgmt_rate;

        SELECT COUNT(*) FILTER (WHERE vehicle_type = 'motorbike' AND status = 'approved'),
               COUNT(*) FILTER (WHERE vehicle_type = 'car' AND status = 'approved')
        INTO v_motorbike_count, v_car_count
        FROM public.vehicles WHERE apartment_id = v_sub.apartment_id;

        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
        v_total_amount := v_mgmt_fee + (v_elec_diff * p_electric_rate) + (v_water_diff * p_water_rate) + v_parking_fee;

        -- Tạo hóa đơn
        INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status, created_at, updated_at)
        VALUES (v_sub.apartment_id, v_sub.period, p_due_date, v_total_amount, 'pending', now(), now())
        RETURNING id INTO v_invoice_id;

        -- Tạo chi tiết hóa đơn
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
        VALUES
            (v_invoice_id, 'Phí quản lý', p_mgmt_rate, v_area, v_mgmt_fee),
            (v_invoice_id, 'Tiền điện', p_electric_rate, v_elec_diff, v_elec_diff * p_electric_rate),
            (v_invoice_id, 'Tiền nước', p_water_rate, v_water_diff, v_water_diff * p_water_rate);

        IF v_parking_fee > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
            VALUES (v_invoice_id, 'Phí gửi xe', v_parking_fee, 1, v_parking_fee);
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Đã phê duyệt chỉ số và tự động tạo hóa đơn tháng!',
            'invoice_id', v_invoice_id
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã phê duyệt chỉ số thành công!');
END;
$$;
```

---

## 3. Kiến Trúc Tầng Ứng Dụng (Flutter & Riverpod)

### 3.1. Data Model: `MeterReadingSubmissionModel`
- File: `lib/data/models/meter_reading_submission_model.dart`
- Thuộc tính:
  - `id`, `apartmentId`, `apartmentCode`, `submittedBy`, `submitterName`.
  - `period`, `electricReading`, `waterReading`, `electricImageUrl`, `waterImageUrl`.
  - `status` (`pending`, `approved`, `rejected`), `rejectReason`, `reviewedAt`, `createdAt`.
  - Getters: `isPending`, `isApproved`, `isRejected`, `statusDisplayName`, `statusColor`.

### 3.2. Tiện ích Nhận diện Mô phỏng (Smart OCR Simulator)
- File: `lib/core/utils/meter_ocr_simulator.dart`
- Chức năng:
  - Khi người dùng chọn/chụp ảnh:
    - Nhận diện loại công tơ (`electric` hoặc `water`).
    - Tính toán số liệu giả lập dựa trên chỉ số cũ + lượng tiêu thụ trung bình hợp lý (VD: điện tăng $120\text{--}180\text{ kWh}$, nước tăng $8\text{--}15\text{ }m^3$).
    - Trả về kết quả sau độ trễ nhân tạo 1.2s kèm độ tin cậy "Độ chính xác 98.5%".
    - Cho phép cư dân hoàn toàn có thể chỉnh sửa lại số liệu trên form trước khi bấm gửi.

### 3.3. Repository & Provider
- File: `lib/data/repositories/meter_reading_repository.dart`
  - `submitReading(...)`
  - `getMySubmissions(String apartmentId)`
  - `getAllSubmissions({String? status})`
  - `approveReading(...)`
  - `rejectReading(...)`
- File: `lib/data/providers/meter_reading_provider.dart`
  - `meterReadingRepositoryProvider`
  - `myMeterReadingsProvider`
  - `allMeterReadingsProvider(String? status)`
  - `pendingMeterReadingsCountProvider`

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn hình Cư Dân: `ResidentMeterReadingScreen`
- Route: `/resident/meter-reading` (Thêm nút truy cập từ Thẻ Điện Nước trên `ResidentHomeScreen` hoặc nút tắt trên `ResidentInvoiceScreen`).
- Bố cục:
  1. **Khối Chỉ Số Hiện Tại (Kỳ Trước)**: Hiển thị chỉ số điện ($kWh$) và nước ($m^3$) đang được ghi nhận của căn hộ để cư dân đối chiếu.
  2. **Form Khai Báo Mới**:
     - Chọn/Chụp ảnh công tơ điện $\rightarrow$ Trình diễn hiệu ứng AI Scanning $\rightarrow$ Tự động điền số $kWh$.
     - Chọn/Chụp ảnh công tơ nước $\rightarrow$ Trình diễn hiệu ứng AI Scanning $\rightarrow$ Tự động điền số $m^3$.
     - Nút **[ Gửi Chỉ Số Điện Nước ]**.
  3. **Lịch Sử Khai Báo**:
     - Danh sách các kỳ đã gửi: Kỳ tháng, Ngày gửi, Trạng thái (`Chờ duyệt`, `Đã duyệt`, `Từ chối - Kèm lý do`).

### 4.2. Màn hình Ban Quản Lý: `ManagementMeterReadingScreen`
- Route: `/management/meter-readings` (Thêm nút truy cập nhanh từ Dashboard BQL).
- Bố cục:
  1. **Thanh Tab Trạng Thái**: `Chờ duyệt (kèm badge số lượng)`, `Đã duyệt`, `Đã từ chối`.
  2. **Danh sách thẻ yêu cầu**:
     - Mã căn hộ (VD: `A0110`), Tên cư dân khai báo, Ngày gửi.
     - So sánh: Chỉ số cũ $\rightarrow$ Chỉ số mới $\rightarrow$ Số tiêu thụ dự kiến.
     - Thu nhỏ ảnh chụp công tơ $\rightarrow$ Bấm vào mở hộp thoại phóng to ảnh để BQL đối chiếu số liệu thực tế.
  3. **Thao tác**:
     - Nút **[ Từ chối ]**: Mở dialog nhập lý do từ chối (ảnh mờ, số liệu bất thường).
     - Nút **[ Xác nhận ]**: Mở dialog duyệt, có Checkbox: `Tự động tạo hóa đơn tháng cho căn hộ này`.

---

## 5. Kế Hoạch Kiểm Thử Tự Động (Testing Strategy)

1. **Migration Test**: Kiểm tra cấu trúc bảng `meter_reading_submissions`, RLS policies và hàm RPC `approve_meter_reading`.
2. **Model Unit Test**: Kiểm tra chuyển đổi `fromJson`, `toJson` và các getters của `MeterReadingSubmissionModel`.
3. **OCR Simulator Test**: Kiểm tra hàm mô phỏng trích xuất số liệu từ ảnh trả về số liệu logic, lớn hơn chỉ số kỳ trước.
4. **Resident Widget Test**: Kiểm tra màn hình gửi chỉ số của cư dân, hiển thị scanning animation và gửi thành công.
5. **Management Widget Test**: Kiểm tra màn hình duyệt chỉ số của BQL, hiển thị ảnh công tơ và thao tác duyệt/từ chối thành công.

---

Tài liệu này là cơ sở duy nhất để lập kế hoạch triển khai chi tiết (`writing-plans`).
