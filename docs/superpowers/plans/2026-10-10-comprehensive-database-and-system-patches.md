# Kế Hoạch Triển Khai: Khắc Phục Toàn Diện CSDL, Bảo Mật, Migration và Flutter Client

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục toàn bộ 11 lỗi nghiêm trọng phía CSDL, Migration, RLS, Trigger và 11 lỗi phía Flutter, cấu hình iOS/Android, đảm bảo hệ thống vận hành hoàn hảo cả trên DB thực tế lẫn khi chạy lại từ DB sạch.

**Architecture:** Áp dụng mô hình bảo mật 2 lớp Least Privilege (Supabase PostgreSQL RLS/RPC và Flutter RoleGuard). Tách biệt vai trò Kế toán (tài chính) và Kỹ thuật viên. Hoàn thiện tính lũy tiến Idempotent cho toàn bộ Migrations và Seed Data.

**Tech Stack:** Flutter (Riverpod 2.5.1, GoRouter 14.8.1), Supabase (PostgreSQL 15+, PL/pgSQL, RLS, Realtime), Dart.

## Global Constraints
- Tuân thủ 100% `coding-rules.md`, `database-rules.md`, `design-rules.md`.
- Giao diện 100% tiếng Việt chuẩn mực, không dùng Emoji làm icon hiển thị.
- Mã căn hộ chuẩn `A0110` / `a0110`.
- Không gọi Supabase trực tiếp trong Widget — luôn qua Repository/Provider.
- Cột `subtotal` trong `invoice_items` là GENERATED ALWAYS AS STORED — không được INSERT thủ công.

---

### Task 1: Tạo và Áp Dụng Migration Bản Vá CSDL Toàn Diện (20261010_01)

**Files:**
- Modify: `supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql`
- Test: `test/data/migrations/p0_security_migration_content_test.dart`

**Interfaces:**
- Consumes: CSDL PostgreSQL hiện hành và bảng `building_amenities`, `meter_reading_submissions`, `payment_transactions`.
- Produces: Các hàm và trigger chuẩn không bị overload, `reject_meter_reading`, `book_amenity_slot`, `simulate_unified_payment`, `generate_valid_bulk_invoices`, `record_manual_payment`, `create_invoice_with_items`, `protect_user_sensitive_fields`.

- [ ] **Step 1: Viết kịch bản kiểm thử nội dung file migration 20261010_01**
- [ ] **Step 2: Chạy kiểm thử để xác nhận trạng thái hiện tại**
- [ ] **Step 3: Hoàn thiện migration 20261010_01**
  - Bổ sung `checked_in_at` cho `amenity_bookings`.
  - DROP toàn bộ các chữ ký overload của `book_amenity_slot`, `simulate_unified_payment`, `generate_valid_bulk_invoices`, `reject_meter_reading`.
  - Sửa `handle_amenity_booking_cancellation` dùng `building_amenities`.
  - Sửa `check_in_amenity_booking` cập nhật `checked_in_at = now()`.
  - Sửa `simulate_unified_payment` chèn đúng cột `type`, `invoice_id`/`booking_id`, không dùng `payment_category`/`reference_id`.
  - Sửa `validate_monthly_bulk_invoices`: tính đúng hiệu số điện nước tiêu thụ (`GREATEST(0, v_cur - v_old)`), 0 xe = 0đ, trả về cả `valid_invoices` và `valid_items`.
  - Sửa `generate_valid_bulk_invoices`: gọi `validate_monthly_bulk_invoices` đúng chữ ký, bỏ chèn `subtotal`.
  - Sửa `record_manual_payment`: tự sinh `transaction_code`.
  - Khôi phục tính tổng tiền và thông báo `new_invoice` trong `create_invoice_with_items`.
  - Siết quyền `approve_meter_reading` và `reject_meter_reading` chỉ cho `is_admin_or_accountant()`.
  - Bổ sung signature đầy đủ cho mọi lệnh `REVOKE / GRANT`.
- [ ] **Step 4: Chạy kiểm thử xác nhận pass**
- [ ] **Step 5: Thực thi SQL trực tiếp vào Supabase qua tool `execute_sql` và kiểm tra phản hồi**

---

### Task 2: Vá Các File Migration Lịch Sử & Sửa Seed Data Cho DB Sạch

**Files:**
- Modify: `supabase/migrations/20261007_01_fix_p0_database_and_security.sql`
- Modify: `supabase/migrations/20261004_02_building_equipment_maintenance.sql`
- Modify: `supabase/seed.sql`

**Interfaces:**
- Consumes: Bảng `auth.users`, `public.users`, `role_delegations`, `building_equipments`.
- Produces: Kịch bản khởi tạo DB sạch không bị vấp lỗi FK hay lỗi cú pháp 42P13 / relation not found.

- [ ] **Step 1: Sửa 20261007_01**
  - Thêm `DROP FUNCTION IF EXISTS` trước `reject_meter_reading`.
  - Sửa `public.amenities` -> `public.building_amenities`.
  - Sửa `rejection_reason` -> `reject_reason`.
  - Sửa `check_in_time` -> `checked_in_at`.
  - Thêm chữ ký đầy đủ cho các lệnh `GRANT / REVOKE`.
- [ ] **Step 2: Sửa 20261004_02**
  - Sửa `notifications.content` -> `notifications.body`.
  - Sửa `a.building` -> `a.building_code`.
