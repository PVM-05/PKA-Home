# Kế Hoạch Triển Khai: Khắc Phục Lỗi P0 VNPay & Chuẩn Hóa Design System, A11y (Phương Án A Cuốn Chiếu)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗi P0 VNPay bằng Edge Function ký số server-authoritative, dọn dẹp khóa bí mật ở client; đồng thời xây dựng bộ Design System Toolkit (Typography, Dark Mode Adaptive Colors, A11y Spoken Currency) và cuốn chiếu chuẩn hóa 7 màn hình của 2 module Tài chính & Sự cố kèm chốt chặn CI test.

**Architecture:** Kiến trúc Clean Architecture / Feature-First. Logic ký số VNPay 2.1.0 và kiểm tra toàn vẹn tài chính được dời về Supabase Edge Function (`create-vnpay-url`, `vnpay-ipn`) dùng `service_role`. Tầng giao diện Flutter sử dụng extension `BuildContext.textTheme`, `AppStatusColors` với getters dark mode, `AppSkeletonShimmer`, `AppEmptyState`, và `Semantics` đọc số tiền chuẩn tiếng Việt qua `VietnameseCurrencyWords`.

**Tech Stack:** Flutter 3.29 / Dart 3.7, Supabase Edge Functions (Deno / TypeScript), PostgreSQL (RLS / Secrets), Riverpod 2.6, Flutter Test.

## Global Constraints
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main`, không tạo branch/worktree phụ.
- Đảm bảo 100% tiếng Việt chuẩn B2B SaaS Commercial PropTech Platform.
- Tuyệt đối không để lộ hoặc hardcode secret key ở tầng client.
- Mã giao dịch VNPay `vnp_TxnRef` bắt buộc bằng `invoices.payment_code`.
- `dart analyze lib test` phải đạt 0 error, 0 warning trước khi kết thúc mỗi task.
- Zero regression: 100% test suites hiện có phải tiếp tục passed.

---

### Task 1: Khắc Phục Lỗi P0 VNPay (Edge Functions Server-Side & Client Cleanup)

**Files:**
- Create: `supabase/functions/create-vnpay-url/index.ts`
- Modify: `supabase/functions/vnpay-ipn/index.ts`
- Modify: `lib/data/models/building_payment_config_model.dart`
- Modify: `lib/core/services/vnpay_service.dart`
- Modify: `lib/data/services/payment_service.dart`
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Test: `test/core/services/vnpay_server_flow_test.dart`

**Interfaces:**
- Consumes: Bảng `invoices` (`total_amount`, `payment_code`, `status`, `apartment_id`), `apartments` (`building_id`), `building_payment_configs` (`vnpay_tmn_code`, `vnpay_is_active`), `building_payment_secrets` (`vnpay_hash_secret`).
- Produces: Edge Function `create-vnpay-url` trả về `{ payment_url: string, txn_ref: string }`; `PaymentService.createVnpayPaymentUrl(invoiceId)` trả về `Future<String?>`.

- [x] **Step 1: Viết test failing cho quy trình gọi VNPay server-side**
Tạo file `test/core/services/vnpay_server_flow_test.dart` kiểm tra `PaymentService.createVnpayPaymentUrl` gọi Supabase Functions với `invoice_id` và nhận URL hợp lệ.

- [x] **Step 2: Chạy test để xác nhận fail**
Chạy `flutter test test/core/services/vnpay_server_flow_test.dart` để xác nhận test thất bại do chưa cập nhật `PaymentService`.

- [x] **Step 3: Tạo Edge Function `supabase/functions/create-vnpay-url/index.ts`**
Viết mã TypeScript cho Deno Edge Function:
1. Thẩm định JWT lấy `user_id`.
2. Kiểm tra RBAC (role `admin`, `management` từ bảng `users` HOẶC cư dân liên kết với `invoices.apartment_id` qua bảng `residents_apartments`).
3. Truy vấn `invoices` lấy `total_amount`, `payment_code`, `status`, `apartment_id`. Kiểm tra nếu `status == 'paid'` ném lỗi 400.
4. Truy vấn 2 bước lấy `vnpay_tmn_code` từ `building_payment_configs` và `vnpay_hash_secret` từ `building_payment_secrets` (kèm fallback env `VNPAY_HASH_SECRET`).
5. Gán `vnp_TxnRef = invoices.payment_code`, `vnp_OrderType = 'billpayment'`, `vnp_Amount = total_amount * 100`.
6. Lấy `vnp_IpAddr` từ `x-forwarded-for`, `vnp_ReturnUrl` từ env `VNPAY_RETURN_URL`.
7. Sắp xếp tham số, tính HMAC-SHA512 và tạo payment URL trả về JSON `{ payment_url, txn_ref }`.

- [x] **Step 4: Cập nhật Edge Function `supabase/functions/vnpay-ipn/index.ts`**
Sửa truy vấn lấy secret thành 2 bước nối tiếp:
1. Query `building_payment_configs` theo `vnp_TmnCode` lấy `building_id`.
2. Query `building_payment_secrets` theo `building_id` lấy `vnpay_hash_secret` (kèm fallback `Deno.env.get("VNPAY_HASH_SECRET")`).

- [x] **Step 5: Dọn dẹp Model & Client Service**
1. Trong `BuildingPaymentConfigModel`: Xóa bỏ 2 trường chết `vnpayHashSecret` và `sepayApiKey`.
2. Trong `VnpayService`: Xóa bỏ logic ký số HMAC-SHA512 phía client (chuyển sang dead code cleanup).
3. Trong `PaymentService`: Viết lại `createVnpayPaymentUrl({required String invoiceId})` gọi `supabase.functions.invoke('create-vnpay-url', body: {'invoice_id': invoiceId})`.
4. Trong `UnifiedPaymentSheet`: Cập nhật gọi `paymentService.createVnpayPaymentUrl(invoiceId: widget.invoice.id)` không cần truyền `vnpayHashSecret`.

- [x] **Step 6: Chạy lại test xác nhận pass**
Chạy `flutter test test/core/services/vnpay_server_flow_test.dart` $\rightarrow$ Pass 100%.

- [x] **Step 7: Commit Task 1**
Commit với message: `fix(vnpay): chuyen logic tao link va ky so vnpay ve server edge function`

---

### Task 2: Xây Dựng Design System Toolkit & Chốt Chặn CI (Guardrail)

**Files:**
- Create: `lib/core/theme/app_typography.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Create: `test/core/theme_and_color_guard_test.dart`

