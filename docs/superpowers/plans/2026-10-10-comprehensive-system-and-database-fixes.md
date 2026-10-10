# Kế hoạch Khắc phục Toàn diện CSDL, Migration và Lỗi Nghiệp vụ Flutter

> **Dành cho Agent:** Áp dụng trực tiếp trên nhánh `main` theo yêu cầu người dùng, kiểm thử từng task bằng TDD/Verification trước khi commit.

**Mục tiêu:** Khắc phục triệt để các lỗi migration/trigger/RPC trong CSDL PostgreSQL/Supabase và các lỗi runtime, phân quyền, nuốt ngoại lệ, trùng lặp provider trong Flutter.

**Kiến trúc:** 
- Tầng CSDL: Vá lỗi SQL syntax/cột sai trong `20261004_02` và tạo migration `20261010_01` hoàn thiện các RPC/trigger.
- Tầng Flutter: Cập nhật repository, provider, widget, router guard và constants theo đúng nguyên tắc Clean Architecture & Riverpod.

**Tech Stack:** PostgreSQL (Supabase), Flutter, Dart, Riverpod 2.x, GoRouter.

---

### Task 1: Vá lỗi CSDL & Migration (PostgreSQL / Supabase)

**Files:**
- Modify: `supabase/migrations/20261004_02_building_equipment_maintenance.sql:64-85`
- Create: `supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql`
- Test: `test/data/migrations/p0_security_migration_content_test.dart`

**Chi tiết xử lý:**
1. Sửa hàm `is_staff_or_management()` trong `20261004_02`:
   - Dùng đúng cột: `rd.delegate_id = auth.uid()`, `rd.delegated_role IN (...)`, `now() BETWEEN rd.starts_at AND rd.ends_at`.
2. Trong `20261010_01`:
   - `record_manual_payment`: Tự động sinh `transaction_code := 'MANUAL-' || to_char(now(), 'YYYYMMDDHH24MISS') || '-' || substr(gen_random_uuid()::text, 1, 8)` để thỏa mãn ràng buộc NOT NULL UNIQUE.
   - Sửa trigger `check_amenity_booking_resident_update`: Cho phép chuyển status sang `'confirmed'` (phục vụ `simulate_unified_payment`) hoặc `'pending_payment'` (phục vụ đôn waitlist).
   - Sửa `validate_monthly_bulk_invoices`:
     - Tính đúng lượng tiêu thụ: `v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec)` và `v_water_usage := GREATEST(0, v_cur_water - v_old_water)`.
     - Phí gửi xe: Nếu không có xe nào (`v_motorbike_count + v_car_count = 0`), gán `v_parking_fee := 0` thay vì phạt 100.000đ.
     - Chuẩn hóa phí quản lý mặc định `16500` đ/m².
   - Sửa regex `classify_issue_priority`: Thêm `\y` cho các từ ngắn (`\ysập\y|\ysap\y|\ynổ\y|\yno\y`) để tránh khớp nhầm với "nóng", "nội quy", "sắp".
   - DROP đúng chữ ký: `DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID, VARCHAR);`.

---

### Task 2: Vá lỗi Runtime, Logic Nghiệp vụ & Data Layer (Flutter)

**Files:**
- Modify: `lib/data/repositories/management_repository.dart:488`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart:47-65`
- Modify: `lib/features/auth/widgets/otp_input_boxes.dart:47-65`
- Modify: `lib/data/repositories/vehicle_repository.dart:122-136`
- Modify: `lib/data/providers/resident_invoice_provider.dart:68-87`

**Chi tiết xử lý:**
1. `management_repository.dart`: Sửa join `amenities(name)` thành `building_amenities(name)` trong `fetchResidentBookings`.
2. `resident_invoice_detail_screen.dart`: Bỏ `ref.watch` ra khỏi getter `_invoice`. Đọc `residentInvoiceProvider` trong `build()` và dùng `ref.read` trong callback.
3. `otp_input_boxes.dart`: Trong `_handleChanged`, chỉ coi là paste khi người dùng dán chuỗi dài vào ô trống hoặc số ký tự thay đổi > 1 so với độ dài cũ. Khi gõ đè 1 ký tự vào ô đã có số, lấy ký tự mới nhất thay thế cho ô hiện tại và chuyển focus tiếp.
4. `vehicle_repository.dart`: Khi `approveVehicle(vehicleId)`, đặt `rejection_reason = null` để xóa lý do từ chối cũ.
5. `resident_invoice_provider.dart`: Cập nhật `ResidentInvoiceService.simulatePayment` gọi RPC `simulate_unified_payment` với `p_category: 'INVOICE'`.

---

### Task 3: Chuẩn hóa Xử lý Lỗi & Khử Trùng Lặp Code

**Files:**
- Modify: `lib/core/utils/network_error_handler.dart:85-102`
- Delete: `lib/core/constants.dart`
- Modify: `lib/data/providers/management_provider.dart:41`
- Modify: `lib/features/management/widgets/resident_360_detail_sheet.dart:198`

**Chi tiết xử lý:**
1. `network_error_handler.dart`: Khi `error is Exception`, tách chuỗi thông báo (bỏ tiền tố `Exception: `). Nếu chuỗi chứa ký tự tiếng Việt có dấu, trả về trực tiếp thông điệp này thay vì rơi vào fallback chung.
2. Xóa file thừa `lib/core/constants.dart` (chỉ giữ `lib/core/constants/app_constants.dart`).
3. Đổi tên `residentVehiclesProvider` trong `management_provider.dart` thành `apartmentVehiclesProvider` để loại bỏ xung đột trùng tên với `vehicle_provider.dart`.

---

### Task 4: Tăng cường Phân quyền RBAC & Router Guard

**Files:**
- Modify: `lib/core/router/app_router.dart:83-90`
- Modify: `lib/core/constants/permissions.dart`
- Modify: `lib/features/management/screens/vehicle_approval_screen.dart`
- Modify: `lib/features/management/screens/management_meter_reading_screen.dart`
- Modify: `lib/features/management/screens/equipment_management_screen.dart`
- Modify: `lib/features/management/screens/management_payment_transactions_screen.dart`

**Chi tiết xử lý:**
1. `app_router.dart`: Trong hàm `redirect`, chặn người dùng đã đăng nhập nhưng không có quyền quản lý (`!user.isManagement`) truy cập vào các route bắt đầu bằng `/management`.
2. `permissions.dart`: Khai báo bổ sung 5 quyền còn thiếu (`vehicleApproval`, `meterReadingManagement`, `equipmentManagement`, `paymentTransactions`, `amenityManagement`).
3. Bọc `RoleGuard` cho 4 màn hình quản lý đang thiếu.

---

### Task 5: Kiểm thử Toàn diện & Hoàn tất Commit

**Files:**
- Run test: `flutter analyze`
- Run test: `flutter test`
- Commit: Commit trực tiếp vào nhánh `main`.
