# Kế Hoạch Triển Khai: Cổng Thanh Toán VietQR Tự Động 100% Qua SePay Webhook (Production Real-Payment Engine)

> **Dành cho kỹ sư triển khai:** BẮT BUỘC SỬ DỤNG KỸ NĂNG: `superpowers:subagent-driven-development` hoặc `superpowers:executing-plans` để thực thi kế hoạch theo từng nhiệm vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng hệ thống thanh toán thật cấp độ sản xuất (Production Real-Payment) cho PKA-Home B2B SaaS, tích hợp cổng thanh toán VietQR tự động hóa 100% qua **SePay Webhook (sepay.vn)**. Loại bỏ triệt để mọi cơ chế giả lập/demo cũ, đảm bảo tính toàn vẹn tài chính ACID, bảo mật API Key, gạch nợ hóa đơn tự động trong 2-3 giây và đồng bộ tức thì xuống ứng dụng cư dân qua Supabase Realtime CDC.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, Supabase Enterprise (PostgreSQL 15+, Realtime CDC), SePay Webhook API, VietQR Engine.

## Global Constraints
- 100% tiếng Việt chuẩn mực trong toàn bộ giao diện, nhãn nút và thông báo lỗi.
- Không sử dụng Emoji trên UI; chỉ sử dụng `Icons.*` thuộc Material Icons chuẩn.
- Commit trực tiếp trên nhánh `main`, không tạo branch phụ hay git worktree.
- Tuân thủ TDD: Viết test trước, chạy test thấy fail, code giải pháp, chạy test pass 100%.
- Định dạng mã căn hộ chuẩn: `A0110` / `a0110`.

---

### Task 1: Migration CSDL: Bảng Cấu Hình SePay Tòa Nhà & RPC `process_sepay_webhook`

**Files:**
- Create: `supabase/migrations/20261108_01_sepay_real_payment_and_webhook.sql`
- Test: `test/database/sepay_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `building_payment_configs` (id, building_id, sepay_api_key, bank_name, bank_account_number, bank_account_name, bank_bin, is_active).
  - RPC `process_sepay_webhook(p_payload JSONB, p_api_key TEXT)`: Thẩm định API Key, bóc tách `transferType = 'in'`, trích xuất `payment_code`, gạch nợ hóa đơn, sinh mã biên lai `REC-*` và ghi nhận giao dịch `payment_transactions`.

- [ ] **Step 1: Viết test kiểm tra migration SQL**
  Tạo `test/database/sepay_migration_test.dart` kiểm tra cú pháp SQL, bảng `building_payment_configs`, RPC `process_sepay_webhook` và các ràng buộc bảo mật.
- [ ] **Step 2: Chạy test để xác nhận test thất bại**
  `flutter test test/database/sepay_migration_test.dart` (Fails vì chưa có file SQL).
- [ ] **Step 3: Viết file migration SQL**
  Tạo `supabase/migrations/20261108_01_sepay_real_payment_and_webhook.sql`.
- [ ] **Step 4: Chạy test để xác nhận test pass**
  `flutter test test/database/sepay_migration_test.dart` (Pass).
- [ ] **Step 5: Commit lên nhánh main**
  `git add supabase/migrations/20261108_01_sepay_real_payment_and_webhook.sql test/database/sepay_migration_test.dart`
  `git commit -m "feat(db): migration bang cau hinh SePay va RPC process_sepay_webhook"`

---

### Task 2: Data Models & Strongly-Typed DTOs Cho SePay Webhook

**Files:**
- Create: `lib/data/models/sepay_webhook_payload_model.dart`
- Create: `lib/data/models/building_payment_config_model.dart`
- Test: `test/data/models/sepay_models_test.dart`

**Interfaces:**
- Produces:
  - `SepayWebhookPayloadModel`: parse chính xác các trường `id`, `gateway`, `transactionDate`, `accountNumber`, `content`, `transferType`, `transferAmount`, `referenceCode`, `description`. Helper `isIncomingTransfer`, `extractedPaymentCode`.
  - `BuildingPaymentConfigModel`: cấu hình ngân hàng & API Key SePay của tòa nhà.

- [ ] **Step 1: Viết test unit cho models**
  Tạo `test/data/models/sepay_models_test.dart` kiểm tra parse JSON, validation `isIncomingTransfer`, trích xuất `paymentCode` từ nội dung chuyển khoản.
- [ ] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/data/models/sepay_models_test.dart`
- [ ] **Step 3: Cài đặt các class Model**
  Viết `sepay_webhook_payload_model.dart` và `building_payment_config_model.dart`.
