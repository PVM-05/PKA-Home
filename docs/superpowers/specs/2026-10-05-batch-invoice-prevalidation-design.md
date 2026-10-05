# Đặc Tả Thiết Kế: Tạo Hóa Đơn Hàng Loạt Có Tiền Kiểm Tra Dữ Liệu & Chống Trùng Lặp

**Tác giả:** Antigravity  
**Ngày:** 05/10/2026  
**Trạng thái:** Chờ phê duyệt (Draft)  
**Phạm vi:** Phân hệ Tài chính - Ban Quản Lý (PKA-Home Management Financial Ecosystem)

---

## 1. Bối cảnh & Mục tiêu

### 1.1. Vấn đề thực tế
- Trong quy trình kế toán chung cư thực tế (280 căn hộ), việc bấm một nút tạo ngay 280 hóa đơn mà không qua kiểm tra dữ liệu dẫn đến nhiều sai sót nghiêm trọng:
  - Một số căn hộ chưa được nhập hoặc chưa duyệt chỉ số điện/nước tháng đó.
  - Một số căn hộ có chỉ số bất thường do ghi nhầm (chỉ số mới nhỏ hơn chỉ số cũ).
  - Nguy cơ tạo trùng lặp hóa đơn nếu Admin vô tình bấm tạo nhiều lần trong cùng một kỳ (`INV-A0110-202610-002`).
- Nếu vì 10 căn hộ có lỗi/thiếu số liệu mà dừng toàn bộ hệ thống, 270 căn hộ còn lại sẽ không thể phát hành hóa đơn đúng tiến độ.

### 1.2. Mục tiêu giải pháp
1. **Phân tách 2 giai đoạn rõ ràng**:
   - **Giai đoạn 1**: Thu thập & kiểm tra chỉ số công tơ điện nước (Smart Meter Reading).
   - **Giai đoạn 2**: Tiền kiểm tra (Pre-flight Validation / Dry-Run) $\rightarrow$ Phân loại dữ liệu $\rightarrow$ Phát hành hóa đơn hàng loạt cho các căn hợp lệ.
2. **Dashboard tiền kiểm tra (Pre-flight Dashboard)**:
   - 🟢 **Hợp lệ (Ready)**: Căn hộ đầy đủ chỉ số, mới $\ge$ cũ, chưa có hóa đơn kỳ này $\rightarrow$ Sẵn sàng tạo.
   - 🟡 **Thiếu dữ liệu (Missing)**: Căn hộ thiếu chỉ số điện hoặc nước kỳ này.
   - 🔴 **Bất thường (Anomaly/Invalid)**: Chỉ số mới < chỉ số cũ.
   - ⚪ **Đã lập hóa đơn (Already Invoiced)**: Căn hộ đã có hóa đơn kỳ này rồi $\rightarrow$ Không tạo lặp.
3. **Phát hành linh hoạt**:
   - Cho phép bấm **[ Tạo X hóa đơn hợp lệ ]** ngay lập tức cho các căn đủ điều kiện.
   - Giữ lại danh sách các căn chưa hợp lệ để BQL bổ sung/xử lý sau.
4. **Idempotency & Chống trùng lặp tuyệt đối**:
   - Khóa ràng buộc duy nhất trên `(apartment_id, period)`.
   - RPC tự động bỏ qua nếu hóa đơn kỳ đó đã tồn tại, không bao giờ sinh thêm hóa đơn trùng lặp.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & RPCs

### 2.1. Ràng buộc toàn vẹn dữ liệu (Constraint)
- Bổ sung Unique Constraint trên bảng `public.invoices`:
  ```sql
  ALTER TABLE public.invoices 
  ADD CONSTRAINT uq_invoices_apartment_period UNIQUE (apartment_id, period);
  ```
  *(Nếu đã có dữ liệu trùng trong môi trường dev, dọn dẹp các bản ghi trùng trước khi áp dụng).*

### 2.2. RPC 1: Tiền kiểm tra dữ liệu (`validate_monthly_bulk_invoices`)
- **Tên hàm**: `public.validate_monthly_bulk_invoices`
- **Mục đích**: Chạy Dry-Run giả lập, kiểm tra và phân loại 280 căn hộ, **không ghi dữ liệu**.
- **Tham số vào**:
  - `p_period` (`text`): Kỳ hóa đơn (VD: `'10/2026'` hoặc `'Tháng 10/2026'`).
  - `p_mgmt_rate` (`numeric` DEFAULT 10000): Đơn giá quản lý ($đ/m^2$).
  - `p_electric_rate` (`numeric` DEFAULT 3500): Đơn giá điện ($đ/kWh$).
  - `p_water_rate` (`numeric` DEFAULT 18000): Đơn giá nước ($đ/m^3$).
