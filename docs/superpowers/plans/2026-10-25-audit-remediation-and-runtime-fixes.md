# Kế Hoạch Triển Khai: Khắc Phục Toàn Diện 6 Điểm Rà Soát Hệ Thống & Kiểm Thử Runtime

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để các lỗ hổng CSDL (giao dịch waitlist, ràng buộc status, RPC đặc quyền, lịch bảo trì), xử lý cập nhật dữ liệu rỗng và thông báo lỗi trong Repository, nâng cao độ tin cậy bộ unit test và đồng bộ CSDL Supabase thực tế.

**Architecture:** Sử dụng kiến trúc Feature-first Flutter + Supabase PostgreSQL. Áp dụng migration DDL/DML có tính chất lũy thừa (idempotent), siết chặt quyền hạn theo nguyên tắc đặc quyền tối thiểu (Least Privilege), và bảo đảm tầng Repository phản hồi chính xác mọi thao tác CSDL.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL 17, Postgrest), Flutter Riverpod, Mocktail / Flutter Test.

## Global Constraints
- **Branch:** Chỉ sử dụng duy nhất nhánh `main`. Commit toàn bộ thay đổi trực tiếp lên `main`.
- **Commit convention:** `<loại>: <mô tả ngắn>` (feat, fix, docs, refactor, style, test).
- **Ngôn ngữ UI/Thông báo:** 100% tiếng Việt chuẩn mực, không dùng emoji trong giao diện.
- **CSDL:** Mọi bảng bắt buộc có `created_at` và `updated_at`. RLS kích hoạt trên toàn bộ các bảng.
- **RPC:** Mọi hàm `SECURITY DEFINER` phải có `SET search_path = public, pg_catalog` và kiểm tra vai trò người gọi nội bộ.

---

### Task 1: Migration CSDL Khắc Phục Giao Dịch Waitlist, Lịch Bảo Trì & Quyền RPC (SYS-01, SYS-02, SYS-04)

**Files:**
- Create: `supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql`
- Test: `test/data/repositories/pending_correction_migration_test.dart`

**Interfaces:**
- Produces: 
  - `public.payment_transactions.updated_at` (TIMESTAMPTZ)
  - `public.payment_transactions_status_check` (cho phép `PENDING`, `SUCCESS`, `FAILED`, `CANCELLED`)
  - `public.confirm_payment(UUID)` với kiểm tra `is_admin() OR is_accountant()`, `search_path`, và `REVOKE FROM anon, PUBLIC`
  - `public.reschedule_amenity_booking` và `public.book_amenity_slot` kiểm tra khoảng thời gian bảo trì với `start_time` và `end_time`
  - `public.handle_amenity_booking_cancellation` tự động tạo/cập nhật `payment_transactions` sang `PENDING` khi đôn waitlist

- [ ] **Step 1: Viết bài test xác thực các yêu cầu mới của migration 20261025_01**