- [ ] **Step 3: Bổ sung 5 user UUID còn thiếu vào `seed.sql`**
  - Thêm 5 user vào `auth.users`, `auth.identities` và `public.users`.
  - Đảm bảo trigger `protect_user_sensitive_fields` không chặn upsert khi `auth.uid() IS NULL`.
- [ ] **Step 4: Kiểm tra tính toàn vẹn cú pháp SQL**

---

### Task 3: Sửa Lỗi Điều Hướng, Trùng Thông Báo & Smart OCR Phía Cư Dân

**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Test: `test/features/resident/resident_meter_reading_screen_test.dart`
- Test: `test/features/management/management_home_rbac_test.dart`

**Interfaces:**
- Consumes: `AppRoutes`, `rawIssuesStreamProvider`.
- Produces: Điều hướng GoRouter chuẩn, so sánh priority 'high', nhãn OCR mô phỏng kèm chọn ảnh thật.

- [ ] **Step 1: Sửa điều hướng trong `resident_meter_reading_screen.dart`**
  - Thay `Navigator.of(context).pushNamed('/link-request')` bằng `context.push(AppRoutes.residentLinkRequest)`.
- [ ] **Step 2: Tích hợp Smart OCR minh bạch & Chọn ảnh thật**
  - Hiển thị nhãn rõ ràng: "(Mô phỏng OCR)".
  - Cho phép người dùng bấm chọn ảnh thật qua ImagePicker hoặc dùng ảnh mẫu có sẵn, gán URL ảnh để BQL có ảnh xem trên giao diện.
- [ ] **Step 3: Sửa `management_home_screen.dart`**
  - Sửa kiểm tra `issue['priority'] == 'high'` thay vì `'urgent'`.
  - Bỏ toast cục bộ trùng lặp từ stream, dựa vào notification push/database.
- [ ] **Step 4: Chạy kiểm thử xác nhận**

---

### Task 4: Vá Dịch Vụ Push Notification & Đổi Tên Provider Xung Đột

**Files:**
- Modify: `lib/core/services/push_notification_service.dart`
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/data/providers/management_provider.dart`
- Modify: `lib/features/management/screens/resident_management_screen.dart`

**Interfaces:**
- Consumes: `FirebaseMessaging`, `FlutterLocalNotificationsPlugin`.
- Produces: Quản lý StreamSubscription an toàn không rò rỉ bộ nhớ / không nhân đôi listener; loại bỏ ambiguous provider import.

- [ ] **Step 1: Quản lý StreamSubscription trong `push_notification_service.dart`**
  - Thêm các biến `StreamSubscription? _tokenRefreshSub; StreamSubscription? _onMessageSub;`.
  - Hủy subscription cũ trước khi lắng nghe mới.
- [ ] **Step 2: Truyền callback điều hướng trong `auth_provider.dart`**
  - Truyền `onSelectNotificationRoute` vào `safeInitialize`.
- [ ] **Step 3: Đổi tên provider trong `management_provider.dart`**
  - Đổi `apartmentVehiclesProvider` thành `managementApartmentVehiclesProvider`.
  - Cập nhật các file đang gọi provider này (`resident_management_screen.dart`).
- [ ] **Step 4: Chạy `flutter test` kiểm tra tính tương thích**

---

### Task 5: Bảo Vệ Giao Diện Với RoleGuard & Ẩn Quick Actions BQL

**Files:**
- Modify: `lib/features/management/screens/amenity_management_screen.dart`
- Modify: `lib/features/management/screens/audit_trail_screen.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/core/constants/permissions.dart`

**Interfaces:**
- Consumes: `AppPermissions`, `RoleGuard`.
- Produces: Màn hình quản lý tiện ích & audit trail được bảo vệ; Dashboard chỉ hiện Quick Actions được phép.

- [ ] **Step 1: Cập nhật `permissions.dart`**
  - Bỏ `technician` khỏi `meterReadingManagement.allowedRoles` (chỉ còn `admin`, `management`, `accountant`).
- [ ] **Step 2: Bọc `RoleGuard` cho `amenity_management_screen.dart` và `audit_trail_screen.dart`**
- [ ] **Step 3: Kiểm tra quyền cho các Quick Action còn lại trên `management_home_screen.dart`**
  - Bọc điều kiện hiển thị cho 'Cẩm nang', 'Tiện ích', 'Bảo trì TB' theo vai trò.
- [ ] **Step 4: Chạy kiểm thử RBAC**

---

### Task 6: Cấu Hình Nền Tảng iOS, Android & Cập Nhật Tài Liệu

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `README.md`

**Interfaces:**
- Consumes: Apple privacy guidelines, Bundle identifier `vn.pka.home`.
- Produces: Cấu hình iOS đầy đủ quyền Camera/Photo/URL schemes; tài liệu README liên kết chuẩn.

- [ ] **Step 1: Bổ sung quyền vào `ios/Runner/Info.plist`**
  - `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `LSApplicationQueriesSchemes` (`tel`, `mailto`).
- [ ] **Step 2: Đồng bộ Bundle ID trong `project.pbxproj`**
  - Đổi `com.example.pkaHome` thành `vn.pka.home`.
- [ ] **Step 3: Cập nhật đường dẫn trong `README.md`**
  - Sửa lại các liên kết tới rules và tài liệu kỹ thuật chuẩn xác.
- [ ] **Step 4: Chạy toàn bộ bộ test `flutter test` và `flutter analyze`**
