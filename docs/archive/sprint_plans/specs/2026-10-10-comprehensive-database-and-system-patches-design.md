# Thiết Kế Chi Tiết: Khắc Phục Toàn Diện Lỗi CSDL, Migration, Bảo Mật và Client Flutter

**Mã tài liệu:** `SPEC-2026-10-10-SYSTEM-PATCHES`  
**Ngày lập:** 10/10/2026  
**Trạng thái:** Đã thống nhất thiết kế  

---

## 1. Mục Tiêu & Phạm Vi
Bản thiết kế này giải quyết triệt để 2 nhóm lỗi cốt lõi đã được kiểm chứng và rà soát:
1. **Nhóm CSDL, Migration & Bảo mật (Supabase / PostgreSQL):**
   - Lỗi PostgreSQL 42P13 khi `CREATE OR REPLACE reject_meter_reading` đổi tên tham số (`p_reason` -> `p_rejection_reason`).
   - Lỗi PostgreSQL “not unique” khi `GRANT/REVOKE` các hàm bị overload (`book_amenity_slot`, `simulate_unified_payment`, `generate_valid_bulk_invoices`).
   - Bảng `public.amenities` không tồn tại (tên đúng: `building_amenities`).
   - Các cột không tồn tại trong `20261007_01`: `rejection_reason` (đúng là `reject_reason`), `check_in_time` (Dart dùng `checked_in_at`), `payment_category`, `reference_id` trong `payment_transactions` (bảng dùng `type`, `title`, `invoice_id`, `booking_id`).
   - `generate_valid_bulk_invoices` gọi `validate_monthly_bulk_invoices` sai signature và đọc nhầm key `valid_invoices` (hàm trả `valid_items`).
   - Bảng `role_delegations` bị gọi sai tên cột trong `20261004_02` và `apartments.building` không tồn tại (đúng là `building_code`), `notifications.content` không tồn tại (đúng là `body`).
   - Chèn vào cột tự sinh `invoice_items.subtotal` (GENERATED ALWAYS).
   - Lỗi logic tính tiền: coi `apartments.electric_reading` là lượng tiêu thụ; tự động tính 100k gửi xe cho căn hộ không có xe.
   - Thiếu `transaction_code` trong `record_manual_payment` gây lỗi NOT NULL 23502.
   - Hàm `generate_monthly_bulk_invoices` cũ chưa bị DROP do sai kiểu tham số `due_date` (`DATE` thay vì `TIMESTAMPTZ`).
   - Policy RLS INSERT trên `vehicles` thiếu điều kiện `status = 'pending'`.
   - `trg_check_amenity_booking_resident_update` chặn cả thanh toán dịch vụ và đôn waitlist.
   - Quyền duyệt chỉ số và lập hóa đơn của `technician` vi phạm least privilege.
   - `seed.sql`: thiếu 5 user UUID gây lỗi FK `residents_apartments`; trigger `protect_user_sensitive_fields` chặn upsert khi `auth.uid() IS NULL`.
   - Khuyến nghị an ninh: Cảnh báo RLS trên bảng `public._applied_migrations`.

2. **Nhóm Ứng Dụng Flutter & Cấu Hình:**
   - `resident_meter_reading_screen.dart`: Sửa `Navigator.pushNamed('/link-request')` sang `context.push(AppRoutes.residentLinkRequest)`.
   - `management_home_screen.dart`: Sửa `priority == 'urgent'` thành `priority == 'high'`, tránh nhân đôi thông báo cho Admin.
   - Smart OCR: Gắn nhãn "(Mô phỏng OCR)", tích hợp chọn ảnh thật (ImagePicker) + tạo ảnh mẫu để nút "Xem ảnh" bên BQL hiển thị chuẩn chỉ.
   - Push notification: Hủy stream listeners cũ khi re-init; truyền `onSelectNotificationRoute` từ AuthProvider.
   - iOS: Bổ sung quyền Camera, Photo Library, Schemes `tel`, `mailto` trong `Info.plist`; đồng bộ Bundle ID `vn.pka.home`.
   - Quản lý biến môi trường: Khuyến nghị `--dart-define` và bảo vệ file `.env`.
   - Phân quyền giao diện: Bọc `RoleGuard` cho `amenity_management_screen.dart`, `audit_trail_screen.dart`, ẩn các Quick Action không thuộc quyền trên Dashboard.
   - Khắc phục xung đột tên provider `apartmentVehiclesProvider`.
   - Khôi phục tính tổng tiền và thông báo "Hóa đơn mới" trong `create_invoice_with_items`.
   - Cập nhật tài liệu `README.md`.

