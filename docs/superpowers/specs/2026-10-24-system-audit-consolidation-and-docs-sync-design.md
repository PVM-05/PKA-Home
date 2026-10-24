# Đặc Tả Thiết Kế: Đồng Bộ & Chuẩn Hóa Toàn Diện Hệ Thống (PKA-Home Audit Remediation)

## 1. Mục Tiêu & Phạm Vi
- **Mục tiêu:** Khắc phục triệt để 40 lỗi tồn đọng từ đợt rà soát mã nguồn (ưu tiên toàn bộ P0, P1 và các điểm P2 trọng yếu), loại bỏ hoàn toàn tình trạng xung đột migration CSDL, chuẩn hóa 100% email tài khoản demo về tên miền `@gmail.com`, và đồng bộ toàn bộ tài liệu dự án trong thư mục `docs/` khớp hoàn toàn với kiến trúc và schema thực tế.
- **Phạm vi xử lý:**
  1. **Cơ sở dữ liệu (Supabase/PostgreSQL):** Tạo bản migration hợp nhất `20261024_01_system_audit_consolidation.sql` định nghĩa chuẩn tắc và duy nhất cho các RPC `simulate_unified_payment`, `book_amenity_slot`, `generate_valid_bulk_invoices`, `approve_meter_reading`, `reject_meter_reading`, `record_manual_payment`, `validate_monthly_bulk_invoices`, `create_invoice_with_items`. Xóa bỏ các trigger trùng lặp.
  2. **Dữ liệu mẫu (`seed.sql`):** Khử trùng lặp biển số xe, đảm bảo 40 phương tiện độc bản hợp lệ, loại bỏ lệnh vô hiệu hóa trigger `trg_check_vehicle_limits`, chuẩn hóa toàn bộ email về `@gmail.com` với mật khẩu chung `PkaHome@2026`.
  3. **Mã nguồn Client (Flutter/Dart):** Xử lý luồng `pending_payment` trên màn hình đặt tiện ích, sửa biến `guestsCount` trong dialog, sửa phím tắt FocusNode trong `OtpInputBoxes`, đóng thẻ XML trong `ios/Runner/Info.plist`, loại bỏ `.env` khỏi `pubspec.yaml` assets.
  4. **Tài liệu dự án (`docs/`):** Cập nhật `ERD.dbml`, `test-plan.md`, `RLS-policy.md`, `bao-cao-tien-do-tuan 1.md`, `errors.md`, `demo_accounts.md` khớp 100% thực tế.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & RPC Chuẩn Tắc

### 2.1. RPC `simulate_unified_payment`
- **Chữ ký chuẩn:** `public.simulate_unified_payment(p_payment_type text, p_reference_id uuid, p_payment_method text DEFAULT 'DEMO'::text)`
- **Logic:**
  - Nhận diện `p_payment_type`: `'INVOICE'` hoặc `'SERVICE'`.
  - Nhánh `SERVICE`: Kiểm tra bảng `amenity_bookings` qua cột `booked_by` (không dùng `user_id`), xác thực quyền `auth.uid() = booked_by` hoặc người cùng căn hộ hoặc thuộc role BQL (`'admin'`, `'management'`).
  - Trả về JSON:
    - Nếu là phương thức trực tiếp / tiền mặt chờ duyệt: chuyển booking sang `pending_payment` hoặc giữ pending, tạo bản ghi `payment_transactions` với `status = 'PENDING'`, trả về `is_pending: true`.
    - Nếu thành công ngay (khi BQL ghi nhận hoặc demo thành công): `status = 'SUCCESS'`, cập nhật booking sang `confirmed`, hóa đơn sang `paid`.

### 2.2. RPC `book_amenity_slot`
- **Chữ ký chuẩn:**
  ```sql
  public.book_amenity_slot(
      p_amenity_id UUID,
      p_booking_date DATE,
      p_time_slot VARCHAR,
      p_guests_count INT DEFAULT 1,
      p_apartment_id UUID DEFAULT NULL,
      p_allow_waitlist BOOLEAN DEFAULT TRUE,
      p_notes TEXT DEFAULT NULL
  ) RETURNS JSONB
  ```
- **Kiểm soát sức chứa:**
  - Tiện ích độc quyền (`exclusive`): Đếm số booking đang active (`confirmed`, `pending_payment`). Nếu > 0 và `p_allow_waitlist = true` -> vào `waitlist`.
  - Tiện ích dùng chung (`shared`): Tính tổng số người:
    ```sql
    SELECT COALESCE(SUM(guests_count), 0) INTO v_current_guests
    FROM public.amenity_bookings
    WHERE amenity_id = p_amenity_id 
      AND booking_date = p_booking_date 
      AND time_slot = p_time_slot 
      AND status IN ('confirmed', 'pending_payment');
    
    IF (v_current_guests + p_guests_count) > v_amenity.max_capacity THEN
        IF p_allow_waitlist THEN v_status := 'waitlist'; ELSE RAISE EXCEPTION ...; END IF;
    END IF;
    ```
  - Chèn bản ghi với đúng cột `booked_by = auth.uid()`, `fee_amount`, `deposit_amount`.

