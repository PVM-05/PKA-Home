# Kế Hoạch Triển Khai: Bản Vá Bảo Mật CSDL & Sửa Lỗi Logic Nghiệp Vụ Toàn Diện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục toàn bộ các lỗ hổng bảo mật RPC/RLS (hóa đơn, xe cộ, chỉ số, tiện ích, giao dịch) và sửa các lỗi logic Dart (AppException, format ngày, thống kê doanh thu, auth/router).

**Architecture:**
- CSDL: Migration `20261007_02_fix_critical_security_and_policies.sql` với RLS chặt chẽ, trigger kiểm soát cập nhật, các RPC có guard `is_admin_or_accountant()` và hàm nguyên tử `record_manual_payment`.
- Flutter/Dart: Tạo lớp `AppException`, nâng cấp `NetworkErrorHandler`, chuẩn hóa gửi ngày `yyyy-MM-dd`, sửa thuật toán tránh đếm đôi doanh thu trong `dashboard_providers`, reactive UI trong `resident_invoice_detail_screen`, bảo vệ luồng auth và OTP reset password trong `app_router`.

**Tech Stack:** PostgreSQL (Supabase RLS/RPC/Trigger), Flutter 3.x, Dart 3.x, Riverpod 2.x, GoRouter.

## Global Constraints
- Tuân thủ nghiêm ngặt `coding-rules.md`, `database-rules.md`, `design-rules.md`.
- 100% tiếng Việt chuẩn mực trong giao diện và thông báo người dùng cuối.
- Không phá vỡ bất kỳ test case nào trong tổng số 262 bài kiểm tra hiện có.

---

### Task 1: Migration CSDL Khắc Phục Toàn Diện Lỗ Hổng Bảo Mật & RLS

**Files:**
- Create: `supabase/migrations/20261007_02_fix_critical_security_and_policies.sql`
- Test: `test/data/migrations/p0_security_migration_content_test.dart`

**Interfaces:**
- Produces:
  - RPC `public.create_invoice_with_items` (guard `is_admin_or_accountant()`)
  - RPC `public.update_invoice_with_items` (guard `is_admin_or_accountant()`)
  - RPC `public.record_manual_payment(UUID, VARCHAR, TEXT)`
  - Policy INSERT `vehicles` (status='pending' & rejection_reason IS NULL)
  - Policy INSERT `meter_reading_submissions` (status='pending' & submitted_by=auth.uid())
  - Policy DELETE `apartment_link_requests` (status='rejected')
  - Trigger `trg_check_amenity_booking_resident_update` on `amenity_bookings`

- [ ] **Step 1: Viết test kiểm tra nội dung migration bảo mật**

