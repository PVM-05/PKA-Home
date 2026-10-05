# Kế Hoạch Triển Khai: Hợp Nhất Tài Chính & Dịch Vụ Chung Cư (Unified Demo Payment)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống thanh toán mô phỏng dùng chung (Unified Demo Payment) phục vụ demo đồ án cho cả hai mảng Tài chính (Hóa đơn tháng) và Dịch vụ (Gym, Hồ bơi, Sân thể thao) với quy trình 3 bước trực quan, tự động gạch nợ và sinh mã kiểm toán `DEMO-YYYYMMDD-XXX`.

**Architecture:** Áp dụng mô hình Feature-first kết hợp tầng dùng chung Core. Tầng backend dùng PostgreSQL RPC nguyên tử `simulate_unified_payment` đảm bảo tính toàn vẹn dữ liệu. Tầng UI dùng `UnifiedPaymentSheet` quản lý State Machine 3 bước (Xác nhận $\rightarrow$ Đang xử lý 1.2s $\rightarrow$ Thành công) được gọi từ `PaymentService`.

**Tech Stack:** Flutter 3.x, Flutter Riverpod, Supabase (PostgreSQL RPC, RLS, Realtime), qr_flutter (QR check-in & gửi xe).

## Global Constraints

- 100% ngôn ngữ tiếng Việt chuẩn mực trên toàn bộ giao diện người dùng.
- Không sử dụng tiền thật hay cổng thanh toán thực tế (loại bỏ yêu cầu quét QR thật hoặc nhập thẻ ngân hàng).
- Phương thức thanh toán duy nhất: `◉ Demo Payment (Giao dịch mô phỏng)`.
- Mã giao dịch sinh tự động theo chuẩn: `DEMO-YYYYMMDD-XXX`.
- Sau khi thanh toán: Hóa đơn chuyển trạng thái `paid`, Lịch đặt dịch vụ chuyển trạng thái `confirmed`.
- Toàn bộ thay đổi phải có test cases và pass 100% `dart analyze` và `flutter test`.

---

### Task 1: Migration Database & RPC `simulate_unified_payment`

**Files:**
- Create: `supabase/migrations/20261005_03_unified_payment_simulation.sql`
- Test: `test/data/repositories/unified_payment_migration_schema_test.dart`

**Interfaces:**
- Produces: Bảng `public.payment_transactions` mở rộng (thêm `type`, `booking_id`, `title`, nullable `invoice_id`), RPC `simulate_unified_payment(p_type, p_reference_id, p_outcome)`.

- [ ] **Step 1: Viết test kiểm tra schema migration và câu lệnh RPC**
- [ ] **Step 2: Viết migration file `20261005_03_unified_payment_simulation.sql`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add supabase/migrations/20261005_03_unified_payment_simulation.sql test/data/repositories/unified_payment_migration_schema_test.dart
git commit -m "feat(db): tạo migration bảng payment_transactions mở rộng và rpc simulate_unified_payment"
```

---

### Task 2: Data Models & Service Layer (`PaymentType`, `PaymentResult`, `PaymentService`)

**Files:**
- Modify: `lib/data/models/payment_transaction_model.dart`
- Create: `lib/data/services/payment_service.dart`
- Create: `lib/data/providers/payment_provider.dart`
- Create: `test/data/services/payment_service_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum PaymentType { invoice, service }
  class PaymentResult {
    final bool success;
    final String transactionCode;
    final String transactionId;
    final double amount;
    final String title;
    final DateTime paidAt;
    final String? errorMessage;
  }
  class PaymentService {
    Future<PaymentResult> pay({
      required WidgetRef ref,
      required PaymentType type,
      required String referenceId,
      String outcome = 'SUCCESS',
    });
  }
  ```

- [ ] **Step 1: Viết unit test cho `PaymentService` và `PaymentTransactionModel`**
- [ ] **Step 2: Cập nhật `PaymentTransactionModel` hỗ trợ `type`, `booking_id`, `title`**
- [ ] **Step 3: Cài đặt `PaymentService` và `paymentServiceProvider` gọi RPC `simulate_unified_payment`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/data/models/payment_transaction_model.dart lib/data/services/ lib/data/providers/payment_provider.dart test/data/services/
git commit -m "feat(service): triển khai PaymentService hỗ trợ thanh toán cả hóa đơn và dịch vụ"
```

---

### Task 3: Component Dùng Chung `UnifiedPaymentSheet`

**Files:**
- Create: `lib/core/widgets/unified_payment_sheet.dart`
- Create: `test/core/widgets/unified_payment_sheet_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<PaymentResult?> showUnifiedPaymentSheet({
    required BuildContext context,
    required WidgetRef ref,
    required PaymentType type,
    required String referenceId,
    required String title,
    required String referenceCode,
    required double amount,
    List<Map<String, dynamic>>? feeBreakdown,
  });
  ```