- **Logic kiểm tra**:
  1. Lấy danh sách căn hộ đang có người ở (`apartments.is_empty = false`).
  2. Kiểm tra `invoices` xem căn hộ đã có hóa đơn kỳ `p_period` chưa. Nếu có $\rightarrow$ Phân loại `ALREADY_INVOICED`.
  3. Lấy chỉ số điện nước tháng này:
     - Ưu tiên: `meter_reading_submissions` có `period = p_period` và `status = 'approved'`.
     - Kế tiếp: `apartments.electric_reading` và `apartments.water_reading`.
  4. Lấy chỉ số kỳ trước (từ hóa đơn kỳ trước hoặc cột lưu trữ).
  5. Đánh giá:
     - Nếu thiếu điện hoặc nước $\rightarrow$ Phân loại `MISSING_DATA` kèm thông điệp (VD: `Chưa có chỉ số nước`).
     - Nếu chỉ số mới < chỉ số cũ $\rightarrow$ Phân loại `INVALID_READING` kèm thông điệp (VD: `Chỉ số điện mới (1250) < chỉ số cũ (1300)`).
     - Nếu hợp lệ $\rightarrow$ Phân loại `VALID`, tính tạm:
       - Phí quản lý = `area * p_mgmt_rate`
       - Phí gửi xe = xe máy * 100k + ô tô * 1.2M
       - Tiền điện = tiêu thụ điện * `p_electric_rate`
       - Tiền nước = tiêu thụ nước * `p_water_rate`
       - Tổng tiền tạm tính.
- **Dữ liệu trả về (JSON)**:
  ```json
  {
    "period": "10/2026",
    "total_scanned": 280,
    "valid_count": 270,
    "missing_count": 7,
    "invalid_count": 3,
    "already_invoiced_count": 0,
    "total_estimated_amount": 395000000,
    "valid_items": [
      {
        "apartment_id": "uuid",
        "apartment_code": "A0110",
        "area": 75.5,
        "electric_usage": 140,
        "water_usage": 11,
        "estimated_total": 1480000
      }
    ],
    "issues": [
      {
        "apartment_id": "uuid",
        "apartment_code": "A0105",
        "type": "MISSING_DATA",
        "message": "Chưa có chỉ số nước kỳ 10/2026"
      },
      {
        "apartment_id": "uuid",
        "apartment_code": "A0203",
        "type": "INVALID_READING",
        "message": "Chỉ số điện mới (1250 kWh) nhỏ hơn chỉ số cũ (1300 kWh)"
      }
    ]
  }
  ```

### 2.3. RPC 2: Phát hành hóa đơn các căn hợp lệ (`generate_valid_bulk_invoices`)
- **Tên hàm**: `public.generate_valid_bulk_invoices`
- **Mục đích**: Tạo hóa đơn và các dòng khoản mục cho các căn hộ hợp lệ trong một TRANSACTION nguyên tử.
- **Tham số vào**:
  - `p_period` (`text`)
  - `p_due_date` (`timestamptz`)
  - `p_mgmt_rate` (`numeric`)
  - `p_electric_rate` (`numeric`)
  - `p_water_rate` (`numeric`)
  - `p_target_apartment_ids` (`uuid[]` DEFAULT NULL): Danh sách ID căn hộ hợp lệ muốn phát hành (nếu NULL thì tự động phát hành toàn bộ các căn hợp lệ sau khi validate).
- **Quy tắc an toàn**:
  - `ON CONFLICT (apartment_id, period) DO NOTHING`: Tuyệt đối không sinh lỗi duplicate và không tạo bản ghi đè.
  - Tự động chèn thông báo hệ thống vào bảng `public.notifications` gửi đến các cư dân liên kết với căn hộ đó.
- **Kết quả trả về**:
  - `invoices_created`: Số lượng hóa đơn được tạo mới thực tế.
  - `total_amount`: Tổng doanh thu phát hành.
  - `skipped_count`: Số lượng căn bị bỏ qua do đã có hóa đơn hoặc có lỗi.

---

## 3. Thiết Kế Giao Diện Người Dùng (UI/UX)

