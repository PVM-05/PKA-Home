# Phân Hệ Tài Chính, Hóa Đơn & Thu Phí VietQR Impeccable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tái thiết và nâng cấp toàn diện giao diện & trải nghiệm người dùng của Phân hệ Tài Chính, Hóa Đơn & Thu Phí VietQR (`InvoiceManagementScreen`, `CreateInvoiceScreen`, `EditInvoiceScreen`, `ManagementInvoiceDetailScreen`, `ResidentInvoiceScreen`, `ResidentInvoiceDetailScreen`, `PaymentHistoryScreen`, `FinancialReportScreen`, `MaintenanceFundLedgerScreen`) theo triết lý thiết kế **`pbakaus/impeccable`**, đồng bộ với `PRODUCT.md` và `DESIGN.md`.

**Architecture:** Áp dụng Feature-First Flutter, sử dụng `AppCard` viền mỏng mờ, `AppTheme`, bọc `LayoutBuilder` cho các widget co giãn linh hoạt, xây dựng Executive Dashboard Workstation cho Ban Quản Lý trên Web Desktop ($\ge 900$dp, `maxWidth: 1400`), thiết kế Split-Screen 2 cột cho lập hóa đơn và thanh toán VietQR. Quản lý trạng thái qua Riverpod.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.6, Printing / PDF, VietQR / PaymentService, AppTheme / AppCard, Flutter Test.

## Global Constraints

- **Toàn bộ commit trực tiếp vào nhánh `main`**: Tuyệt đối không tạo nhánh phụ hay worktree ngoài `main`.
- **Anti-RenderFlex Guarantee 100%**: 0 lỗi `RenderFlex overflowed` trên mọi kích thước từ 320dp x 600dp (kèm text scale 1.3x) đến 1920dp x 1080dp.
- **Tiêu chuẩn B2B SaaS**: 100% tiếng Việt chuẩn mực, không emoji, không hardcode mã màu, sử dụng token trong `DESIGN.md`.
- **Chất lượng mã nguồn**: 0 lỗi / 0 cảnh báo khi chạy `dart analyze lib test`.

---

### Task 1: Nâng cấp `FinancialReportScreen` & `MaintenanceFundLedgerScreen` (BQL)

**Files:**
- Modify: `lib/features/management/screens/financial_report_screen.dart`
- Modify: `lib/features/management/screens/maintenance_fund_ledger_screen.dart`
- Create: `test/features/management/finance_reports_responsive_test.dart`

**Interfaces:**
- Consumes: `financialAgingReportProvider`, `financialReportFilterProvider`, `activeMaintenanceFundProvider`, `maintenanceFundLedgerProvider`, `AppTheme`, `AppCard`.
- Produces:
  - `FinancialReportScreen`: Bọc `Center(ConstrainedBox(maxWidth: 1400))`, KPI chuyển 4 cột trên Desktop và lưới 2 cột co giãn an toàn trên Mobile 320dp (Text Zoom 1.3x).
  - `MaintenanceFundLedgerScreen`: Bố cục Split-Screen 2 cột trên Desktop $\ge 900$dp, bộ lọc FilterChip cuộn ngang an toàn trên Mobile.

- [ ] **Step 1: Viết test kiểm tra Responsive cho `FinancialReportScreen` và `MaintenanceFundLedgerScreen`**
  Tạo `test/features/management/finance_reports_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Executive KPI Bar và Workstation cân đối.
- [ ] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/management/finance_reports_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `FinancialReportScreen` với kiến trúc Responsive Impeccable**
  - Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 1400))`.
  - Nâng cấp dải KPI 4 chỉ số: 4 cột trên Desktop, 2 cột co giãn linh hoạt trên Mobile.