---

## 2. Thiết Kế Chi Tiết Tầng CSDL (Supabase PostgreSQL)

### 2.1. Cấu trúc Migration `20261010_01_comprehensive_database_and_security_patches.sql`
Áp dụng chiến lược Idempotent (chạy được nhiều lần không lỗi):
1. **Bổ sung cột còn thiếu:**
   ```sql
   ALTER TABLE public.amenity_bookings ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ;
   ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
   ```
2. **Xóa triệt để các phiên bản hàm cũ gây xung đột / overload:**
   ```sql
   -- Xóa toàn bộ biến thể overload của book_amenity_slot
   DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN);
   DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT);

   -- Xóa toàn bộ biến thể overload của simulate_unified_payment
   DROP FUNCTION IF EXISTS public.simulate_unified_payment(VARCHAR, UUID, VARCHAR);
   DROP FUNCTION IF EXISTS public.simulate_unified_payment(TEXT, UUID, TEXT, TEXT, TEXT);

   -- Xóa toàn bộ biến thể của generate_monthly_bulk_invoices và generate_valid_bulk_invoices
   DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices(TEXT, TIMESTAMPTZ, NUMERIC, NUMERIC, NUMERIC);
   DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);
   DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, TIMESTAMPTZ, NUMERIC, NUMERIC, NUMERIC, UUID[]);
   DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);

   -- Xóa biến thể cũ của reject_meter_reading trước khi tạo lại để tránh lỗi 42P13
   DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID, TEXT);
   DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID);
   ```
3. **Định nghĩa lại các hàm chuẩn xác:**
   - `reject_meter_reading(p_submission_id UUID, p_reason TEXT DEFAULT 'Chỉ số không hợp lệ hoặc ảnh mờ')`:
     - Phân quyền: `public.is_admin_or_accountant()`.
     - Cập nhật đúng cột `reject_reason = p_reason`.
   - `check_in_amenity_booking(p_booking_id UUID)`:
     - Cập nhật đúng `checked_in_at = now()`, `status = 'completed'`.
   - `book_amenity_slot`: Truy vấn đúng bảng `public.building_amenities`, kiểm tra thời gian theo múi giờ `Asia/Ho_Chi_Minh`.
   - `simulate_unified_payment`:
     - Chèn đúng vào `public.payment_transactions`: dùng `type = upper(p_type)`, `invoice_id` hoặc `booking_id`, không dùng `payment_category` hay `reference_id`.
   - `validate_monthly_bulk_invoices`:
     - Lượng tiêu thụ = `GREATEST(0, v_cur_reading - v_old_reading)` nếu có submission approved; nếu không có kỳ mới coi như tiêu thụ = 0.
     - Phí gửi xe: Chỉ tính cho căn hộ có xe approved, 0 xe = 0đ.
     - Trả về đồng bộ cả hai key `'valid_invoices'` và `'valid_items'`.
   - `generate_valid_bulk_invoices`:
     - Gọi `validate_monthly_bulk_invoices(p_period, p_mgmt_rate, p_electric_rate, p_water_rate)`.
     - Bỏ chèn vào cột `subtotal` trong `invoice_items`.
   - `record_manual_payment`:
     - Tự động sinh `transaction_code = 'MANUAL-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8))`.
   - `create_invoice_with_items`:
     - Tự động cập nhật `total_amount = SUM(subtotal)` và bắn thông báo `new_invoice` đến cư dân căn hộ.
   - `protect_user_sensitive_fields`:
     - Kiểm tra `IF auth.uid() IS NOT NULL THEN` để không chặn seed và migration của hệ thống.
   - `trg_check_amenity_booking_resident_update`:
     - Cho phép cư dân cập nhật sang `confirmed` khi thanh toán thành công và `pending_payment` khi đôn waitlist.
   - Siết RLS `vehicles`:
     - Khi cư dân tự INSERT xe, bắt buộc `status = 'pending'` và `rejection_reason IS NULL`.

