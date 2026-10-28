# Kế Hoạch Thực Thi: Giai Đoạn A1 & A2 - Hợp Nhất Database & Chuẩn Hóa Hợp Đồng Client-Server

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hợp nhất 58 migration cũ thành 1 file baseline duy nhất có đầy đủ DDL, RLS, Triggers, RPCs chuẩn hóa; đồng thời sửa triệt để các lỗi lệch chữ ký RPC và sai tên cột giữa Flutter client và PostgreSQL server.

**Architecture:** 
- Toàn bộ 58 migration cũ được chuyển vào `supabase/migrations_archive/` làm tài liệu lưu trữ.
- Tạo file baseline duy nhất `supabase/migrations/20261027_01_baseline_schema.sql` tuân thủ nguyên tắc một định nghĩa duy nhất cho mỗi RPC và không tham chiếu cột sai.
- Phía Flutter client (`payment_service.dart`, `resident_invoice_provider.dart`, `amenity_service.dart`), đồng bộ 100% tham số gọi RPC với kiểu dữ liệu chặt chẽ và loại bỏ param thừa (`p_type`).
- Kiểm thử tĩnh (`flutter analyze`) và kiểm thử đơn vị/tích hợp (`flutter test`) xác minh độ toàn vẹn.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase (PostgreSQL 15+, PL/pgSQL, Row Level Security).

## Global Constraints

- Mọi RPC chỉ có duy nhất 1 định nghĩa với chữ ký chuẩn xác.
- Mã phòng/căn hộ tuân thủ quy chuẩn `A0110` / `a0110` theo `coding-rules.md`.
- Ngôn ngữ giao diện và thông báo lỗi RPC 100% tiếng Việt theo `design-rules.md`.
- Commit trực tiếp trên nhánh `main` theo quy định `AGENTS.md`.

---

### Task 1: Lưu Trữ 58 File Migration Hiện Tại

**Files:**
- Create: `supabase/migrations_archive/`
- Modify: Di chuyển tất cả các file từ `supabase/migrations/2026*.sql` sang `supabase/migrations_archive/`

**Interfaces:**
- Consumes: Thư mục `supabase/migrations/` hiện có 58 files.
- Produces: `supabase/migrations_archive/` chứa toàn bộ 58 files; thư mục `supabase/migrations/` sẵn sàng nhận file baseline mới.

- [ ] **Step 1: Tạo thư mục lưu trữ migrations_archive**
Tạo thư mục `supabase/migrations_archive/` nếu chưa có.

- [ ] **Step 2: Di chuyển toàn bộ file migration cũ vào thư mục archive**
Thực hiện lệnh git hoặc filesystem di chuyển an toàn các file `2026*.sql` vào `supabase/migrations_archive/`.

- [ ] **Step 3: Xác minh thư mục supabase/migrations trống các file cũ**
Chạy kiểm tra đảm bảo không còn file migration cũ nào nằm trực tiếp trong `supabase/migrations/`.

- [ ] **Step 4: Commit lưu trữ migration**
```bash
git add supabase/migrations supabase/migrations_archive
git commit -m "chore(db): luu tru 58 file migration cu vao migrations_archive"
```

---

### Task 2: Xây Dựng File Baseline Schema Duy Nhất (`20261027_01_baseline_schema.sql`)

**Files:**
- Create: `supabase/migrations/20261027_01_baseline_schema.sql`