- [ ] **Step 4: Cập nhật `MaintenanceFundLedgerScreen` với kiến trúc Responsive Impeccable**
  - Hỗ trợ Split-Screen 2 cột trên Desktop $\ge 900$dp (`maxWidth: 1400`).
  - Bọc bộ lọc FilterChip trong `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
- [ ] **Step 5: Chạy kiểm thử xác minh và static analysis**
  Chạy `flutter test test/features/management/finance_reports_responsive_test.dart`.
- [ ] **Step 6: Commit Task 1 vào `main`**
  `git commit -m "feat(management): nang cap bao cao tai chinh va so quy bao tri responsive impeccable"`

---

### Task 2: Nâng cấp `CreateInvoiceScreen` & `EditInvoiceScreen` (Biểu Mẫu Lập Hóa Đơn)

**Files:**
- Modify: `lib/features/management/screens/create_invoice_screen.dart`
- Modify: `lib/features/management/screens/edit_invoice_screen.dart`
- Create: `test/features/management/invoice_forms_responsive_test.dart`

**Interfaces:**
- Consumes: `managementProvider`, `feeScheduleProvider`, `AppTheme`, `AppCard`.
- Produces:
  - Bố cục Split-Screen 2 cột trên Web Desktop $\ge 900$dp (`maxWidth: 1400`).
  - Mobile (< 900dp): Trường nhập đơn giá, số lượng và tổng tiền co giãn an toàn qua `LayoutBuilder`.

- [ ] **Step 1: Viết test kiểm tra Responsive cho `CreateInvoiceScreen` và `EditInvoiceScreen`**
  Tạo `test/features/management/invoice_forms_responsive_test.dart`.
- [ ] **Step 2: Chạy test để xác nhận trạng thái**
  Chạy `flutter test test/features/management/invoice_forms_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `CreateInvoiceScreen` với kiến trúc Responsive Impeccable**
  - Tách bố cục Desktop Split-Screen (Cột trái: Thông tin căn hộ & kỳ thu; Cột phải: Các khoản mục phí).
  - Chống tràn bằng `LayoutBuilder` cho các cặp trường nhập đơn giá & số lượng.
- [ ] **Step 4: Cập nhật `EditInvoiceScreen` với kiến trúc Responsive Impeccable**
  - Căn giữa `maxWidth: 1400` trên Desktop, bọc `Expanded` và `FittedBox` cho các dòng chi phí.
- [ ] **Step 5: Chạy kiểm thử xác minh**
  Chạy `flutter test test/features/management/invoice_forms_responsive_test.dart`.
- [ ] **Step 6: Commit Task 2 vào `main`**
  `git commit -m "feat(management): nang cap bieu mau lap va sua hoa don responsive split-screen"`

---

### Task 3: Nâng cấp `ResidentInvoiceScreen` & `ResidentInvoiceDetailScreen` (Cư Dân)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`

**Interfaces:**
- Consumes: `residentInvoiceProvider`, `PaymentService`, `AppTheme`, `AppCard`.
- Produces:
  - `ResidentInvoiceScreen`: Thẻ hóa đơn viền mỏng mờ, huy hiệu quá hạn rõ ràng, chống tràn 100% trên 320dp.
  - `ResidentInvoiceDetailScreen`: Split-Screen trên Web Desktop $\ge 900$dp (Cột trái: Tổng tiền & QR VietQR; Cột phải: Chi tiết các khoản phí).

- [ ] **Step 1: Chạy test resident invoice hiện tại**
  Chạy `flutter test test/features/resident/*invoice*`.
- [ ] **Step 2: Cập nhật `ResidentInvoiceScreen` với tiêu chuẩn Impeccable**
  - Chuẩn hóa màu sắc thẻ theo `AppTheme` và `DESIGN.md`.
  - Bọc nhãn hạn thanh toán và huy hiệu trạng thái trong `FittedBox` + `ConstrainedBox`.
- [ ] **Step 3: Cập nhật `ResidentInvoiceDetailScreen` với bố cục Split-Screen Desktop**
  - Thêm hỗ trợ màn hình lớn $\ge 900$dp (`maxWidth: 1200`).
  - Tối ưu hiển thị bảng tính lũy tiến và mã QR chuyển khoản VietQR.
- [ ] **Step 4: Chạy kiểm thử toàn bộ test của resident invoice**
  Chạy `flutter test test/features/resident/*invoice*` đảm bảo pass 100%.
- [ ] **Step 5: Commit Task 3 vào `main`**
  `git commit -m "feat(resident): nang cap giao dien hoa don va chi tiet thanh toan vietqr responsive"`

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống

**Files:**
- Verify: Toàn bộ codebase phân hệ Tài chính
- Update: Knowledge Graph qua `graphify update .`

- [ ] **Step 1: Chạy toàn bộ test suite của phân hệ Tài chính & Hóa đơn**
  Chạy `flutter test test/features/management/*invoice* test/features/resident/*invoice* test/features/management/*finance*`.
- [ ] **Step 2: Chạy static analysis toàn dự án**
  Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- [ ] **Step 3: Quét kiểm tra chất lượng giao diện bằng Impeccable engine**
  Chạy `.agents/skills/impeccable/scripts/impeccable.cmd detect lib/`.
- [ ] **Step 4: Cập nhật Knowledge Graph**
  Chạy `graphify update .`.
- [ ] **Step 5: Commit tài liệu hoàn thành vào `main`**
  `git commit -m "docs: hoan thanh cai tien toan dien giao dien phan he tai chinh va hoa don vietqr"`
