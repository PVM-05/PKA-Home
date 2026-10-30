# Kế Hoạch Triển Khai: Báo Cáo Tài Chính & Phân Tích Tuổi Nợ (C6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống Báo cáo Tài chính toàn diện và Phân tích Tuổi nợ (Debt Aging Analysis) cho Ban Quản Lý, tích hợp biểu đồ trực quan, xuất Excel đối soát 2 trang tính và thao tác nhắc nợ nhanh, hoàn tất trọn vẹn Giai đoạn C trong Commercial Roadmap.

**Architecture:** Sử dụng kiến trúc Hybrid: RPC PostgreSQL `get_financial_aging_report` tính toán và gom nhóm 4 xô nợ (0-30, 31-60, 61-90, >90 ngày) tức thời trên server; tầng Client cung cấp data models strongly-typed, engine tính toán offline fallback trên `AccountingRepository`, bộ công cụ xuất file Excel đối soát đa trang tính (`ExcelExportHelper`), và màn hình quản trị `FinancialReportScreen` tối ưu hiển thị với Riverpod.

**Tech Stack:** Dart, Flutter, `flutter_riverpod: ^2.6.1`, `fl_chart: ^1.2.0`, `excel: ^4.0.6`, `share_plus: ^13.3.1`, Supabase PostgreSQL RPC `SECURITY DEFINER`.

## Global Constraints
- Tuân thủ quy tắc Git: Toàn bộ commit trực tiếp vào nhánh `main`.
- 100% tiếng Việt tự nhiên trên UI, không dùng emoji, dùng Icons từ Flutter Material Icons.
- Không hardcode màu sắc, tuân thủ `AppTheme` / `AppCard`.
- Định dạng mã căn hộ chuẩn `A0110` / `B0205`.
- Duy trì 100% pass toàn bộ 651+ tests tự động.
- `dart analyze` phải đạt 0 issue.

---

### Task 1: Migration SQL Database & RPC `get_financial_aging_report`

