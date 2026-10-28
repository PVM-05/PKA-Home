# Kế Hoạch Triển Khai: Cổng Thanh Toán Mô Phỏng (Demo Payment Gateway & Transactions)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống cổng thanh toán mô phỏng (Demo Payment Simulation) chuẩn kiến trúc thanh toán doanh nghiệp cho PKA-Home, cho phép cư dân thanh toán hóa đơn với 3 kịch bản (Thành công, Thất bại, Hủy) mà không cần chuyển tiền thật hay qua bước duyệt thủ công, quản lý lịch sử giao dịch qua bảng `payment_transactions` và RPC nguyên tử bảo mật.

**Architecture:** Sử dụng PostgreSQL Function `simulate_invoice_payment` với thuộc tính `SECURITY DEFINER` và khóa dòng `FOR UPDATE` để đảm bảo client Flutter không thể tự ý cập nhật trạng thái `paid`. Mọi giao dịch được ghi nhận vào bảng `payment_transactions`, tích hợp Supabase Realtime đẩy cập nhật tức thì tới UI cư dân và Ban Quản Lý.

**Tech Stack:** Flutter (Dart 3.x), Riverpod, Supabase Database, PostgreSQL RPC, Supabase Realtime, RLS Policies.

## Global Constraints

- **Language:** 100% Tiếng Việt chuẩn mực trên mọi màn hình, nhãn dán, mã giao dịch và thông báo lỗi.
- **Bảo mật:** Client tuyệt đối không được gọi `UPDATE invoices SET status = 'paid'` trực tiếp; mọi thao tác phải qua RPC `simulate_invoice_payment`.
- **UI/UX:** Loại bỏ hoàn toàn VietQR; thay thế bằng Bottom Sheet Cổng thanh toán Demo với tóm tắt các khoản phí và Modal xác nhận 3 kịch bản (`Thành công`, `Thất bại`, `Hủy`).
- **TDD:** Viết unit test và widget test xác minh độc lập; bảo đảm toàn bộ 171/171 test cases hiện có tiếp tục PASS 100%.

---

### Task 1: Migration Cơ Sở Dữ Liệu (`payment_transactions`, Cột Mới & RPC `simulate_invoice_payment`)

**Files:**
- Create: `supabase/migrations/20261005_02_demo_payment_simulation.sql`

**Interfaces:**
- Table `public.payment_transactions` (id, invoice_id, user_id, apartment_id, amount, payment_method, status, transaction_code, failure_reason, created_at).
- Bổ sung cột vào `public.invoices`: `payment_method VARCHAR(50)`, `transaction_code VARCHAR(100)`, `paid_at TIMESTAMPTZ`.
- RPC: `public.simulate_invoice_payment(p_invoice_id UUID, p_outcome VARCHAR) -> JSONB`.
- RLS Policies cho `public.payment_transactions`.

- [ ] **Step 1: Soạn file migration `supabase/migrations/20261005_02_demo_payment_simulation.sql`**
- [ ] **Step 2: Kiểm tra cấu trúc RPC, kiểm soát quyền căn hộ và giao dịch nguyên tử**
- [ ] **Step 3: Commit file migration vào git**

```bash
git add supabase/migrations/20261005_02_demo_payment_simulation.sql
git commit -m "feat(db): tạo migration bảng payment_transactions và rpc simulate_invoice_payment"
```

---

### Task 2: Data Model `PaymentTransactionModel` & Unit Tests

**Files:**
- Create: `lib/data/models/payment_transaction_model.dart`
- Create: `test/data/models/payment_transaction_model_test.dart`

**Interfaces:**
- `PaymentTransactionModel`:
  - `id`, `invoiceId`, `userId`, `apartmentId`, `amount`, `paymentMethod`, `status`, `transactionCode`, `failureReason`, `createdAt`.
  - Getters: `isSuccess`, `isFailed`, `isCancelled`, `formattedAmount`, `statusDisplayName`.
  - `fromJson`, `toJson`.

- [ ] **Step 1: Viết failing test trong `test/data/models/payment_transaction_model_test.dart`**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Hiện thực `PaymentTransactionModel` trong `lib/data/models/payment_transaction_model.dart`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/data/models/payment_transaction_model.dart test/data/models/payment_transaction_model_test.dart
git commit -m "feat(model): tạo PaymentTransactionModel và bộ unit tests"
```

---

### Task 3: Tầng Dịch Vụ / Repository Gọi RPC Thanh Toán Mô Phỏng

**Files:**
- Modify: `lib/features/resident/services/resident_invoice_service.dart`
- Create: `test/features/resident/services/resident_invoice_service_test.dart`

**Interfaces:**
- `ResidentInvoiceService`:
  - `simulatePayment({required WidgetRef ref, required String invoiceId, required String outcome}) -> Future<Map<String, dynamic>>`:
    - Gọi Supabase RPC `simulate_invoice_payment`.
    - Tự động làm mới `invoicesProvider` và `residentInvoicesProvider`.

- [ ] **Step 1: Viết unit test cho `simulatePayment` trong `test/features/resident/services/resident_invoice_service_test.dart`**
- [ ] **Step 2: Hiện thực phương thức `simulatePayment` trong `ResidentInvoiceService`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/features/resident/services/ test/features/resident/services/
git commit -m "feat(service): bổ sung phương thức simulatePayment gọi RPC simulate_invoice_payment"
```

---

### Task 4: Giao Diện Cổng Thanh Toán Demo (`DemoPaymentBottomSheet` & Hộp Thoại Mô Phỏng)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Create: `test/features/resident/demo_payment_sheet_test.dart`

**Interfaces:**
- Thay thế hoàn toàn `_showPaymentBottomSheet` (VietQR) bằng giao diện Cổng Thanh Toán Demo:
  - Header hiện đại với icon thẻ thanh toán và logo Demo Gateway.
  - Bảng tóm tắt các mục phí (Phí quản lý, nước, xe...) và tổng tiền nổi bật.
  - Nút "TIẾN HÀNH THANH TOÁN" mở Dialog chọn 3 kịch bản:
    - `[✓ Thanh toán thành công (Mô phỏng)]`: Gọi `simulatePayment(..., 'SUCCESS')`, hiển thị hiệu ứng thành công, cập nhật hóa đơn sang `paid` và lưu mã giao dịch `PAY-YYYYMMDD-XXXXX`.
    - `[✕ Thanh toán thất bại (Mô phỏng)]`: Gọi `simulatePayment(..., 'FAILED')`, báo lỗi "Thanh toán thất bại", hóa đơn vẫn là `unpaid`.
    - `[Hủy]`: Đóng dialog.
- Cập nhật Biên nhận điện tử hiển thị mã giao dịch `transaction_code` và phương thức `Demo Payment`.

- [x] **Step 1: Viết widget test kiểm tra hiển thị Bottom Sheet và Dialog mô phỏng**
- [x] **Step 2: Cập nhật `ResidentInvoiceDetailScreen` tích hợp Cổng thanh toán Demo**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/resident/screens/resident_invoice_detail_screen.dart test/features/resident/
git commit -m "feat(ui): tích hợp cổng thanh toán mô phỏng demo payment thay thế hoàn toàn vietqr"
```

---

### Task 5: Rà Soát Toàn Diện, Phân Tích Tĩnh & Nghiệm Thu (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [x] **Step 1: Chạy `dart analyze` đảm bảo 0 cảnh báo/lỗi**
- [x] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [x] **Step 3: Báo cáo kết quả và sẵn sàng chạy demo trực tiếp**
