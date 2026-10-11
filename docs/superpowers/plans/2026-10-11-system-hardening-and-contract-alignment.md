# Kế Hoạch Triển Khai: Đồng Bộ Giao Diện Thanh Toán, Chuẩn Hóa Số Liệu Tài Chính & Khắc Phục Lệch Hợp Đồng RPC

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để 5 vấn đề về RPC CSDL, độ tin cậy repository, tính toán thống kê tài chính và phản hồi giao diện thanh toán.

**Architecture:** Bổ sung Migration 20261011_03 tái tạo RPC `update_invoice_with_items` và chuẩn hóa `book_amenity_slot`. Cập nhật tầng Repository không nuốt lỗi và không fallback không nguyên tử. Cập nhật `dashboard_providers.dart` phân rã trạng thái hóa đơn. Cập nhật UI thanh toán và booking không báo thành công khi thanh toán bị lỗi.

**Tech Stack:** Flutter / Dart, Supabase PostgreSQL 15, Riverpod.

## Global Constraints
- Commit trực tiếp vào nhánh `main`, không tạo branch hay worktree phụ.
- Đảm bảo `flutter analyze` 0 lỗi và toàn bộ kiểm thử `flutter test` vượt qua.
- Văn bản và tài liệu sử dụng 100% tiếng Việt chuẩn mực.

---

### Task 1: Migration 20261011_03 & Unit Test Kiểm Tra Chữ Ký RPC

**Files:**
- Create: `supabase/migrations/20261011_03_harmonize_amenity_and_invoice_rpcs.sql`
- Create: `test/data/migrations/rpc_contract_alignment_test.dart`

**Interfaces:**
- Produces: RPC `public.update_invoice_with_items`, RPC `public.book_amenity_slot`.

- [ ] **Step 1: Viết failing test cho Migration mới**
  Kiểm tra file `20261011_03_harmonize_amenity_and_invoice_rpcs.sql` tồn tại và định nghĩa đầy đủ 2 RPC với các tham số tương thích client.
- [ ] **Step 2: Chạy test để xác nhận test thất bại**
  `flutter test test/data/migrations/rpc_contract_alignment_test.dart`
- [ ] **Step 3: Viết migration SQL**
  Tạo `supabase/migrations/20261011_03_harmonize_amenity_and_invoice_rpcs.sql`.
- [ ] **Step 4: Chạy test để xác nhận test thành công**
  `flutter test test/data/migrations/rpc_contract_alignment_test.dart`
- [ ] **Step 5: Commit task 1**
  `git commit -m "feat(db): bổ sung migration đồng bộ RPC book_amenity_slot và update_invoice_with_items"`

---

### Task 2: Chuẩn Hóa Repositories (Xử Lý Lỗi & Nguyên Tử Hóa)

**Files:**
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/data/repositories/management_repository.dart`
- Modify/Create: `test/data/repositories/amenity_booking_repository_error_test.dart`

**Interfaces:**
- Consumes: Supabase PostgreSQL tables & RPCs.
- Produces: `AmenityBookingRepository.getBookingsByAmenityAndDate`, `ManagementRepository.updateInvoice`.

- [ ] **Step 1: Viết test cho AmenityBookingRepository**
  Kiểm tra khi client gặp exception thì ném lỗi thay vì trả về `[]`.
- [ ] **Step 2: Sửa `amenity_booking_repository.dart`**
  Loại bỏ `catch (_) { return []; }` ở `getBookingsByAmenityAndDate` và `getMaintenanceWindows`.
- [ ] **Step 3: Sửa `management_repository.dart`**
  Gọi RPC `update_invoice_with_items` và loại bỏ khối fallback xóa chèn thủ công.
- [ ] **Step 4: Chạy test repository**
  `flutter test test/data/repositories/amenity_booking_repository_error_test.dart`
- [ ] **Step 5: Commit task 2**
  `git commit -m "fix(repo): chuẩn hóa xử lý lỗi amenity repository và nguyên tử hóa updateInvoice"`

---

### Task 3: Chuẩn Hóa Thống Kê Tài Chính Trên Dashboard

**Files:**
- Modify: `lib/data/providers/dashboard_providers.dart`
- Create/Modify: `test/data/providers/dashboard_financial_stats_test.dart`

**Interfaces:**
- Produces: `FinancialStats` với các trường `paidTotal`, `unpaidTotal`, `pendingConfirmationTotal`, `cancelledTotal`, `totalBilled`.

- [ ] **Step 1: Viết test kiểm tra tính toán FinancialStats**
  Đưa vào danh sách hóa đơn gồm `paid`, `unpaid`, `pending_confirmation`, `cancelled`, `void`.
  Xác nhận `cancelled` và `void` không bị cộng vào nợ; xác nhận `totalBilled` và `actualRevenue` tính đúng.
- [ ] **Step 2: Cập nhật `dashboard_providers.dart`**
  Cập nhật lớp `FinancialStats` và logic phân loại trong `financialStatsProvider`.
- [ ] **Step 3: Chạy test xác nhận đỗ**
  `flutter test test/data/providers/dashboard_financial_stats_test.dart`
- [ ] **Step 4: Commit task 3**
  `git commit -m "fix(dashboard): chuẩn hóa thống kê tài chính và loại bỏ hóa đơn đã hủy khỏi nợ"`

---

### Task 4: Đồng Bộ Giao Diện Thanh Toán & Đặt Tiện Ích

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Modify: `lib/data/providers/resident_invoice_provider.dart`
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Create/Modify: `test/features/resident/amenity_booking_payment_failure_ui_test.dart`

**Interfaces:**
- Consumes: `showUnifiedPaymentSheet`, `PaymentResult`.
- Produces: UI phản hồi chính xác khi thanh toán thất bại / chưa hỗ trợ.

- [ ] **Step 1: Viết test UI kiểm tra luồng thanh toán thất bại**
  Kiểm tra màn hình không hiển thị "Đặt lịch tiện ích thành công!" màu xanh khi payment không thành công.
- [ ] **Step 2: Cập nhật `amenity_booking_screen.dart`**
  Hiển thị thông báo hướng dẫn cư dân liên hệ BQL khi đơn đặt ở trạng thái chờ thanh toán.
- [ ] **Step 3: Cập nhật `resident_invoice_provider.dart`**
  Sửa `'p_category': 'INVOICE'` sang `'p_type': 'INVOICE'`.
- [ ] **Step 4: Cập nhật `unified_payment_sheet.dart`**
  Nâng cấp thông điệp báo lỗi và hướng dẫn khi gặp `feature_not_supported`.
- [ ] **Step 5: Chạy test UI**
  `flutter test test/features/resident/amenity_booking_payment_failure_ui_test.dart`
- [ ] **Step 6: Commit task 4**
  `git commit -m "fix(ui): đồng bộ phản hồi giao diện khi thanh toán trực tuyến bị từ chối"`

---

### Task 5: Xác Minh Toàn Diện & Push Remote

- [ ] **Step 1: Chạy `flutter analyze`**
- [ ] **Step 2: Chạy `flutter test` toàn bộ suite**
- [ ] **Step 3: Push lên `origin/main`**