**Interfaces:**
- Consumes: Toàn bộ schema, trigger, policy và RPCs chuẩn từ các bản migration mới nhất (đặc biệt `20261025_03` và `20261026_03`).
- Produces: `20261027_01_baseline_schema.sql` chứa đầy đủ 9 khối DDL & RPC:
  - Part 1: Extensions & Enums (`user_role`, `vehicle_type`, `invoice_status`, `payment_method`, `amenity_booking_status`, `meter_submission_status`, `issue_status`).
  - Part 2: Bảng cốt lõi (`users`, `apartments`, `residents_apartments`, `apartment_link_requests`, `invoices`, `invoice_items`, `vehicles`, `building_amenities`, `amenity_bookings`, `amenity_maintenance_windows`, `meter_reading_submissions`, `payment_transactions`, `announcements`, `issue_reports`, `issue_images`, `equipment_maintenance_tasks`, `audit_logs`, `service_ratings`, `issue_comments`).
  - Part 3: Bảng cấu hình biểu phí động (`fee_schedules`, `tiered_tariffs`).
  - Part 4: Indexes & Constraints.
  - Part 5: Security Helper Functions (`is_staff_or_management()`, `get_current_user_role()`, `check_user_active_and_unlocked()`).
  - Part 6: RLS Policies cho tất cả các bảng.
  - Part 7: Triggers (`updated_at`, `handle_new_user`, audit logs).
  - Part 8: Canonical RPC Functions (Chuẩn hóa `simulate_unified_payment`, `reschedule_amenity_booking`, `book_amenity_slot`, `confirm_payment`, `record_manual_amenity_payment`, `validate_monthly_bulk_invoices`, `generate_valid_bulk_invoices`, `approve_meter_reading`, `reject_meter_reading`, `admin_create_user`, `admin_update_user_profile`, `admin_toggle_user_status`, `admin_unlink_apartment`).
  - Part 9: Storage Buckets & Policies (`issue-images`, `meter-readings`, `avatars`).

- [ ] **Step 1: Viết file baseline schema tổng hợp đầy đủ DDL, RLS, Triggers và RPCs chuẩn hóa**
Viết file `supabase/migrations/20261027_01_baseline_schema.sql`.
Đặc biệt sửa triệt để:
- Trong `reschedule_amenity_booking`: so khớp `start_time <= v_day_end AND end_time >= v_day_start` (bỏ `start_date`/`end_date`), cập nhật `payment_transactions` bằng `booking_id = p_booking_id` (bỏ `OR invoice_id = p_booking_id::text`), đọc `v_amenity.fee_amount` (bỏ `price_per_slot`).
- Trong `simulate_unified_payment`: chỉ nhận `p_reference_id`, `p_payment_type`, `p_payment_method`, `p_outcome`, `p_failure_reason`. Bỏ `p_type`.
- Trong `book_amenity_slot`: không dùng `FOR UPDATE` trên hàm tổng hợp `SUM()` / `COUNT()`, sử dụng `pg_advisory_xact_lock`.

- [ ] **Step 2: Rà soát kiểm tra cú pháp SQL của file baseline**
Kiểm tra tính nhất quán của các bảng, khóa ngoại và chữ ký hàm.

- [ ] **Step 3: Commit file baseline schema**
```bash
git add supabase/migrations/20261027_01_baseline_schema.sql
git commit -m "feat(db): tao baseline migration duy nhat 20261027_01_baseline_schema.sql"
```

---

### Task 3: Chuẩn Hóa Phía Client - PaymentService & ResidentInvoiceProvider

**Files:**
- Modify: `lib/data/services/payment_service.dart:65-88`
- Modify: `lib/data/providers/resident_invoice_provider.dart:68-91`
- Test: `test/data/services/payment_service_contract_test.dart`

**Interfaces:**
- Consumes: RPC `simulate_unified_payment` với chữ ký:
  - `p_reference_id UUID`
  - `p_payment_type TEXT` ('INVOICE' | 'AMENITY')
  - `p_payment_method TEXT` ('DEMO' | 'bank_transfer' | 'cash')
  - `p_outcome TEXT` ('SUCCESS' | 'FAILURE')
  - `p_failure_reason TEXT`
- Produces: `simulateUnifiedPayment` và `simulatePayment` truyền đúng 100% tham số, bỏ tham số `p_type`.