```dart
test('Migration 20261025_01 phải bổ sung updated_at, sửa status check PENDING và siết confirm_payment', () {
  final file = File('supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql');
  expect(file.existsSync(), isTrue, reason: 'Phải tạo migration 20261025_01');
  final content = file.readAsStringSync();
  expect(content.contains('payment_transactions_status_check'), isTrue);
  expect(content.contains('PENDING'), isTrue);
  expect(content.contains('ADD COLUMN IF NOT EXISTS updated_at'), isTrue);
  expect(content.contains('confirm_payment'), isTrue);
  expect(content.contains('is_admin() OR public.is_accountant()'), isTrue);
  expect(content.contains('start_time AT TIME ZONE'), isTrue);
});
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL vì file migration chưa tồn tại.

- [ ] **Step 3: Soạn thảo file migration `supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql`**

Bao gồm:
1. `ALTER TABLE public.payment_transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();`
2. Cập nhật check constraint `payment_transactions_status_check` cho phép `('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED')`.
3. Sửa `book_amenity_slot` và `reschedule_amenity_booking` so khớp thời gian bảo trì với `start_time` và `end_time`.
4. Cập nhật `handle_amenity_booking_cancellation` tạo bản ghi `payment_transactions` trạng thái `PENDING` khi đôn waitlist.
5. Cập nhật `confirm_payment` có `SET search_path = public, pg_catalog`, kiểm tra `is_admin() OR is_accountant()`, `REVOKE ALL FROM PUBLIC, anon`.
6. Cập nhật `search_path` cho các hàm kiểm tra quyền.

- [ ] **Step 4: Chạy test kiểm tra cú pháp và nội dung migration (Green)**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS

- [ ] **Step 5: Thực thi migration trực tiếp trên CSDL Supabase qua `execute_sql` MCP tool**

Thực thi câu lệnh SQL để đồng bộ CSDL thực tế:
- Áp dụng migration `20261024_04` (nếu các hàm RPC chưa có trên DB) và migration `20261025_01`.
- Kiểm tra lại các bảng `payment_transactions`, `pg_proc` xác nhận các ràng buộc và quyền đã có hiệu lực trên database thật.

- [ ] **Step 6: Commit lên `main`**

```bash
git add supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql test/data/repositories/pending_correction_migration_test.dart
git commit -m "fix(db): hoàn thiện giao dịch waitlist, siết quyền RPC và sửa lỗi lịch bảo trì"
```

---

### Task 2: Chuẩn Hóa `AmenityBookingRepository` Xử Lý Kết Quả Cập Nhật & Thông Báo Lỗi (SYS-03, UI-01, SYS-04)

**Files:**
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Test: `test/data/repositories/amenity_booking_repository_update_check_test.dart`

**Interfaces:**
- Consumes: `AmenityBookingRepository`
- Produces: 
  - `cancelBooking(String bookingId)`: Ném Exception nếu 0 dòng cập nhật
  - `updateDepositStatus(String bookingId, String depositStatus, {String? notes})`: Ném Exception nếu 0 dòng cập nhật
  - `markBookingAttendance(String bookingId, String status)`: Ném Exception nếu 0 dòng cập nhật
  - `createBooking(...)`: Ném thông báo lỗi quan hệ dữ liệu liên kết không hợp lệ khi nhận mã `23503`
  - `getMaintenanceWindows(...)`: Log cảnh báo rõ ràng khi gặp lỗi bảng chưa tồn tại

- [ ] **Step 1: Viết unit test cho các hàm cập nhật và thông báo lỗi trong Repository**

Tạo `test/data/repositories/amenity_booking_repository_update_check_test.dart` kiểm tra:
1. `createBooking` khi gặp PostgrestException 23503 ném thông báo: "Thông tin tiện ích hoặc căn hộ liên kết không tồn tại hoặc không hợp lệ."
2. `cancelBooking`, `updateDepositStatus`, `markBookingAttendance` khi `response` rỗng (`[]`) ném Exception tiếng Việt tương ứng.

- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**

Run: `flutter test test/data/repositories/amenity_booking_repository_update_check_test.dart`
Expected: FAIL

- [ ] **Step 3: Cập nhật mã nguồn `AmenityBookingRepository`**

1. Trong `createBooking`:
   ```dart
   if (e.code == '23503') {
     throw Exception('Thông tin tiện ích hoặc căn hộ liên kết không tồn tại hoặc không hợp lệ.');
   }
   ```
2. Trong `cancelBooking`:
   ```dart
   final response = await _client
       .from('amenity_bookings')
       .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
       .eq('id', bookingId)
       .select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền hủy.');
   }
   ```
3. Trong `updateDepositStatus`:
   ```dart
   final response = await _client.from('amenity_bookings').update({
     'deposit_status': depositStatus,
     'deposit_notes': notes,
     'updated_at': DateTime.now().toIso8601String(),
   }).eq('id', bookingId).select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật tiền cọc.');
   }
   ```
4. Trong `markBookingAttendance`:
   ```dart
   final response = await _client.from('amenity_bookings').update({
     'status': status,
     'updated_at': DateTime.now().toIso8601String(),
   }).eq('id', bookingId).select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật điểm danh.');
   }
   ```
5. Trong `getMaintenanceWindows`:
   Log cảnh báo qua `AppLogger.w` nếu bắt được `PGRST205` hoặc `42P01`.

- [ ] **Step 4: Chạy test để xác nhận test thành công (Green)**

Run: `flutter test test/data/repositories/amenity_booking_repository_update_check_test.dart`
Expected: PASS

- [ ] **Step 5: Commit lên `main`**

```bash
git add lib/data/repositories/amenity_booking_repository.dart test/data/repositories/amenity_booking_repository_update_check_test.dart
git commit -m "fix(repo): kiểm tra bản ghi cập nhật và chuẩn hóa thông báo lỗi đặt tiện ích"
```

---

### Task 3: Nâng Cấp Bộ Test Migration & Kiểm Thử Toàn Vẹn CSDL Thực Tế (SYS-05)

**Files:**
- Modify: `test/data/repositories/pending_correction_migration_test.dart`
- Create: `test/integration/database_schema_and_security_audit_test.dart`

**Interfaces:**
- Produces: Bộ test chạy nghiêm ngặt không có `return` sớm, xác thực đầy đủ ràng buộc CSDL và quyền thực thi RPC.

- [ ] **Step 1: Viết test integration kiểm tra trực tiếp CSDL Supabase thực tế**

Tạo `test/integration/database_schema_and_security_audit_test.dart`:
- Kiểm tra bảng `payment_transactions` có cột `updated_at`.
- Kiểm tra `payment_transactions_status_check` cho phép `PENDING`.
- Kiểm tra các hàm `confirm_payment`, `approve_link_request`, `reschedule_amenity_booking` đã được cấp quyền đúng và có `search_path`.

- [ ] **Step 2: Cập nhật `pending_correction_migration_test.dart` loại bỏ `return` sớm**

Thay thế tất cả `if (!migrationFile.existsSync()) return;` bằng `expect(migrationFile.existsSync(), isTrue);`.

- [ ] **Step 3: Chạy toàn bộ test suites của task 3**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart test/integration/database_schema_and_security_audit_test.dart`
Expected: PASS

- [ ] **Step 4: Commit lên `main`**

```bash
git add test/data/repositories/pending_correction_migration_test.dart test/integration/database_schema_and_security_audit_test.dart
git commit -m "test: loại bỏ silent pass và bổ sung kiểm thử kiểm toán schema CSDL"
```

---

### Task 4: Chạy Toàn Bộ Kiểm Thử Tĩnh và Unit/Widget Test Xác Minh Không Lỗi (Verification)

**Files:**
- Toàn bộ dự án

- [ ] **Step 1: Chạy phân tích tĩnh mã nguồn**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Chạy toàn bộ test suites**

Run: `flutter test`
Expected: Tất cả bài test vượt qua (100% pass), không có failure nào.

- [ ] **Step 3: Cập nhật `README.md` với số liệu test mới nhất và bằng chứng kiểm toán**

Ghi nhận số lượng test pass mới (370+ test cases), ghi chú rõ các test RLS integration và kết quả chạy `flutter analyze`.

- [ ] **Step 4: Commit và Push lên `main`**

```bash
git add README.md
git commit -m "docs: cập nhật số liệu kiểm thử và kết quả rà soát toàn diện hệ thống"
git push origin main
```