Nâng cấp widget [`BulkInvoiceDialog`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/widgets/bulk_invoice_dialog.dart) thành **Hộp thoại Tiền Kiểm Tra & Phát Hành Hóa Đơn 2 Bước (Pre-flight Billing Dialog)**:

### 3.1. Bước 1: Cấu hình Kỳ & Biểu phí
- Nhập kỳ hóa đơn (mặc định: tháng hiện tại `10/2026`).
- Chọn hạn thanh toán (mặc định: +15 ngày).
- Đơn giá: Phí quản lý ($10.000 đ/m^2$), Điện ($3.500 đ/kWh$), Nước ($18.000 đ/m^3$).
- Nút bấm chính: **[ Kiểm Tra Dữ Liệu ]** (kèm icon `Icons.fact_check_outlined`).

### 3.2. Bước 2: Bảng Điều Khiển Tiền Kiểm Tra (Pre-flight Dashboard)
- **Thống kê 4 khối (Summary Badges)**:
  - 🟢 **270 Căn Hợp Lệ**: Sẵn sàng tạo hóa đơn (Tổng dự thu: ~395.000.000 đ).
  - 🟡 **7 Căn Thiếu Số**: Cần thu thập bổ sung.
  - 🔴 **3 Căn Bất Thường**: Cần kiểm tra lại công tơ.
  - ⚪ **0 Căn Đã Có HĐ**: Bỏ qua tránh trùng lặp.
- **Tabs xem chi tiết**:
  - Tab 1: **Căn hợp lệ (270)** — Danh sách dạng cuộn: Mã căn, Tiêu thụ điện/nước, Số tiền dự kiến.
  - Tab 2: **Cần xử lý (10)** — Danh sách các căn thiếu số hoặc bất thường, hiển thị rõ badge lỗi màu vàng/đỏ và mô tả chi tiết nguyên nhân.
- **Hành động**:
  - Nút phụ: **[ Quay lại cấu hình ]**
  - Nút chính: **[ Tạo 270 Hóa Đơn Hợp Lệ ]** (Nổi bật, màu `AppTheme.primary`).
  - Ghi chú minh bạch: *"10 căn hộ có vấn đề sẽ được giữ lại để bổ sung chỉ số sau. 270 căn hợp lệ sẽ được tạo hóa đơn ngay."*

### 3.3. Bước 3: Thông báo kết quả phát hành
- Banner thành công: *"Đã phát hành thành công 270 hóa đơn kỳ 10/2026 với tổng dự thu 395.200.000 đ!"*
- Tự động làm mới danh sách hóa đơn trên màn hình `InvoiceManagementScreen`.

---

## 4. Kiểm Thử & Tiêu Chí Nghiệm Thu (Acceptance Criteria)

1. **Test Backend RPCs**:
   - Kiểm tra `validate_monthly_bulk_invoices`:
     - Test case căn đủ điều kiện $\rightarrow$ phân loại `VALID`.
     - Test case căn thiếu chỉ số $\rightarrow$ phân loại `MISSING_DATA`.
     - Test case căn có chỉ số mới < cũ $\rightarrow$ phân loại `INVALID_READING`.
     - Test case căn đã có hóa đơn kỳ đó $\rightarrow$ phân loại `ALREADY_INVOICED`.
   - Kiểm tra `generate_valid_bulk_invoices`:
     - Tạo đúng số lượng hóa đơn hợp lệ.
     - Chạy lại lần 2 cùng kỳ $\rightarrow$ `invoices_created = 0`, không crash, không sinh duplicate.
2. **Test Frontend Widget**:
   - `bulk_invoice_dialog_test.dart`:
     - Test chuyển đổi giữa Bước 1 (Cấu hình) $\rightarrow$ Bước 2 (Kết quả tiền kiểm tra).
     - Test hiển thị đúng 4 nhóm phân loại (Hợp lệ, Thiếu số, Bất thường, Đã có).
     - Test bấm nút [ Tạo hóa đơn hợp lệ ] gọi đúng repository và hiển thị thông báo thành công.
3. **Tuân thủ quy chuẩn dự án**:
   - 100% tiếng Việt chuẩn mực.
   - Không Emoji, dùng Material Icons (`Icons.fact_check_outlined`, `Icons.check_circle_outline`, `Icons.warning_amber_rounded`, `Icons.error_outline`).
   - `dart analyze`: 0 errors, 0 warnings.
   - 100% test suite pass.
