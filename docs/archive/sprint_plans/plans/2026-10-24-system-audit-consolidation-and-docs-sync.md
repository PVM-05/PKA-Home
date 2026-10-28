# Kế Hoạch Thực Thi: Chuẩn Hóa Toàn Diện Hệ Thống & Đồng Bộ Tài Liệu Dự Án

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để các lỗi P0/P1/P2 từ đợt kiểm thử, tạo migration CSDL hợp nhất giải quyết xung đột hàm RPC, chuẩn hóa 100% email về `@gmail.com` và đồng bộ toàn bộ tài liệu dự án trong `docs/`.

**Architecture:** Tạo bản migration SQL chuẩn tắc `20261024_01_system_audit_consolidation.sql` để drop sạch signature cũ và định nghĩa các RPC chuẩn (thanh toán PENDING 2 bước, kiểm tra sức chứa SUM guests, invoice unpaid enum, RBAC security); khử trùng lặp và kích hoạt trigger trong `seed.sql`; sửa các lỗi UI/Provider trên Flutter; và cập nhật toàn bộ tài liệu `docs/` (ERD, Test Plan, RLS, Báo cáo, Errors).

**Tech Stack:** Flutter / Dart (Riverpod, GoRouter), PostgreSQL / Supabase, DBML, Markdown.

## Global Constraints
- Commit trực tiếp trên nhánh `main`, không tạo branch/worktree phụ.
- 100% tiếng Việt chuẩn trên giao diện người dùng, không hardcode mã màu rời rạc, hỗ trợ Dark Mode an toàn.
- Tuân thủ nghiêm ngặt quy tắc enum CSDL (`invoice_status`: `'unpaid'`, `'pending_confirmation'`, `'paid'`; `user_role`: `'admin'`, `'management'`, `'accountant'`, `'technician'`, `'resident'`).
- Mọi email tài khoản dùng trong hệ thống và tài liệu đều thuộc tên miền `@gmail.com`, mật khẩu `PkaHome@2026`.

---

### Task 1: Tạo Migration Hợp Nhất Cơ Sở Dữ Liệu (`20261024_01_system_audit_consolidation.sql`)

**Files:**
- Create: `supabase/migrations/20261024_01_system_audit_consolidation.sql`

**Interfaces:**
- Consumes: CSDL PostgreSQL 15, bảng `amenity_bookings`, `invoices`, `payment_transactions`, `meter_reading_submissions`.
- Produces: Các RPC chuẩn xác: `simulate_unified_payment`, `book_amenity_slot`, `generate_valid_bulk_invoices`, `approve_meter_reading`, `reject_meter_reading`, `record_manual_payment`, `validate_monthly_bulk_invoices`, `create_invoice_with_items`.

- [ ] **Step 1: Viết file migration hợp nhất `20261024_01_system_audit_consolidation.sql`**
  - Drop toàn bộ các overload cũ:
    ```sql
    DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text);
    DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar);
    DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT);
    DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN);
    DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT);
    DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);
    DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]);
    DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);
    DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID, BOOLEAN, DATE);
    DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID);
    DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID, TEXT);
    DROP FUNCTION IF EXISTS public.record_manual_payment(UUID);
    DROP FUNCTION IF EXISTS public.record_manual_payment(UUID, VARCHAR, TEXT);
    DROP FUNCTION IF EXISTS public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB);
    ```
  - Định nghĩa `simulate_unified_payment`: Dùng `b.booked_by`, role `'management'`, 2 bước PENDING.
  - Định nghĩa `book_amenity_slot`: Dùng `SUM(guests_count) + p_guests_count` cho tiện ích `shared`.
  - Định nghĩa `generate_valid_bulk_invoices`: Chứa tham số `p_target_apartment_ids UUID[] DEFAULT NULL`, `status = 'unpaid'`.
  - Định nghĩa `approve_meter_reading`: Tạo hóa đơn với `status = 'unpaid'`.
  - Định nghĩa `reject_meter_reading`: Nhận tham số `p_reason`.
  - Định nghĩa `record_manual_payment`: Tự sinh `transaction_code`, cập nhật `SUCCESS` và invoice `paid`.
  - Định nghĩa `validate_monthly_bulk_invoices`: Kiểm tra `public.is_admin_or_accountant()`.
  - Định nghĩa `create_invoice_with_items`: Tạo hóa đơn với `status = 'unpaid'`.
  - Xóa trigger cũ: `trg_notify_on_issue_status_change`, `trg_notify_on_issue_lifecycle`, `trg_notify_equipment_task_status`.
  - Siết quyền `get_amenity_bookings`: `REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated;`.

- [ ] **Step 2: Kiểm tra cú pháp SQL và tính toàn vẹn của migration**
  - Đảm bảo không còn tham chiếu `price_per_slot`, `v_booking.total_fee`, `b.user_id`, `'manager'`, hoặc enum `'pending'`.