**Interfaces:**
- Consumes: `Theme.of(context).textTheme`, `Theme.of(context).brightness`.
- Produces: `context.textTheme` extension, `AppStatusColors.get*()` adaptive getters, CI test quét chống mã màu và font size cứng trên các module đã chuẩn hóa.

- [x] **Step 1: Viết test failing cho CI Guardrail**
Tạo file `test/core/theme_and_color_guard_test.dart` quét danh sách file whitelist. Kiểm tra assertion ném lỗi nếu có file trong whitelist vi phạm `Color(0x` hoặc `fontSize:`.

- [x] **Step 2: Chạy test để xác nhận hoạt động**
Chạy `flutter test test/core/theme_and_color_guard_test.dart`.

- [x] **Step 3: Tạo `lib/core/theme/app_typography.dart`**
Định nghĩa extension `AppTypographyExtension` trên `BuildContext`:
- `textTheme`, `displayLarge`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelSmall`.

- [x] **Step 4: Bổ sung Dark Mode Adaptive Getters vào `AppStatusColors` trong `app_theme.dart`**
Giữ nguyên toàn bộ mã màu Light hiện tại:
- `paid (0xFF4CAF50)`, `unpaid (0xFFF44336)`, `pendingConfirmation (0xFFFFB300)`, `priorityHigh (0xFFD32F2F)`, `priorityMedium (0xFFFF9800)`, `priorityLow (0xFF64B5F6)`.
Thêm các hàm getter thích ứng Dark Mode:
- `getPaid(context)`, `getUnpaid(context)`, `getPendingConfirmation(context)`, `getPriorityHigh(context)`, `getPriorityMedium(context)`, `getPriorityLow(context)`.

- [x] **Step 5: Kiểm tra static analyze**
Chạy `dart analyze lib test` xác nhận 0 lỗi.

- [x] **Step 6: Commit Task 2**
Commit với message: `feat(design-system): bo sung typography extension dark mode colors va ci guard test`

---

### Task 3: Cuốn Chiếu Module 1 - Tài Chính & Hóa Đơn (4 Màn Hình)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Create: `test/features/resident/resident_invoice_a11y_and_shimmer_test.dart`
- Create: `test/features/management/invoice_management_a11y_and_shimmer_test.dart`

**Interfaces:**
- Consumes: `AppTypographyExtension`, `AppStatusColors`, `AppSkeletonShimmer`, `AppEmptyState`, `VietnameseCurrencyWords`.
- Produces: 4 màn hình hóa đơn đạt chuẩn Design Tokens, phủ Shimmer Loading, Empty State và nhãn giọng đọc Semantics tiếng Việt.

- [ ] **Step 1: Viết test failing cho Resident Invoice A11y & Shimmer**
Tạo file `test/features/resident/resident_invoice_a11y_and_shimmer_test.dart` kiểm tra Shimmer khi loading, Empty State khi không có hóa đơn, và nhãn Semantics giọng đọc tiếng Việt cho số tiền hóa đơn (`VietnameseCurrencyWords.toVietnameseWords`).

- [ ] **Step 2: Viết test failing cho Invoice Management A11y & Shimmer**
Tạo file `test/features/management/invoice_management_a11y_and_shimmer_test.dart` kiểm tra giao diện quản lý hóa đơn BQL.

- [ ] **Step 3: Chạy test xác nhận failing**
Chạy 2 test vừa tạo để xác nhận fail do màn hình chưa có đủ Semantics/Shimmer.

- [ ] **Step 4: Chuẩn hóa 2 màn hình Resident Invoice**
1. `resident_invoice_screen.dart`:
   - Thay thế toàn bộ mã màu cứng và `fontSize:` bằng `context.textTheme` và `AppStatusColors.get*()`.
   - Bọc `Semantics` cho thẻ hóa đơn với `semanticLabel` đọc số tiền tự nhiên: `"${invoice.paymentCode}, số tiền ${VietnameseCurrencyWords.toVietnameseWords(invoice.totalAmount)}, trạng thái ${invoice.statusVietnamese}"`.
   - Bọc `Semantics(button: true)` cho các nút thanh toán VietQR, VNPay.
2. `resident_invoice_detail_screen.dart`:
   - Thay thế `CircularProgressIndicator` bằng `AppSkeletonShimmer.cardList()`.
   - Dọn dẹp mã màu cứng và `fontSize:`.
   - Bổ sung `Semantics` cho bảng kê chi tiết dịch vụ và số tiền tổng.

- [ ] **Step 5: Chuẩn hóa 2 màn hình Management Invoice**
1. `invoice_management_screen.dart`:
   - Thay thế `CircularProgressIndicator` bằng `AppSkeletonShimmer.cardList()`.
   - Thêm `AppEmptyState` khi danh sách lọc rỗng.
   - Dọn sạch mã màu cứng và `fontSize:`.
   - Bọc `Semantics` cho các thẻ trạng thái và nút duyệt/gạch nợ.
2. `management_invoice_detail_screen.dart`:
   - Thay `CircularProgressIndicator` bằng Shimmer.
   - Chuẩn hóa typography và adaptive colors.

- [ ] **Step 6: Cập nhật whitelist trong CI Guardrail Test**
Thêm 4 màn hình Hóa đơn vào `targetModulesWhitelist` của `test/core/theme_and_color_guard_test.dart`.

- [ ] **Step 7: Chạy toàn bộ test xác nhận pass**
Chạy `flutter test test/features/resident/resident_invoice_a11y_and_shimmer_test.dart test/features/management/invoice_management_a11y_and_shimmer_test.dart test/core/theme_and_color_guard_test.dart` $\rightarrow$ Passed!

- [ ] **Step 8: Commit Task 3**
Commit với message: `refactor(finance-ui): chuan hoa design tokens shimmer empty state va semantics cho module hoa don`

---

### Task 4: Cuốn Chiếu Module 2 - Sự Cố & Vận Hành (3 Màn Hình)

**Files:**
- Modify: `lib/features/resident/screens/resident_issue_screen.dart`
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Modify: `lib/features/management/screens/issue_management_screen.dart`
- Create: `test/features/management/issue_management_a11y_and_shimmer_test.dart`

**Interfaces:**
- Consumes: `AppTypographyExtension`, `AppStatusColors`, `AppSkeletonShimmer`, `AppEmptyState`.
- Produces: 3 màn hình sự cố loại bỏ 100% `CircularProgressIndicator`, bọc Shimmer, Empty State và nhãn Semantics phân công/mức ưu tiên.

- [ ] **Step 1: Viết test failing cho Issue Management A11y & Shimmer**
Tạo file `test/features/management/issue_management_a11y_and_shimmer_test.dart` kiểm tra `AppSkeletonShimmer` khi loading, `AppEmptyState` khi rỗng và nhãn Semantics cho độ ưu tiên và nút điều phối.

- [ ] **Step 2: Chạy test xác nhận failing**
Chạy test để xác nhận fail do `issue_management_screen.dart` đang dùng `CircularProgressIndicator`.

- [ ] **Step 3: Chuẩn hóa 2 màn hình Resident Issue**
1. `resident_issue_screen.dart`:
   - Dọn sạch các mã màu cứng và `fontSize:` còn sót lại.
   - Bọc `Semantics` cho thẻ sự cố với tiêu đề, mức độ ưu tiên và trạng thái.
2. `issue_detail_screen.dart`:
   - Thay thế `CircularProgressIndicator` bằng `AppSkeletonShimmer.cardList()`.
   - Dọn dẹp mã màu cứng và font size cứng.
   - Bọc `Semantics(image: true)` cho danh sách ảnh hiện trường sự cố và các mốc thời gian xử lý SLA.

- [ ] **Step 4: Chuẩn hóa `issue_management_screen.dart` (BQL)**
- Xóa bỏ triệt để `CircularProgressIndicator`, thay bằng `AppSkeletonShimmer.cardList()`.
- Thêm `AppEmptyState` chuẩn mực cho các tab sự cố (Chờ xử lý, Đang xử lý, Đã hoàn thành).
- Dọn dẹp mã màu cứng và `fontSize:` bằng `context.textTheme` và `AppStatusColors.getPriority*()`.
- Bọc `Semantics` cho nút phân công kỹ thuật viên và badge SLA.

- [ ] **Step 5: Cập nhật whitelist trong CI Guardrail Test**
Thêm 3 màn hình Sự cố vào `targetModulesWhitelist` của `test/core/theme_and_color_guard_test.dart` (tổng cộng đủ 7 màn hình).

- [ ] **Step 6: Chạy test xác nhận pass**
Chạy `flutter test test/features/management/issue_management_a11y_and_shimmer_test.dart test/core/theme_and_color_guard_test.dart` $\rightarrow$ Passed!

- [ ] **Step 7: Commit Task 4**
Commit với message: `refactor(issue-ui): chuan hoa design tokens shimmer empty state va semantics cho module su co`

---

### Task 5: Kiểm Thử Toàn Diện, Chạy Static Analyze & Checklist Nghiệm Thu

**Files:**
- Test: Toàn bộ test suite liên quan (`test/core/...`, `test/features/resident/...`, `test/features/management/...`)
- Documentation: `docs/superpowers/plans/2026-11-17-vnpay-p0-and-ui-a11y-plan.md`

- [ ] **Step 1: Chạy toàn bộ static analyze**
Chạy `dart analyze lib test` đảm bảo:
`No issues found!` (0 error, 0 warning).

- [ ] **Step 2: Chạy toàn bộ test suites của 2 module và core**
Chạy Flutter test trọn gói:
`flutter test test/core/services/vnpay_server_flow_test.dart test/core/theme_and_color_guard_test.dart test/features/resident/resident_invoice_a11y_and_shimmer_test.dart test/features/management/invoice_management_a11y_and_shimmer_test.dart test/features/management/issue_management_a11y_and_shimmer_test.dart`
Xác nhận 100% Passed.

- [ ] **Step 3: Chạy graphify update**
Cập nhật đồ thị tri thức mã nguồn: `graphify update .`

- [ ] **Step 4: Hoàn thiện Checklist Nghiệm thu QA Thủ công & Deploy**
Tạo tài liệu hướng dẫn nghiệm thu deploy 2 Edge Functions và test sandbox VNPay.

- [ ] **Step 5: Push lên nhánh `main`**
Đẩy toàn bộ thay đổi an toàn lên `origin/main`.

