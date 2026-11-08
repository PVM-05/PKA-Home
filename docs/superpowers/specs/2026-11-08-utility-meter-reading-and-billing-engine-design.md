# Đặc Tả Thiết Kế: Phân Hệ Chốt Chỉ Số Điện - Nước & Tự Động Lập Hóa Đơn Định Kỳ (Utility Meter Reading & Automated Billing Engine)

## 1. Bối Cảnh & Định Vị Thương Mại B2B SaaS
- **Sản phẩm:** PKA-Home (Commercial PropTech SaaS Platform).
- **Phân hệ:** Quản lý tiêu thụ Năng lượng/Tiện ích (Utility Meter Reading & Billing Cycle).
- **Đối tượng thụ hưởng:**
  - **Kỹ thuật viên / Nhân viên vận hành:** Cần công cụ di động thao tác nhanh chóng khi đi chốt số từng tầng, có cảnh báo chống nhập sai, chụp ảnh lưu vết.
  - **Kế toán / Quản lý tòa nhà:** Cần tự động hóa 100% việc tính toán chi phí (theo đơn giá cố định hoặc bậc thang), loại bỏ hoàn toàn việc tính toán thủ công trên Excel, chốt kỳ hóa đơn và phát hành hàng loạt chỉ với 1 click.
  - **Cư dân / Khách thuê:** Minh bạch số liệu tiêu thụ (số cũ, số mới, lượng dùng, hình ảnh đồng hồ thực tế), nhận thông báo hóa đơn và quét VietQR Napas 247 thanh toán ngay tức thì.

---

## 2. Kiến Trúc Dữ Liệu & Hợp Đồng ACID RPCs (PostgreSQL / Supabase)

### 2.1 Cấu Trúc Bảng CSDL
- **Bảng `building_utility_rates` (Cấu hình đơn giá điện nước tòa nhà):**
  - `id` (UUID PK)
  - `utility_type` (`electricity` | `water`)
  - `pricing_model` (`fixed` | `tiered_evn` | `tiered_water`)
  - `base_unit_price` (NUMERIC): Đơn giá cơ sở nếu dùng giá cố định (ví dụ: 3.500đ/kWh, 25.000đ/m³)
  - `vat_percentage` (NUMERIC DEFAULT 8.0 hoặc 10.0)
  - `environment_fee_percentage` (NUMERIC DEFAULT 10.0 cho nước)
  - `tiers` (JSONB): Mảng các bậc thang tiêu thụ nếu dùng bậc thang (from, to, unit_price).
  - `effective_from` (DATE), `is_active` (BOOLEAN).

- **Bổ sung cột trên `meter_reading_submissions`:**
  - `previous_electric_reading` (NUMERIC)
  - `previous_water_reading` (NUMERIC)
  - `electric_consumed` (NUMERIC GENERATED ALWAYS AS (electric_reading - COALESCE(previous_electric_reading, 0)) STORED)
  - `water_consumed` (NUMERIC GENERATED ALWAYS AS (water_reading - COALESCE(previous_water_reading, 0)) STORED)
  - `invoice_id` (UUID FK $\rightarrow$ `invoices.id`, NULLABLE)
  - `reader_id` (UUID FK $\rightarrow$ `users.id`, người đi chốt số)

### 2.2 Các ACID RPCs Cốt Lõi
1. `approve_meter_reading_and_generate_invoice`:
   - Tham số: `p_submission_id UUID`, `p_generate_invoice BOOLEAN DEFAULT true`, `p_due_date DATE DEFAULT NULL`.
   - Nghiệp vụ:
     - Khóa bản ghi `meter_reading_submissions` bằng `FOR UPDATE`.
     - Lấy chỉ số kỳ trước gần nhất của căn hộ nếu `previous_*` chưa có để tính `electric_consumed`, `water_consumed`.
     - Tính thành tiền điện và nước dựa trên cấu hình bảng giá.
     - Kiểm tra nếu kỳ đó (`period`) căn hộ đã có hóa đơn pending/draft: Bổ sung 2 dòng `invoice_items` (tiền điện, tiền nước) vào hóa đơn hiện có. Nếu chưa có: Tạo mới `invoices` và tạo `invoice_items`.
     - Cập nhật `meter_reading_submissions.status = 'approved'`, `invoice_id = v_invoice_id`.
     - Trả về JSONB chi tiết (invoice_id, total_amount, electric_cost, water_cost).