### 2.3. RPC `generate_valid_bulk_invoices`
- **Chữ ký chuẩn:**
  ```sql
  public.generate_valid_bulk_invoices(
      p_period text,
      p_due_date date,
      p_mgmt_rate numeric DEFAULT 16500,
      p_electric_rate numeric DEFAULT 3500,
      p_water_rate numeric DEFAULT 18000,
      p_target_apartment_ids UUID[] DEFAULT NULL
  ) RETURNS JSONB
  ```
- Trạng thái hóa đơn tạo mới bắt buộc là `'unpaid'` (thuộc enum `invoice_status`).

### 2.4. RPC `approve_meter_reading` & `reject_meter_reading`
- `approve_meter_reading(p_submission_id UUID, p_generate_invoice BOOLEAN DEFAULT FALSE, p_due_date DATE DEFAULT NULL)`: Trạng thái hóa đơn tự động sinh là `'unpaid'`.
- `reject_meter_reading(p_submission_id UUID, p_reason TEXT DEFAULT 'Chỉ số không hợp lệ hoặc ảnh mờ')`.

### 2.5. Bảo Mật RPC & Dọn Dẹp Trigger
- `validate_monthly_bulk_invoices`: Thêm kiểm tra `IF NOT public.is_admin_or_accountant() THEN RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền thực hiện'; END IF;`.
- `get_amenity_bookings`: `REVOKE ALL ON FUNCTION public.get_amenity_bookings(UUID, DATE) FROM PUBLIC, anon; GRANT EXECUTE ... TO authenticated;`.
- Xóa trigger cũ: `trg_notify_on_issue_status_change`, `trg_notify_on_issue_lifecycle`, giữ lại duy nhất `trg_notify_on_issue_event`.
- Xóa trigger bảo trì thiết bị cũ `trg_notify_equipment_task_status`, chỉ giữ `trg_notify_on_equipment_maintenance`.

---

## 3. Thiết Kế Client (Flutter / Dart)

1. **`amenity_booking_screen.dart` & `amenity_booking_model.dart`:**
   - Bổ sung `isPendingPayment` vào danh sách trạng thái hiển thị của thẻ lịch đặt (Badge vàng cam: "Chờ thanh toán").
   - Thêm nút "Thanh toán ngay" mở `UnifiedPaymentSheet` và nút "Hủy lịch" cho trạng thái `pending_payment`.
   - Trong dialog đặt chỗ: tách `int dialogGuestsCount = guestsCount;` làm biến trạng thái cục bộ của `StatefulBuilder`, không thao tác trực tiếp lên tham số hàm.
2. **`amenity_booking_repository.dart`:**
   - Trong `getBookingsByAmenityAndDate`: sửa bộ lọc `.inFilter('status', ['confirmed', 'waitlist', 'pending_payment'])` để phản ánh đúng số chỗ đã giữ trên UI.
3. **`resident_360_detail_sheet.dart`:**
   - Sửa truy cập `(b['building_amenities'] as Map?)?['name'] ?? 'Tiện ích'` khớp với câu truy vấn Supabase.
4. **`otp_input_boxes.dart`:**
   - Khởi tạo danh sách `late List<FocusNode> _keyboardFocusNodes` trong `initState()` và `dispose()` đúng chu kỳ, không tạo `FocusNode()` mới trong hàm `build()`.
5. **`pubspec.yaml` & `ios/Runner/Info.plist`:**
   - Gỡ `- .env` khỏi `assets:`, giữ lại `- .env.example`.
   - Thêm thẻ đóng `</array>` cho `UISupportedInterfaceOrientations~ipad` trong `Info.plist`.

---

## 4. Đồng Bộ Tài Liệu Dự Án (`docs/`)

1. **Chuẩn hóa Email:**
   - Chuyển toàn bộ các email trong `docs/test-plan.md` từ `@pka.vn` sang `@gmail.com`:
     - `pkahome.admin@gmail.com`
     - `pkahome.ketoan@gmail.com`
     - `pkahome.kythuat@gmail.com`
     - `cudan.a0101@gmail.com`, `cudan.b0101@gmail.com`, `cudan.c0101@gmail.com`, `test1@gmail.com`
   - Cập nhật mật khẩu chuẩn `PkaHome@2026`.
2. **`docs/ERD.dbml`:**
   - Sửa tên bảng `amenities` -> `building_amenities`.
   - Bổ sung bảng `amenity_maintenance_windows`, `user_fcm_tokens`.
   - Bổ sung các cột thực tế: `fee_amount`, `deposit_amount`, `deposit_status`, `deposit_notes`, `checked_in_at` trên `amenity_bookings`.
   - Cập nhật cột bảng `vehicles`: `user_id`, `plate_number`, `license_plate`, `brand_model`.
   - Cập nhật enum `payment_transactions.status`: `PENDING`, `SUCCESS`, `FAILED`, `CANCELLED`.
3. **`docs/RLS-policy.md`:**
   - Cập nhật Storage Bucket `issue-images`: Chuyển quyền SELECT thành Authenticated Read Access khớp với migration `20261011_06`.
4. **`docs/bao-cao-tien-do-tuan 1.md`:**
   - Sửa phương thức thanh toán: VietQR / Chuyển khoản ngân hàng / Tiền mặt (loại bỏ MoMo/ZaloPay).
   - Cập nhật tiến độ BQL đạt 100%.
5. **`docs/errors.md`:**
   - Bổ sung đầy đủ các lỗi cốt lõi đã điều tra và khắc phục trong đợt kiểm thử.