**Files:**
- Create: `supabase/migrations/20261030_01_financial_aging_report_rpc.sql`
- Test: `test/integration/financial_aging_report_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `invoices`, `apartments`, `residents_apartments`, `users`, `role_delegations`.
- Produces: RPC `get_financial_aging_report(p_building_id UUID, p_period TEXT)` trả về JSONB tổng hợp tài chính và 4 xô tuổi nợ.

- [x] **Step 1:** Viết failing test `financial_aging_report_migration_test.dart` kiểm tra sự tồn tại của tệp migration, cấu trúc hàm RPC, kiểm tra quyền truy cập RBAC, các CTE tính toán (`filtered_invoices`, `summary_calc`, `aging_calc`, `debtors`, `collection_by_block`) và cấu trúc JSON trả về.
- [x] **Step 2:** Chạy `flutter test test/integration/financial_aging_report_migration_test.dart` để xác nhận test FAIL.
- [x] **Step 3:** Tạo tệp migration `supabase/migrations/20261030_01_financial_aging_report_rpc.sql` với đầy đủ logic phân quyền và tổng hợp tính toán.
- [x] **Step 4:** Chạy lại test `financial_aging_report_migration_test.dart` để xác nhận PASS.
- [x] **Step 5:** Commit task 1 vào `main`.

---

### Task 2: Data Models (Financial Aging Report Models)

**Files:**
- Create: `lib/data/models/financial_aging_report_model.dart`
- Test: `test/data/models/financial_aging_report_model_test.dart`

**Interfaces:**
- Consumes: Cấu trúc JSONB từ RPC `get_financial_aging_report`.
- Produces: `FinancialAgingReportModel`, `FinancialAgingSummaryModel`, `DebtAgingBucketModel`, `DebtorApartmentModel`, `BlockCollectionRateModel`.

- [x] **Step 1:** Viết failing test `financial_aging_report_model_test.dart` kiểm tra `fromJson`, `toJson`, các getters tiện ích (`collectionRateFormatted`, `riskLevelText`, `isSevereRisk`), và xử lý an toàn dữ liệu null/khuyết thiếu.
- [x] **Step 2:** Chạy `flutter test test/data/models/financial_aging_report_model_test.dart` để xác nhận test FAIL.
- [x] **Step 3:** Hiện thực hóa các class model trong `lib/data/models/financial_aging_report_model.dart`.
- [x] **Step 4:** Chạy lại test model để xác nhận PASS.
- [x] **Step 5:** Commit task 2 vào `main`.

---

### Task 3: Accounting Repository & Engine Tính Toán Offline Fallback

**Files:**
- Modify: `lib/data/repositories/accounting_repository.dart`
- Test: `test/data/repositories/accounting_repository_aging_report_test.dart`

**Interfaces:**
- Consumes: Supabase RPC client, bảng `invoices`, `apartments`.
- Produces: `Future<FinancialAgingReportModel> fetchAgingReport({String? buildingId, String? period})`.

- [x] **Step 1:** Viết failing test `accounting_repository_aging_report_test.dart` kiểm tra việc gọi RPC thành công, xử lý mapping model và cơ chế offline fallback tự động tính toán từ danh sách invoices cục bộ khi RPC lỗi.
- [x] **Step 2:** Chạy test để xác nhận FAIL.
- [x] **Step 3:** Thêm phương thức `fetchAgingReport` và thuật toán `calculateAgingReportFallback` vào `AccountingRepository`.
- [x] **Step 4:** Chạy lại test để xác nhận PASS.
- [x] **Step 5:** Commit task 3 vào `main`.

---

### Task 4: Nâng Cấp `ExcelExportHelper` Xuất Báo Cáo Tuổi Nợ 2 Trang Tính

**Files:**
- Modify: `lib/core/utils/excel_export_helper.dart`
- Test: `test/core/utils/excel_export_aging_report_test.dart`

**Interfaces:**
- Consumes: `FinancialAgingReportModel`.
- Produces: `Future<String?> exportAgingReport({required FinancialAgingReportModel report, String? period})`.

- [x] **Step 1:** Viết failing test `excel_export_aging_report_test.dart` kiểm tra sinh file `.xlsx` chứa 2 sheets: `Tổng Quan & Tuổi Nợ` và `Danh Sách Căn Hộ Nợ`, kiểm tra đầy đủ cột header, định dạng số tiền và dữ liệu từng căn.
- [x] **Step 2:** Chạy test để xác nhận FAIL.
- [x] **Step 3:** Triển khai phương thức `exportAgingReport` trong `ExcelExportHelper`.
- [x] **Step 4:** Chạy lại test để xác nhận PASS.
- [x] **Step 5:** Commit task 4 vào `main`.

---

### Task 5: Providers & Màn Hình Quản Trị `FinancialReportScreen`

**Files:**
- Create: `lib/data/providers/financial_report_provider.dart`
- Create: `lib/features/management/screens/financial_report_screen.dart`
- Modify: `lib/core/router/app_router.dart` & `lib/core/router/route_names.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart` (Thêm nút điều hướng tiện lợi)
- Test: `test/features/management/screens/financial_report_screen_test.dart`

**Interfaces:**
- Consumes: `financialAgingReportProvider`, `accountingRepositoryProvider`, `pushNotificationServiceProvider`.
- Produces: Giao diện trực quan phân tích tuổi nợ, bộ lọc kỳ/tòa, nút xuất Excel, hộp thoại nhắc nợ nhanh, điều hướng sang Sổ cái.

- [x] **Step 1:** Viết widget test `financial_report_screen_test.dart` kiểm tra hiển thị KPI, 4 thẻ xô nợ, bộ lọc chip tuổi nợ, danh sách căn hộ nợ, nút bấm nhắc nợ và nút xuất file Excel.
- [x] **Step 2:** Chạy test để xác nhận FAIL.
- [x] **Step 3:** Tạo provider `financial_report_provider.dart` quản lý bộ lọc và fetch dữ liệu.
- [x] **Step 4:** Xây dựng màn hình `FinancialReportScreen` chuẩn Material Design và thiết kế tiếng Việt 100%.
- [x] **Step 5:** Đăng ký route `/management/financial-report` trong `app_router.dart` và tích hợp lối tắt vào `ManagementHomeScreen`.
- [x] **Step 6:** Chạy lại widget test để xác nhận PASS.
- [x] **Step 7:** Commit task 5 vào `main`.

---

### Task 6: Quality Gate, Graphify Update & Cập Nhật Roadmap

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md` (Đánh dấu hoàn tất C6)
- Update: `graphify-out/` qua `python -m graphify update .`

- [x] **Step 1:** Chạy `dart analyze` đảm bảo 0 warning, 0 error.
- [x] **Step 2:** Chạy `flutter test` đảm bảo toàn bộ bộ test (655+ tests) vượt qua 100%.
- [x] **Step 3:** Chạy `python -m graphify update .` để cập nhật Knowledge Graph kiến trúc dự án.
- [x] **Step 4:** Cập nhật mục `C6` thành `[x]` trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.
- [x] **Step 5:** Commit hoàn tất toàn bộ tính năng C6 vào `main`.