2. `batch_record_meter_readings`:
   - Tham số: `p_period TEXT`, `p_readings JSONB` (mảng các object `{apartment_id, electric_reading, water_reading, electric_image_url, water_image_url}`).
   - Nghiệp vụ: Duyệt ghi nhận hàng loạt cho kỹ thuật viên chốt số cả tầng, tự động kích hoạt trigger kiểm tra anomaly, ghi nhận tức thời.

3. `calculate_utility_charge`:
   - Hàm phụ trợ tính toán tiền điện/nước theo bậc thang lũy tiến hoặc đơn giá cố định.

---

## 3. Kiến Trúc Tầng Ứng Dụng (Flutter Feature-First & Riverpod)

### 3.1 Data Models Strongly-Typed
- `BuildingUtilityRateModel`: DTO cấu hình biểu giá điện nước tòa nhà.
- `UtilityCalculationResult`: DTO kết quả tính toán chi phí (tiêu thụ, đơn giá, thuế VAT, phí bảo vệ môi trường, tổng tiền).
- Nâng cấp `MeterReadingSubmissionModel`: Thêm `previousElectricReading`, `previousWaterReading`, `electricConsumed`, `waterConsumed`, `invoiceId`.

### 3.2 Repositories & Providers
- `MeterReadingRepository`:
  - `approveReading(submissionId, generateInvoice, dueDate)` gọi RPC mới.
  - `batchRecordReadings(period, readings)` phục vụ chốt số hàng loạt.
  - `getUtilityRates()` lấy cấu hình biểu giá.
- `utilityRatesProvider`, `unbilledMeterReadingsProvider`.

### 3.3 Giao Diện Trải Nghiệm (UI/UX)
1. **Ban Quản Lý & Kỹ Thuật Viên (`ManagementMeterReadingScreen`):**
   - **Thêm Tab "Trạm Chốt Số Nhanh" (Batch Meter Reader):** Cho phép kỹ thuật viên chọn Tầng, hiển thị danh sách các căn hộ với chỉ số cũ có sẵn, nhập chỉ số mới (hoặc bấm camera nhận diện OCR), hiển thị ngay lượng tiêu thụ chênh lệch và cảnh báo bất thường màu đỏ/vàng nếu đột biến.
   - **Hộp thoại Duyệt & Phát Hành Hóa Đơn Tự Động:** Tính toán trước số tiền điện, tiền nước dự kiến, hiển thị checkbox tạo hóa đơn kèm ngày đến hạn thanh toán, nhấn duyệt để gạch sổ và đồng bộ sang phân hệ kế toán.
2. **Cư Dân (`ResidentMeterReadingScreen`):**
   - Xem chi tiết minh bạch số cũ, số mới, lượng tiêu thụ trong kỳ.
   - Thấy liên kết trực tiếp đến Hóa đơn tháng kèm mã VietQR Napas 247 để chuyển khoản tức thì.

---

## 4. Kịch Bản Kiểm Thử & Tiêu Chuẩn Nghiệm Thu (QA / TDD)
- **Unit & Migration Tests:**
  - Test migration SQL tạo bảng biểu giá `building_utility_rates`, cập nhật cột tính tiêu thụ, RPC `approve_meter_reading_and_generate_invoice`.
  - Test tính toán tiền điện nước theo biểu giá cố định và bậc thang.
  - Test Models serialization/deserialization.
- **Repository Tests:**
  - Test gọi RPC duyệt sinh hóa đơn thành công và xử lý ngoại lệ.
- **Widget Tests:**
  - Test UI Trạm Chốt Số Nhanh theo tầng.
  - Test Hộp thoại phê duyệt và tùy chọn phát hành hóa đơn.
- **Static Analysis:**
  - `dart analyze lib test` đạt 0 issues.
- **Git Commit:** Commit trực tiếp trên `main`.