- Quản lý 3 trạng thái:
  1. `Confirmation`: Tiêu đề, Mã đơn, Tổng tiền to đậm, `◉ Demo Payment`, nút `[ THANH TOÁN ]`.
  2. `Processing`: Hiển thị `⏳ Đang xử lý giao dịch...` (trễ 1.2s - 1.5s với animation chấm nhảy).
  3. `Success`: Icon xanh `✓`, `Thanh toán thành công`, mã `DEMO-...`, ngày giờ, nút `[ HOÀN TẤT ]`.

- [ ] **Step 1: Viết widget test kiểm tra quy trình 3 bước của `UnifiedPaymentSheet`**
- [ ] **Step 2: Triển khai widget `UnifiedPaymentSheet` với thiết kế giao diện chuẩn Segoe UI / Google Fonts**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/core/widgets/unified_payment_sheet.dart test/core/widgets/unified_payment_sheet_test.dart
git commit -m "feat(ui): tạo widget modal dùng chung UnifiedPaymentSheet 3 trạng thái"
```

---

### Task 4: Tích Hợp Vào Hóa Đơn Tháng (`ResidentInvoiceDetailScreen`)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Create: `test/features/resident/resident_invoice_unified_payment_test.dart`

**Interfaces:**
- Nút `[ THANH TOÁN NGAY ]` mở `showUnifiedPaymentSheet` với `type: PaymentType.invoice`.
- Sau khi thành công: Cập nhật UI ngay sang `Đã thanh toán`, hiển thị nút `[ XEM BIÊN NHẬN ĐIỆN TỬ ]` với mã `DEMO-...`.

- [ ] **Step 1: Viết widget test kiểm tra thanh toán hóa đơn bằng `UnifiedPaymentSheet`**
- [ ] **Step 2: Cập nhật `ResidentInvoiceDetailScreen` gọi `showUnifiedPaymentSheet`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/features/resident/screens/resident_invoice_detail_screen.dart test/features/resident/resident_invoice_unified_payment_test.dart
git commit -m "feat(resident): tích hợp UnifiedPaymentSheet vào màn hình chi tiết hóa đơn"
```

---

### Task 5: Tích Hợp Vào Đặt Dịch Vụ Chung Cư (`AmenityBookingScreen` & QR Check-in)

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Create: `test/features/resident/amenity_booking_unified_payment_test.dart`

**Interfaces:**
- Khi đặt dịch vụ có phí (Gym, Hồ bơi, Sân cầu lông) $\rightarrow$ Mở `showUnifiedPaymentSheet` với `type: PaymentType.service`.
- Sau khi thanh toán thành công: Cập nhật booking sang `confirmed`, hiển thị dialog mã đặt chỗ kèm **Mã QR Check-in** (sử dụng Custom QR Canvas hoặc `qr_flutter`).

- [ ] **Step 1: Viết widget test cho luồng đặt dịch vụ và thanh toán qua `UnifiedPaymentSheet`**
- [ ] **Step 2: Cập nhật `AmenityBookingScreen` mở `showUnifiedPaymentSheet` khi có phí và hiển thị dialog QR**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/features/resident/screens/amenity_booking_screen.dart test/features/resident/amenity_booking_unified_payment_test.dart
git commit -m "feat(amenity): tích hợp UnifiedPaymentSheet và mã QR Check-in cho đặt dịch vụ"
```

---

### Task 6: Màn Hình Lịch Sử Thanh Toán Gom Chung (`PaymentHistoryScreen`)

**Files:**
- Create: `lib/features/resident/screens/payment_history_screen.dart`
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`
- Create: `test/features/resident/payment_history_screen_test.dart`

**Interfaces:**
- Màn hình hiển thị danh sách mọi giao dịch (Hóa đơn & Dịch vụ) từ `payment_transactions`.
- Bộ lọc Chips: `[ Tất cả ]`, `[ 🏠 Hóa đơn ]`, `[ 🏋️ Dịch vụ ]`.
- Tích hợp liên kết từ `ResidentProfileScreen` mục "Lịch sử thanh toán".

- [ ] **Step 1: Viết widget test cho `PaymentHistoryScreen` và bộ lọc giao dịch**
- [ ] **Step 2: Xây dựng `PaymentHistoryScreen` và provider tải danh sách giao dịch**
- [ ] **Step 3: Gắn điều hướng từ `ResidentProfileScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/features/resident/screens/payment_history_screen.dart lib/features/resident/screens/resident_profile_screen.dart test/features/resident/payment_history_screen_test.dart
git commit -m "feat(resident): xây dựng màn hình Lịch sử thanh toán gom chung có bộ lọc danh mục"
```

---

### Task 7: Rà Soát Toàn Diện, Phân Tích Tĩnh & Nghiệm Thu (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy `dart analyze` toàn dự án đảm bảo 0 lỗi/cảnh báo**
- [ ] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [ ] **Step 3: Kiểm tra trạng thái Git working tree sạch sẽ**
- [ ] **Step 4: Hướng dẫn kịch bản demo hoàn chỉnh cho người dùng**