- [ ] **Step 1: Viết test hợp đồng cho PaymentService**
Tạo file test `test/data/services/payment_service_contract_test.dart` kiểm tra `PaymentResult.fromJson` và cấu trúc parameters gửi đi không còn chứa `p_type`.

- [ ] **Step 2: Chạy test để xác minh lỗi/trạng thái ban đầu**
Chạy: `flutter test test/data/services/payment_service_contract_test.dart`

- [ ] **Step 3: Cập nhật PaymentService và ResidentInvoiceProvider**
Sửa `lib/data/services/payment_service.dart` và `lib/data/providers/resident_invoice_provider.dart`:
Loại bỏ `p_type`, đồng bộ tên tham số và kiểu trả về.

- [ ] **Step 4: Chạy lại test xác nhận PASS**
Chạy: `flutter test test/data/services/payment_service_contract_test.dart`

- [ ] **Step 5: Commit thay đổi Client Payment Contract**
```bash
git add lib/data/services/payment_service.dart lib/data/providers/resident_invoice_provider.dart test/data/services/payment_service_contract_test.dart
git commit -m "fix(payment): chuan hoa chu ky goi simulate_unified_payment tren client"
```

---

### Task 4: Chuẩn Hóa Phía Client - AmenityService & Booking Provider

**Files:**
- Modify: `lib/data/services/amenity_service.dart`
- Modify: `lib/data/providers/amenity_booking_provider.dart`

**Interfaces:**
- Consumes: RPCs `reschedule_amenity_booking` (`p_booking_id`, `p_new_date`, `p_new_time_slot`, `p_new_guests_count`, `p_new_notes`) và `book_amenity_slot`.
- Produces: Các phương thức `rescheduleBooking`, `bookSlot` truyền đúng các tham số canonical.

- [ ] **Step 1: Kiểm tra các lời gọi RPC trong AmenityService**
Rà soát `lib/data/services/amenity_service.dart` để đối chiếu với chữ ký của `reschedule_amenity_booking`, `cancel_amenity_booking`, `book_amenity_slot`.

- [ ] **Step 2: Sửa đổi và chuẩn hóa tham số trong AmenityService nếu có sai lệch**
Cập nhật các phương thức trong `amenity_service.dart` đảm bảo truyền đúng tên tham số (`p_booking_id`, `p_new_date`, `p_new_time_slot`, `p_new_guests_count`, `p_new_notes`).

- [ ] **Step 3: Commit cập nhật Amenity Service**
```bash
git add lib/data/services/amenity_service.dart lib/data/providers/amenity_booking_provider.dart
git commit -m "fix(amenity): dong bo tham so goi rpc doi lich va dat tien ich"
```

---

### Task 5: Rà Soát Toàn Hệ Thống, Kiểm Thử Tích Hợp & Verification

**Files:**
- Test: `test/integration/amenity_booking_concurrency_and_rpc_test.dart`
- Analyze: Toàn bộ codebase qua `flutter analyze`

**Interfaces:**
- Consumes: Toàn bộ thay đổi từ Task 1 đến Task 4.
- Produces: Báo cáo `flutter analyze` sạch (0 issues), test suite chạy thành công.

- [ ] **Step 1: Chạy phân tích tĩnh Flutter**
Chạy: `flutter analyze`
Đảm bảo: "No issues found!"

- [ ] **Step 2: Chạy bộ kiểm thử tích hợp và kiểm thử đơn vị**
Chạy: `flutter test test/integration/amenity_booking_concurrency_and_rpc_test.dart` và `flutter test test/data/services/payment_service_contract_test.dart`
Đảm bảo tất cả các bài test đều vượt qua (PASS).

- [ ] **Step 3: Commit hoàn tất Giai đoạn A1 & A2**
```bash
git commit --allow-empty -m "chore: hoan thanh xac minh giai doan A1 & A2 hop nhat baseline va dong bo hop dong"
```
