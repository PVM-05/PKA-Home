# Kế Hoạch Triển Khai: Webhook Ngân Hàng Bảo Mật & Cổng Thanh Toán VNPay Thực Tế

- **Mục tiêu:**
  1. Bảo vệ cổng Webhook ngân hàng: Thu hồi quyền gọi trực tiếp của client đối với các RPC gạch nợ; chuyển sang Supabase Edge Function có xác thực token / HMAC-SHA256 với quyền `service_role`.
  2. Bổ sung cấu hình VNPay trong CSDL và tạo Edge Function `vnpay-ipn` tiếp nhận đối soát thanh toán trực tuyến.
  3. Xây dựng `VnpayService` trên Flutter client tạo URL thanh toán ký bằng HMAC-SHA512.
  4. Nâng cấp `UnifiedPaymentSheet` hỗ trợ song hành: Chuyển khoản VietQR Napas 247 và Cổng thanh toán VNPay.
  5. Đạt 0 issues trên `dart analyze lib test` và 100% test suite xanh.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).

---

## Danh Sách Nhiệm Vụ Chi Tiết

### Task 1: Migration PostgreSQL Cắt Quyền Client RPC & Bổ Sung Cấu Hình VNPay
**Tệp:**
- Tạo mới: `supabase/migrations/20261114_01_secure_bank_webhook_and_vnpay.sql`
- Kiểm thử: `test/integration/secure_bank_webhook_migration_test.dart`

- [x] **Step 1:** Viết file migration SQL:
  - Thu hồi quyền `EXECUTE` trên `process_bank_payment_webhook` và `process_sepay_webhook` khỏi `PUBLIC`, `anon`, `authenticated`.
  - Cấp quyền `EXECUTE` duy nhất cho `service_role`.
  - Mở rộng bảng `building_payment_configs` thêm các cột: `vnpay_tmn_code TEXT`, `vnpay_hash_secret TEXT`, `vnpay_is_active BOOLEAN DEFAULT false`.
- [x] **Step 2:** Viết test `test/integration/secure_bank_webhook_migration_test.dart` xác nhận file migration tồn tại, có đầy đủ lệnh REVOKE/GRANT và cột VNPay.
- [x] **Step 3:** Chạy test kiểm tra: `flutter test test/integration/secure_bank_webhook_migration_test.dart`.
- [x] **Step 4:** Commit vào `main`: `feat(finance): migration bao ve rpc webhook ngan hang va bo sung vnpay`.

---

### Task 2: Hoàn Thiện & Bảo Vệ Supabase Edge Functions (SePay & VNPay IPN)
**Tệp:**
- Chỉnh sửa: `supabase/functions/sepay-webhook/index.ts`
- Tạo mới: `supabase/functions/vnpay-ipn/index.ts`

- [x] **Step 1:** Chuẩn hóa `sepay-webhook/index.ts`: Bắt buộc kiểm tra API Key từ Header `Authorization` / `x-sepay-key`, gọi RPC bằng `SUPABASE_SERVICE_ROLE_KEY`.
- [x] **Step 2:** Tạo `vnpay-ipn/index.ts`: Tiếp nhận IPN từ VNPay, sắp xếp query params, xác thực chữ ký HMAC-SHA512 `vnp_SecureHash`, gọi RPC gạch nợ an toàn bằng `service_role`.
- [x] **Step 3:** Commit vào `main`: `feat(functions): hoan thien edge function sepay webhook va vnpay ipn`.

---

### Task 3: Triển Khai `VnpayService` Ký Chữ Ký Số HMAC-SHA512
**Tệp:**
- Chỉnh sửa: `lib/data/models/building_payment_config_model.dart`
- Tạo mới: `lib/core/services/vnpay_service.dart`
- Kiểm thử: `test/core/services/vnpay_service_test.dart`

- [x] **Step 1:** Cập nhật `BuildingPaymentConfigModel` hỗ trợ `vnpayTmnCode`, `vnpayHashSecret`, `vnpayIsActive`.
- [x] **Step 2:** Viết kịch bản test TDD cho `VnpayService`: kiểm tra thuật toán sắp xếp URL params theo ASCII, băm chữ ký HMAC-SHA512 chuẩn xác, và kiểm tra tính toàn vẹn khi callback.
- [x] **Step 3:** Hiện thực hóa `VnpayService` trong `lib/core/services/vnpay_service.dart`.
- [x] **Step 4:** Chạy test: `flutter test test/core/services/vnpay_service_test.dart`.
- [x] **Step 5:** Commit vào `main`: `feat(finance): trien khai vnpay service ky so hmac sha512`.

---

### Task 4: Tích Hợp VNPay Vào `UnifiedPaymentSheet` & `PaymentService`
**Tệp:**
- Chỉnh sửa: `lib/data/services/payment_service.dart`
- Chỉnh sửa: `lib/core/widgets/unified_payment_sheet.dart`
- Kiểm thử: `test/core/widgets/unified_payment_sheet_vnpay_test.dart`

- [ ] **Step 1:** Bổ sung phương thức `createVnpayPaymentUrl` trong `PaymentService`.
- [ ] **Step 2:** Cập nhật `UnifiedPaymentSheet`:
  - Thêm phương thức thanh toán `'vnpay'` bên cạnh `'bank_transfer'` và `'cash'`.
  - Hiển thị nút "MỞ CỔNG VNPAY" dẫn tới URL thanh toán nếu tòa nhà đã kích hoạt VNPay.
- [ ] **Step 3:** Viết test `unified_payment_sheet_vnpay_test.dart` kiểm tra chuyển đổi phương thức VNPay và hiển thị nút thanh toán hợp lệ.
- [ ] **Step 4:** Chạy test: `flutter test test/core/widgets/unified_payment_sheet_vnpay_test.dart`.
- [ ] **Step 5:** Commit vào `main`: `feat(ui): tich hop cong thanh toan vnpay vao unified payment sheet`.

---

### Task 5: Rà Soát Toàn Bộ, Static Analysis & Cập Nhật Tri Thức
- [ ] **Step 1:** Chạy `dart analyze lib test` (đảm bảo 0 issues).
- [ ] **Step 2:** Chạy toàn bộ các tệp test liên quan đến thanh toán.
- [ ] **Step 3:** Cập nhật đồ thị tri thức `graphify update .`.
- [ ] **Step 4:** Commit hoàn tất kế hoạch vào `main`: `chore: hoan thanh he thong dong tien that vnpay va webhook ngan hang`.