- [ ] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/data/models/sepay_models_test.dart`
- [ ] **Step 5: Commit lên main**
  `git commit -m "feat(models): data models SePay webhook payload va building payment config"`

---

### Task 3: PaymentService & PaymentRepository Nâng Cấp SePay

**Files:**
- Modify: `lib/data/services/payment_service.dart`
- Modify: `lib/data/providers/payment_provider.dart`
- Test: `test/data/services/payment_service_sepay_test.dart`

**Interfaces:**
- Produces:
  - `PaymentService.processSepayWebhook(SepayWebhookPayloadModel payload, {String? apiKey})`
  - `PaymentService.fetchBuildingPaymentConfig(String buildingId)`
  - Mock fallback engine cho SePay webhook trong môi trường test/offline.

- [ ] **Step 1: Viết test cho PaymentService SePay**
  Tạo `test/data/services/payment_service_sepay_test.dart`.
- [ ] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/data/services/payment_service_sepay_test.dart`
- [ ] **Step 3: Cập nhật PaymentService**
  Thêm phương thức xử lý SePay Webhook chuẩn hóa.
- [ ] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/data/services/payment_service_sepay_test.dart`
- [ ] **Step 5: Commit lên main**
  `git commit -m "feat(service): tich hop xu ly SePay webhook trong PaymentService"`

---

### Task 4: Nâng Cấp `UnifiedPaymentSheet` Thanh Toán Thật 100%

**Files:**
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Test: `test/core/widgets/unified_payment_sheet_real_payment_test.dart`

**Interfaces:**
- Produces:
  - Xóa bỏ nút giả lập thanh toán cũ.
  - Hiển thị VietQR SePay động kèm logo Napas 247 và thông tin ngân hàng BQL.
  - Nút "Mở ứng dụng Ngân hàng" (Deep-link banking) & "Sao chép STK/Nội dung/Số tiền".
  - Thanh trạng thái Realtime "Đang chờ biến động số dư ngân hàng..." tự động chuyển bước sang "Thanh toán thành công" khi nhận CDC event gạch nợ.

- [ ] **Step 1: Viết test widget cho UnifiedPaymentSheet**
  Tạo `test/core/widgets/unified_payment_sheet_real_payment_test.dart` kiểm tra hiển thị QR, các nút thao tác và phản hồi tự động khi hóa đơn chuyển trạng thái `paid`.
- [ ] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/core/widgets/unified_payment_sheet_real_payment_test.dart`
- [ ] **Step 3: Cập nhật UnifiedPaymentSheet**
  Loại bỏ logic giả lập, tích hợp reactive Realtime CDC.
- [ ] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/core/widgets/unified_payment_sheet_real_payment_test.dart`
- [ ] **Step 5: Commit lên main**
  `git commit -m "feat(ui): nang cap UnifiedPaymentSheet thanh toan VietQR SePay that 100%"`

---

### Task 5: Dọn Dẹp Mã Nguồn Cũ & Xóa Bỏ Hoàn Toàn Vết Tích Demo

**Files:**
- Modify: `lib/data/providers/resident_invoice_provider.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`

**Interfaces:**
- Produces:
  - Xóa bỏ `ResidentInvoiceService.simulatePayment`.
  - Thay thế các đoạn code hiển thị `paymentMethod == 'DEMO'` sang `paymentMethod == 'VIETQR'` hoặc `Chuyển khoản SePay VietQR`.

- [ ] **Step 1: Rà soát và loại bỏ các đoạn code demo**
- [ ] **Step 2: Chạy test suite liên quan**
  `flutter test test/features/resident/`
- [ ] **Step 3: Commit lên main**
  `git commit -m "chore: loai bo triet de ma nguon demo va simulatePayment"`

---

### Task 6: Bàn Kế Toán Quản Trị SePay & Xử Lý Giao Dịch Chưa Khớp (Unmatched Handlers)

**Files:**
- Modify: `lib/features/management/screens/accounting_web_workstation_screen.dart`
- Test: `test/features/management/accounting_sepay_workstation_test.dart`

**Interfaces:**
- Produces:
  - Bổ sung tab/bộ lọc giao dịch SePay: Tự động phân loại giao dịch đã gạch nợ (`SUCCESS`) và giao dịch chuyển khoản sai cú pháp (`UNMATCHED`).
  - Hỗ trợ Kế toán chọn hóa đơn và bấm nút "Khớp nợ thủ công" cho các giao dịch cư dân gõ nhầm nội dung.

- [ ] **Step 1: Viết test widget cho Accounting Workstation SePay**
- [ ] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/features/management/accounting_sepay_workstation_test.dart`
- [ ] **Step 3: Cập nhật AccountingWebWorkstationScreen**
- [ ] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/features/management/accounting_sepay_workstation_test.dart`
- [ ] **Step 5: Commit lên main**
  `git commit -m "feat(accounting): xu ly giao dich SePay doi soat va unmatched tai ban ke toan"`

---

### Task 7: Toàn Diện Kiểm Thử & Đảm Bảo Chất Lượng (Quality Gate)

**Files:**
- Run test: Toàn bộ test suite SePay & Payment
- Analyze: `dart analyze lib test`
- Graphify: `graphify update .`

- [ ] **Step 1: Chạy toàn bộ test suite thanh toán**
- [ ] **Step 2: Kiểm tra Static Analysis đạt 0 issues**
  `dart analyze lib test`
- [ ] **Step 3: Cập nhật Knowledge Graph**
  `graphify update .`
- [ ] **Step 4: Commit hoàn tất lên main**
  `git commit -m "feat: hoan tat tich hop cong thanh toan that VietQR SePay tu dong hoa 100%"`