### 2.2. Vá các file migration lịch sử & `seed.sql`
- Sửa `20261007_01_fix_p0_database_and_security.sql`:
  - Thêm `DROP FUNCTION IF EXISTS` trước khi khai báo lại hàm để tránh 42P13.
  - Sửa `public.amenities` -> `public.building_amenities`.
  - Sửa `rejection_reason` -> `reject_reason`.
  - Sửa `check_in_time` -> `checked_in_at`.
  - Bổ sung signature đầy đủ cho mọi câu lệnh `REVOKE / GRANT`.
- Sửa `20261004_02_building_equipment_maintenance.sql`:
  - Sửa `notifications (..., content, ...)` -> `notifications (..., body, ...)`.
  - Sửa `a.building` -> `a.building_code`.
- Sửa `seed.sql`:
  - Bổ sung 5 tài khoản còn thiếu vào `auth.users` và `public.users`:
    - `a84c3099-f173-433c-8a8e-5990eeb8aad9` (Nguyễn Văn An)
    - `4f89c188-841e-4936-854b-a70393c265be` (Trần Thị Bích)
    - `f5547802-196d-475b-877d-c0ea2c3d3910` (Lê Hoàng Cường)
    - `78fbb083-ee75-4144-9bc8-79f79a49584a` (Phạm Thị Dung)
    - `17a9f297-6fb8-45b0-a9e7-a598fd770684` (Võ Quốc Em)

---

## 3. Thiết Kế Chi Tiết Tầng Client Flutter

### 3.1. Sửa Lỗi Điều Hướng & Hiển Thị
- `resident_meter_reading_screen.dart`:
  - Đổi `Navigator.of(context).pushNamed('/link-request')` thành `context.push(AppRoutes.residentLinkRequest)`.
  - Tích hợp `ImagePicker` cho phép chụp hoặc chọn ảnh thật; nếu bỏ qua sẽ gán ảnh mẫu SVG/WebP URL để BQL luôn có nút "Xem ảnh".
- `management_home_screen.dart`:
  - Sửa kiểm tra `issue['priority'] == 'high'` (thay vì `'urgent'`).
  - Loại bỏ toast cục bộ của stream khi DB trigger đã gửi push notification, ngăn chặn hiển thị trùng lặp.
  - Ẩn các Quick Action mà vai trò hiện tại không có quyền: 'Cẩm nang' (admin/management), 'Tiện ích' (admin/management), 'Bảo trì TB' (admin/management/technician).

### 3.2. Bảo Vệ Màn Hình Với RoleGuard
- Bọc `RoleGuard` cho `amenity_management_screen.dart` (`AppPermissions.amenityManagement`).
- Bọc `RoleGuard` cho `audit_trail_screen.dart` (chỉ `admin`, `management`).
- Sửa `AppPermissions.meterReadingManagement`: loại bỏ `technician` khỏi danh sách được duyệt tài chính, chỉ cho phép `admin`, `management`, `accountant`.

### 3.3. Dịch Vụ Thông Báo & Provider
- `push_notification_service.dart`:
  - Lưu giữ `_tokenRefreshSub` và `_onMessageSub`, gọi `.cancel()` trước khi đăng ký mới.
  - Cung cấp callback điều hướng khi người dùng nhấn vào thông báo.
- `auth_provider.dart`:
  - Truyền `onSelectNotificationRoute` vào `safeInitialize` để điều hướng chuẩn qua `AppRoutes`.
- `management_provider.dart`:
  - Đổi tên `apartmentVehiclesProvider` thành `managementApartmentVehiclesProvider` để tránh lỗi xung đột với `vehicle_provider.dart`.

### 3.4. Cấu Hình Nền Tảng iOS & Android
- `ios/Runner/Info.plist`:
  - Bổ sung `NSCameraUsageDescription` và `NSPhotoLibraryUsageDescription`.
  - Bổ sung `LSApplicationQueriesSchemes` với `tel` và `mailto`.
- `ios/Runner.xcodeproj/project.pbxproj`:
  - Đổi `PRODUCT_BUNDLE_IDENTIFIER` từ `com.example.pkaHome` sang `vn.pka.home`.

---

## 4. Kế Hoạch Kiểm Thử & Xác Nhận (Verification)
1. **Kiểm tra cú pháp & static analysis:** `flutter analyze`.
2. **Kiểm tra unit & widget test:** `flutter test`.
3. **Kiểm tra migration thực tế:** Chạy SQL vá lỗi trên Supabase thông qua `execute_sql` tool và xác nhận các hàm/triggers hoạt động chính xác.