- [ ] **Step 3: Commit migration vào git**
  - Chạy: `git add supabase/migrations/20261024_01_system_audit_consolidation.sql`
  - Chạy: `git commit -m "fix(db): add authoritative consolidation migration resolving RPC and trigger conflicts"`

---

### Task 2: Chuẩn Hóa Dữ Liệu Mẫu (`supabase/seed.sql`)

**Files:**
- Modify: `supabase/seed.sql`

**Interfaces:**
- Consumes: Bảng `vehicles`, `apartments`, `auth.users`.
- Produces: Dữ liệu mẫu 40 xe độc bản không trùng biển số, trigger `trg_check_vehicle_limits` không bị disable, email 100% `@gmail.com`.

- [ ] **Step 1: Khử trùng lặp biển số xe trong `supabase/seed.sql`**
  - Rà soát các block INSERT của `vehicles`:
    - Biển số `30K-112.34`, `29Y1-789.01`, `30G-998.87`, `29V1-567.89` đang bị chèn nhiều lần ở cùng căn hộ.
    - Thay thế bằng các biển số xe thực tế độc nhất (đảm bảo đủ 28 xe máy, 12 ô tô = 40 xe phân bổ đều theo `docs/demo_accounts.md`).
- [ ] **Step 2: Loại bỏ lệnh tắt trigger và bảo đảm giới hạn số lượng xe**
  - Xóa dòng `ALTER TABLE public.vehicles DISABLE TRIGGER trg_check_vehicle_limits;`.
  - Đảm bảo mỗi căn hộ không vượt quá 2 xe máy và 1 ô tô.
- [ ] **Step 3: Kiểm tra toàn bộ email tài khoản trong `seed.sql`**
  - Đảm bảo 100% email có đuôi `@gmail.com` và mật khẩu `PkaHome@2026`.
- [ ] **Step 4: Commit `seed.sql` vào git**
  - Chạy: `git add supabase/seed.sql`
  - Chạy: `git commit -m "fix(seed): deduplicate vehicle plates, remove trigger bypass and verify gmail accounts"`

---