```dart
// test/data/migrations/p0_security_migration_content_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 20261007_02 chứa đầy đủ các bản vá bảo mật RPC và RLS', () {
    final file = File('supabase/migrations/20261007_02_fix_critical_security_and_policies.sql');
    expect(file.existsSync(), isTrue, reason: 'File migration 20261007_02 phải tồn tại');
    
    final content = file.readAsStringSync();
    expect(content.contains('is_admin_or_accountant()'), isTrue);
    expect(content.contains('create_invoice_with_items'), isTrue);
    expect(content.contains('update_invoice_with_items'), isTrue);
    expect(content.contains('record_manual_payment'), isTrue);
    expect(content.contains("rejection_reason IS NULL"), isTrue);
    expect(content.contains("submitted_by = auth.uid()"), isTrue);
    expect(content.contains("Cư dân đặt lịch tiện ích"), isTrue);
    expect(content.contains("simulate_invoice_payment"), isTrue);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận thất bại trước khi viết migration**

Chạy: `flutter test test/data/migrations/p0_security_migration_content_test.dart`
Kỳ vọng: FAIL vì file chưa tồn tại.

- [ ] **Step 3: Viết file migration `20261007_02_fix_critical_security_and_policies.sql`**

Viết migration hoàn chỉnh chứa:
1. `create_invoice_with_items` và `update_invoice_with_items` có kiểm tra `is_admin_or_accountant()`, `REVOKE ... FROM anon, PUBLIC;` và `GRANT TO authenticated;`.
2. `vehicles`: Cập nhật policy INSERT với `status = 'pending' AND rejection_reason IS NULL`.
3. `meter_reading_submissions`: Cập nhật policy INSERT với `status = 'pending' AND (submitted_by = auth.uid() OR submitted_by IS NULL)`.
4. `amenity_bookings`: DROP policy INSERT `Cư dân đặt lịch tiện ích`. Thêm trigger `BEFORE UPDATE` chỉ cho phép cư dân đổi sang `status = 'cancelled'`.
5. `payment_transactions`: Siết policy sang `is_admin_or_accountant()`.
6. `record_manual_payment`: Tạo RPC nguyên tử `FOR UPDATE` cho BQL thu tiền.
7. `apartment_link_requests`: Thêm policy DELETE cho cư dân khi `status = 'rejected'`.
8. `DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID);`.

- [ ] **Step 4: Chạy test để xác nhận vượt qua**

Chạy: `flutter test test/data/migrations/p0_security_migration_content_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261007_02_fix_critical_security_and_policies.sql test/data/migrations/p0_security_migration_content_test.dart
git commit -m "fix(db): bản vá bảo mật RPC hóa đơn, RLS phương tiện, tiện ích và giao dịch"
```

---

### Task 2: Chuẩn Hóa Xử Lý Lỗi Nghiệp Vụ (`AppException` & `NetworkErrorHandler`)

**Files:**
- Create: `lib/core/errors/app_exception.dart`
- Modify: `lib/core/utils/network_error_handler.dart`
- Modify: `test/core/utils/network_error_handler_test.dart`
- Modify: `lib/data/providers/link_request_provider.dart`

**Interfaces:**
- Produces:
  - `class AppException implements Exception`
  - `NetworkErrorHandler.getMessage(error)` xử lý `AppException` và `P0001` tiếng Việt.

- [ ] **Step 1: Cập nhật unit test kiểm tra xử lý `AppException` và lỗi CSDL**

Thêm các test case trong `test/core/utils/network_error_handler_test.dart`:
- `AppException('Thông điệp tiếng Việt cụ thể')` phải giữ nguyên chuỗi.
- `PostgrestException` với `code == 'P0001'` phải giữ nguyên `message`.
- `PostgrestException` với lỗi cú pháp tiếng Anh không có code P0001 phải trả về câu tiếng Việt thân thiện, không để lộ tiếng Anh.

- [ ] **Step 2: Chạy test để xác nhận thất bại**

Chạy: `flutter test test/core/utils/network_error_handler_test.dart`
Kỳ vọng: FAIL do `AppException` chưa được định nghĩa.

- [ ] **Step 3: Tạo `lib/core/errors/app_exception.dart` và cập nhật `NetworkErrorHandler`**

- Tạo `AppException`:
```dart
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
```
- Cập nhật `NetworkErrorHandler.getMessage`:
  - `if (error is AppException) return error.message;`
  - Với `PostgrestException`:
    - Nếu `error.code == 'P0001'`: return `error.message`.
    - Nếu `error.code == '23505'`: return 'Dữ liệu hoặc khung giờ đã tồn tại trong hệ thống. Vui lòng kiểm tra lại.';
    - Không để lộ lỗi kỹ thuật cú pháp.
- Đổi các `throw Exception('...')` trong `link_request_provider.dart` sang `throw AppException('...')`.

- [ ] **Step 4: Chạy lại test xác nhận thành công**

Chạy: `flutter test test/core/utils/network_error_handler_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/errors/app_exception.dart lib/core/utils/network_error_handler.dart test/core/utils/network_error_handler_test.dart lib/data/providers/link_request_provider.dart
git commit -m "fix(core): chuẩn hóa AppException và xử lý thông báo lỗi tiếng Việt thân thiện"
```

---

### Task 3: Chuẩn Hóa Format Ngày & Bổ Sung RPC Thu Tiền Nguyên Tử Trong Repository

**Files:**
- Modify: `lib/data/repositories/management_repository.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`

**Interfaces:**
- Produces:
  - `managementRepository.generateValidBulkInvoices` gửi `p_due_date` dạng `yyyy-MM-dd`.
  - `managementRepository.recordManualPayment(invoiceId, paymentMethod, notes)`.
  - Xóa `generateMonthlyBulkInvoices` cũ.

- [ ] **Step 1: Viết test cho `recordManualPayment` và tham số ngày `dueDate`**

- [ ] **Step 2: Chạy test xác nhận thất bại**

- [ ] **Step 3: Cập nhật `management_repository.dart` và `management_invoice_detail_screen.dart`**
- Trong `generateValidBulkInvoices`:
  ```dart
  'p_due_date': dueDate.toIso8601String().split('T')[0],
  ```
- Thêm method `recordManualPayment`:
  ```dart
  Future<void> recordManualPayment({
    required String invoiceId,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    await _client.rpc('record_manual_payment', params: {
      'p_invoice_id': invoiceId,
      'p_payment_method': paymentMethod,
      'p_notes': notes,
    });
  }
  ```
- Cập nhật `_confirmPayment` trong `management_invoice_detail_screen.dart` gọi `recordManualPayment` nguyên tử thay vì 2 bước riêng biệt.

- [ ] **Step 4: Chạy test xác nhận thành công**

Chạy: `flutter test test/features/management/management_invoice_screen_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/management_repository.dart lib/features/management/screens/management_invoice_detail_screen.dart
git commit -m "fix(invoice): format ngày chuẩn yyyy-MM-dd và thu tiền nguyên tử qua RPC"
```

---

### Task 4: Sửa Thuật Toán Doanh Thu (Tránh Đếm Đôi) & Chọn Kỳ Mới Nhất

**Files:**
- Modify: `lib/data/providers/dashboard_providers.dart`
- Test: `test/data/providers/dashboard_providers_test.dart`

**Interfaces:**
- `monthlyRevenueTrendProvider`: Chỉ fallback `created_at` khi `invPeriod` rỗng hoặc không phân tích được thành `MM/yyyy`.
- `financialStatsProvider`: Sắp xếp các chu kỳ `MM/yyyy` tìm kỳ có thời gian lớn nhất.

- [ ] **Step 1: Viết test kiểm tra không bị đếm đôi và chọn đúng kỳ mới nhất**

Tạo `test/data/providers/dashboard_providers_test.dart` với dữ liệu mẫu:
- Hóa đơn kỳ "09/2026" tạo vào tháng 10/2026 -> chỉ được tính vào tháng 9, không tính vào tháng 10.
- Danh sách hóa đơn gồm kỳ "08/2026" và "09/2026" (thứ tự ngẫu nhiên) -> `financialStatsProvider` phải chọn kỳ "09/2026".

- [ ] **Step 2: Chạy test xác nhận thất bại**

Chạy: `flutter test test/data/providers/dashboard_providers_test.dart`
Kỳ vọng: FAIL.

- [ ] **Step 3: Cập nhật `dashboard_providers.dart`**
- Trong `monthlyRevenueTrendProvider`:
  - Kiểm tra xem `invPeriod` có dạng hợp lệ `\d{1,2}/\d{4}` không. Nếu có nhưng không khớp chu kỳ đang xét thì KHÔNG fallback sang `created_at`.
- Trong `financialStatsProvider`:
  - Phân tích danh sách chu kỳ thành `DateTime(year, month)` và tìm kỳ lớn nhất.

- [ ] **Step 4: Chạy test xác nhận thành công**

Chạy: `flutter test test/data/providers/dashboard_providers_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/providers/dashboard_providers.dart test/data/providers/dashboard_providers_test.dart
git commit -m "fix(dashboard): chống đếm trùng doanh thu và chuẩn hóa chọn kỳ thống kê mới nhất"
```

---

### Task 5: Cập Nhật Trực Tiếp Giao Diện Chi Tiết Hóa Đơn Cư Dân

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Test: `test/features/resident/resident_invoice_screen_test.dart`

**Interfaces:**
- `ResidentInvoiceDetailScreen`: Lắng nghe hóa đơn thời gian thực từ provider thay vì chỉ giữ `widget.invoice` tĩnh.

- [ ] **Step 1: Viết test xác nhận giao diện cập nhật sang "Đã thanh toán" khi trạng thái thay đổi**

- [ ] **Step 2: Chạy test xác nhận**

- [ ] **Step 3: Cập nhật `resident_invoice_detail_screen.dart`**
- Lấy thông tin hóa đơn mới nhất từ `residentInvoicesStreamProvider`:
  ```dart
  final invoicesAsync = ref.watch(residentInvoicesStreamProvider);
  final currentInvoice = invoicesAsync.valueOrNull?.firstWhere(
    (inv) => inv.id == widget.invoice.id,
    orElse: () => widget.invoice,
  ) ?? widget.invoice;
  ```
- Sử dụng `currentInvoice` để hiển thị trạng thái và nút hành động.

- [ ] **Step 4: Chạy test xác nhận thành công**

Chạy: `flutter test test/features/resident/resident_invoice_screen_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/resident/screens/resident_invoice_detail_screen.dart
git commit -m "fix(resident): cập nhật tự động trạng thái đã thanh toán trên màn hình chi tiết"
```

---

### Task 6: Luồng Quản Lý Khóa Tài Khoản & Bảo Vệ Điều Hướng OTP Reset Mật Khẩu

**Files:**
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/data/repositories/auth_repository_test.dart`

**Interfaces:**
- `accountLockedNoticeProvider`: Báo hiệu tài khoản bị khóa cho người dùng.
- `app_router.dart`: Không tự động redirect về trang chủ khi người dùng đang ở `/verify-otp` hoặc `/reset-password`.

- [ ] **Step 1: Viết test kiểm tra trạng thái khóa tài khoản và router redirect**

- [ ] **Step 2: Chạy test xác nhận thất bại**

- [ ] **Step 3: Cập nhật `auth_provider.dart` và `app_router.dart`**
- Trong `auth_provider.dart`:
  - Khởi tạo `final accountLockedNoticeProvider = StateProvider<bool>((ref) => false);`.
  - Trong `_fetchUserInfo`:
    ```dart
    if (userModel.isLocked) {
      _ref?.read(accountLockedNoticeProvider.notifier).state = true;
      await logout();
      state = const AsyncValue.data(null);
      return;
    }
    ```
  - Nếu `state.valueOrNull?.id == userId` thì không gán `AsyncValue.loading()` gây nháy toàn bộ giao diện.
- Trong `app_router.dart`:
  - Thêm kiểm tra trong `redirect`: Nếu `state.matchedLocation == AppRoutes.verifyOtp || state.matchedLocation == AppRoutes.resetPassword`, không tự động redirect người dùng ra trang chủ.

- [ ] **Step 4: Chạy test xác nhận thành công**

Chạy: `flutter test test/data/repositories/auth_repository_test.dart`
Kỳ vọng: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/providers/auth_provider.dart lib/core/router/app_router.dart
git commit -m "fix(auth): thông báo khóa tài khoản độc lập và bảo vệ luồng OTP reset mật khẩu"
```

---

### Task 7: Kiểm Thử Toàn Diện Hệ Thống (Full Regression Testing)

**Files:**
- Test: Toàn bộ suite `test/`

- [ ] **Step 1: Chạy toàn bộ test suite dự án**

Chạy: `flutter test`
Kỳ vọng: 100% test cases (265+ tests) vượt qua thành công, 0 lỗi.

- [ ] **Step 2: Phân tích cảnh báo tĩnh**

Chạy: `flutter analyze`
Kỳ vọng: Không có cảnh báo hoặc lỗi cú pháp mới.

- [ ] **Step 3: Báo cáo kết quả tổng thể và xác minh**