### Task 3: Sửa Lỗi Mã Nguồn Client (P0, P1, P2)

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Modify: `lib/data/models/amenity_booking_model.dart`
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/features/management/widgets/resident_360_detail_sheet.dart`
- Modify: `lib/features/auth/widgets/otp_input_boxes.dart`
- Modify: `ios/Runner/Info.plist`
- Modify: `pubspec.yaml`
- Modify: `test/features/auth/password_reset_screens_test.dart`

**Interfaces:**
- Consumes: `AmenityBookingModel`, `AmenityBookingRepository`, `OtpInputBoxes`.
- Produces: Luồng hủy và thanh toán `pending_payment` cho cư dân, `FocusNode` quản lý an toàn trong OTP, cấu hình iOS Plist hợp lệ, pubspec không chứa file bảo mật.

- [ ] **Step 1: Viết test cho `AmenityBookingModel` và logic trạng thái `pending_payment`**
  - Viết test trong `test/data/models/amenity_booking_model_test.dart` kiểm tra `isPendingPayment == true`, JSON parsing với `deposit_amount`, `fee_amount`.
- [ ] **Step 2: Cập nhật `AmenityBookingModel` và `AmenityBookingRepository`**
  - Trong `amenity_booking_model.dart`: Cập nhật comment và enum helper.
  - Trong `amenity_booking_repository.dart`: `getBookingsByAmenityAndDate` bổ sung `pending_payment` vào `inFilter('status', ['confirmed', 'waitlist', 'pending_payment'])`.
- [ ] **Step 3: Cập nhật `amenity_booking_screen.dart`**
  - Trong `_buildMyBookingsTab`:
    - Thêm nhánh trạng thái `else if (b.isPendingPayment)` hiển thị nhãn "Chờ thanh toán" (màu `AppStatusColors.pendingConfirmation`).
    - Thêm nút "Thanh toán ngay" (kích hoạt `UnifiedPaymentSheet`) và cho phép `canCancel = (b.isConfirmed || b.isWaitlist || b.isPendingPayment)`.
  - Trong dialog đặt chỗ `_confirmAndBookSlot`: Tách `int dialogGuestsCount = guestsCount;` độc lập trong `StatefulBuilder`.
- [ ] **Step 4: Sửa `resident_360_detail_sheet.dart`**
  - Đổi `b['amenities']` thành `b['building_amenities']` để hiển thị đúng tên tiện ích thay vì fallback "Tiện ích".
- [ ] **Step 5: Sửa `otp_input_boxes.dart`**
  - Khởi tạo danh sách `late List<FocusNode> _keyboardFocusNodes` trong `initState()` và `dispose()` trong `dispose()`, thay thế việc gọi `focusNode: FocusNode()` trực tiếp trong `build()`.
- [ ] **Step 6: Sửa `ios/Runner/Info.plist` & `pubspec.yaml`**
  - `ios/Runner/Info.plist`: Bổ sung thẻ `</array>` đóng mảng `UISupportedInterfaceOrientations~ipad`.
  - `pubspec.yaml`: Gỡ `- .env` khỏi danh mục assets.
  - `test/features/auth/password_reset_screens_test.dart`: Đổi `resident@pka.vn` thành `cudan.a0101@gmail.com`.
- [ ] **Step 7: Chạy kiểm thử Unit Test & Flutter Analyze**
  - Chạy `flutter test` và `flutter analyze` xác nhận 0 lỗi.
- [ ] **Step 8: Commit client fixes vào git**
  - Chạy: `git commit -am "fix(client): handle pending payment booking, fix dialog state, otp focus and config"`

---

### Task 4: Đồng Bộ & Cập Nhật Toàn Bộ Tài Liệu Dự Án (`docs/`)

**Files:**
- Modify: `docs/test-plan.md`
- Modify: `docs/ERD.dbml`
- Modify: `docs/RLS-policy.md`
- Modify: `docs/bao-cao-tien-do-tuan 1.md`
- Modify: `docs/errors.md`
- Modify: `docs/SRS.md`
- Modify: `docs/feature-list.md`

**Interfaces:**
- Consumes: CSDL thực tế, mã nguồn hiện hành, email `@gmail.com`.
- Produces: Bộ tài liệu kỹ thuật và báo cáo chuẩn hóa 100% phục vụ nghiệm thu đồ án.

- [ ] **Step 1: Cập nhật `docs/test-plan.md`**
  - Đổi toàn bộ các tài khoản `@pka.vn` sang `@gmail.com`:
    - `pkahome.admin@gmail.com`
    - `pkahome.ketoan@gmail.com`
    - `pkahome.kythuat@gmail.com`
    - `cudan.a0101@gmail.com`, `cudan.b0101@gmail.com`, `cudan.c0101@gmail.com`, `test1@gmail.com`
  - Đổi mật khẩu demo thành `PkaHome@2026`.
  - Cập nhật kịch bản kiểm thử khớp với luồng thanh toán PENDING và chỉ số điện nước.
- [ ] **Step 2: Cập nhật `docs/ERD.dbml`**
  - Đổi tên bảng `amenities` -> `building_amenities`.
  - Bổ sung bảng `amenity_maintenance_windows`, `user_fcm_tokens`.
  - Thêm cột `fee_amount`, `deposit_amount`, `deposit_status`, `deposit_notes`, `checked_in_at` vào bảng `amenity_bookings`.
  - Chuẩn hóa cột bảng `vehicles`: `user_id`, `plate_number`, `license_plate`, `brand_model`.
  - Bổ sung `PENDING` vào trạng thái của `payment_transactions`.
- [ ] **Step 3: Cập nhật `docs/RLS-policy.md`**
  - Cập nhật mục 7 Storage Bucket `issue-images` phản ánh đúng chính sách Authenticated Read Access đã siết chặt.
- [ ] **Step 4: Cập nhật `docs/bao-cao-tien-do-tuan 1.md`**
  - Sửa phương thức thanh toán: VietQR / Chuyển khoản ngân hàng / Tiền mặt (loại bỏ MoMo/ZaloPay).
  - Cập nhật Giai đoạn 5 (Tính năng Ban Quản Lý) đạt 100%.
- [ ] **Step 5: Cập nhật `docs/errors.md`**
  - Bổ sung toàn diện các lỗi đã xử lý: Realtime WebSocket Code 1002, Lệch chữ ký RPC tạo hóa đơn, Xung đột enum `invoice_status` với `'pending'`, và Khắc phục luồng `simulate_unified_payment`.
- [ ] **Step 6: Commit cập nhật tài liệu vào git**
  - Chạy: `git add docs/`
  - Chạy: `git commit -m "docs: synchronize ERD, test plan, RLS policies and progress report with actual implementation"`

---

### Task 5: Xác Minh Tổng Thể Toàn Hệ Thống

**Files:**
- N/A

- [ ] **Step 1: Chạy toàn bộ test suite dự án**
  - Chạy: `flutter test`
  - Kỳ vọng: 100% tests pass.
- [ ] **Step 2: Chạy kiểm tra tĩnh mã nguồn**
  - Chạy: `flutter analyze`
  - Kỳ vọng: 0 issues found.
- [ ] **Step 3: Kiểm tra trạng thái Git**
  - Chạy: `git status`
  - Kỳ vọng: Working tree clean trên nhánh `main`.
