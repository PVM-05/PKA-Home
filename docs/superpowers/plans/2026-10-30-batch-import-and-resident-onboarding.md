# Kế Hoạch Triển Khai: Bộ Công Cụ Onboarding & Nhập Liệu Hàng Loạt Từ Excel (B2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng giải pháp Onboarding thương mại toàn diện cho Ban Quản Lý: Nhập hàng loạt Căn hộ, Cư dân và Chỉ số điện nước từ file Excel (.xlsx) với cơ chế thẩm định từng dòng, hiển thị lỗi chi tiết, tải file mẫu, và quản lý lịch sử liên kết cư dân chuẩn mực (không xóa mất dữ liệu), hoàn thành mục B2 trong Commercial Roadmap.

**Architecture:** Sử dụng kiến trúc kết hợp: Tầng Client đảm nhận việc phân tích cấu trúc Excel, sinh file mẫu (.xlsx) và thẩm định (validation) chi tiết từng dòng bằng `excel: ^4.0.6` và `ExcelImportHelper` với tốc độ phản hồi tức thì; Tầng Backend cung cấp migration nâng cấp vòng đời cư dân (`start_date`, `end_date`, `status`) và các RPC PostgreSQL transactional (`batch_import_apartments`, `batch_import_residents`, `batch_import_meter_readings`) thực thi an toàn theo từng `building_id`; Giao diện cung cấp trung tâm `BatchImportCenterScreen` 3 tab linh hoạt.

**Tech Stack:** Dart, Flutter, `excel: ^4.0.6`, `flutter_riverpod: ^2.6.1`, `share_plus: ^13.3.1`, Supabase PostgreSQL RPC `SECURITY DEFINER`.

## Global Constraints
- Tuân thủ quy tắc Git: Toàn bộ commit trực tiếp vào nhánh `main`.
- 100% tiếng Việt tự nhiên trên UI, không dùng emoji, dùng Icons từ Flutter Material Icons.
- Không hardcode màu sắc, tuân thủ `AppTheme` / `AppCard`.
- Định dạng mã căn hộ chuẩn `A0110` / `B0205` (`<Block><Tầng 2 số><Phòng 2 số>`).
- Duy trì 100% pass toàn bộ 661+ tests tự động.
- `dart analyze` phải đạt 0 issue.

---

### Task 1: Migration SQL Vòng Đời Cư Dân & RPCs Batch Import

**Files:**
- Create: `supabase/migrations/20261030_02_residents_apartments_lifecycle_and_batch_import.sql`
- Test: `test/integration/batch_import_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `residents_apartments`, `apartments`, `users`, `meter_reading_submissions`.
- Produces:
  * Cột `start_date`, `end_date`, `status` trên `residents_apartments`.
  * RPC `batch_import_apartments(p_building_id UUID, p_apartments JSONB)`.
  * RPC `batch_import_residents(p_building_id UUID, p_residents JSONB)`.
  * RPC `batch_import_meter_readings(p_building_id UUID, p_period TEXT, p_readings JSONB)`.

- [ ] **Step 1:** Viết failing test `batch_import_migration_test.dart` kiểm tra sự tồn tại của tệp migration, các cột mới trong `residents_apartments`, và các hàm RPC batch import với kiểm tra quyền RBAC.
- [ ] **Step 2:** Chạy test để xác nhận FAIL.
- [ ] **Step 3:** Tạo tệp migration `supabase/migrations/20261030_02_residents_apartments_lifecycle_and_batch_import.sql`.
- [ ] **Step 4:** Chạy lại test để xác nhận PASS.
- [ ] **Step 5:** Commit task 1 vào `main`.

---

### Task 2: Data Models (Batch Import Models)

**Files:**
- Create: `lib/data/models/batch_import_model.dart`
- Test: `test/data/models/batch_import_model_test.dart`

**Interfaces:**
- Consumes: Dữ liệu parsing từ file Excel và kết quả trả về từ RPC.
- Produces: `BatchImportType`, `BatchRowErrorModel`, `BatchImportResultModel<T>`, `ApartmentImportItem`, `ResidentImportItem`, `MeterReadingImportItem`.

- [ ] **Step 1:** Viết failing test `batch_import_model_test.dart` kiểm tra serialization, getters (`hasErrors`, `hasValidItems`, `errorSummary`), và chuyển đổi các models.
- [ ] **Step 2:** Chạy test để xác nhận FAIL.
- [ ] **Step 3:** Hiện thực hóa các class trong `lib/data/models/batch_import_model.dart`.
- [ ] **Step 4:** Chạy lại test để xác nhận PASS.
- [ ] **Step 5:** Commit task 2 vào `main`.

---

### Task 3: Excel Import Helper & Engine Thẩm Định (Parser, Validator & Templates)

**Files:**
- Create: `lib/core/utils/excel_import_helper.dart`
- Test: `test/core/utils/excel_import_helper_test.dart`

**Interfaces:**
- Consumes: `excel: ^4.0.6`, `BatchImportResultModel`, danh sách mã căn hộ hiện có.
- Produces:
  * `generateApartmentTemplate()`, `generateResidentTemplate()`, `generateMeterReadingTemplate()`.
  * `parseAndValidateApartments(List<int> bytes)`.
  * `parseAndValidateResidents(List<int> bytes, {Set<String>? existingApartmentCodes})`.
  * `parseAndValidateMeterReadings(List<int> bytes, {Set<String>? existingApartmentCodes})`.
  * `exportErrorRows(List<BatchRowErrorModel> errors, String originalFileName)`.

- [ ] **Step 1:** Viết failing test `excel_import_helper_test.dart` kiểm tra sinh template Excel, kiểm tra validation căn hộ (chấp nhận A0110, từ chối A101), kiểm tra validation cư dân (SĐT 10 số, mã căn tồn tại), kiểm tra validation điện nước ($\ge 0$, kỳ `MM/yyyy`), và xuất file dòng lỗi.
- [ ] **Step 2:** Chạy test để xác nhận FAIL.
- [ ] **Step 3:** Hiện thực hóa `lib/core/utils/excel_import_helper.dart`.
- [ ] **Step 4:** Chạy lại test để xác nhận PASS.
- [ ] **Step 5:** Commit task 3 vào `main`.

---

### Task 4: Batch Import Repository & Service

**Files:**
- Create: `lib/data/repositories/batch_import_repository.dart`
- Test: `test/data/repositories/batch_import_repository_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `ApartmentImportItem`, `ResidentImportItem`, `MeterReadingImportItem`.
- Produces:
  * `importApartments({required String buildingId, required List<ApartmentImportItem> items})`.
  * `importResidents({required String buildingId, required List<ResidentImportItem> items})`.
  * `importMeterReadings({required String buildingId, required String period, required List<MeterReadingImportItem> items})`.

- [ ] **Step 1:** Viết failing test `batch_import_repository_test.dart` kiểm tra gọi RPC batch import và fallback nạp cục bộ.
- [ ] **Step 2:** Chạy test để xác nhận FAIL.
- [ ] **Step 3:** Hiện thực hóa `BatchImportRepository`.
- [ ] **Step 4:** Chạy lại test để xác nhận PASS.
- [ ] **Step 5:** Commit task 4 vào `main`.

---

### Task 5: Providers & Màn Hình `BatchImportCenterScreen`

**Files:**
- Create: `lib/data/providers/batch_import_provider.dart`
- Create: `lib/features/management/screens/batch_import_center_screen.dart`
- Modify: `lib/core/router/route_names.dart` & `lib/core/router/app_router.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Test: `test/features/management/screens/batch_import_center_screen_test.dart`

**Interfaces:**
- Consumes: `batchImportRepositoryProvider`, `batchImportStateProvider`.
- Produces: Giao diện 3 tab (Căn hộ, Cư dân, Điện nước), tải file mẫu, chọn file, hiển thị bảng kiểm duyệt, nút xuất file lỗi và nút nạp dữ liệu.

- [ ] **Step 1:** Viết widget test `batch_import_center_screen_test.dart` kiểm tra chuyển 3 tab, hiển thị nút tải mẫu, hiển thị kết quả kiểm duyệt lỗi/hợp lệ và nút thực hiện nhập.
- [ ] **Step 2:** Chạy test để xác nhận FAIL.
- [ ] **Step 3:** Tạo provider `batch_import_provider.dart`.
- [ ] **Step 4:** Xây dựng màn hình `BatchImportCenterScreen`.
- [ ] **Step 5:** Đăng ký route `AppRoutes.managementBatchImport` và thêm lối tắt trên `ManagementHomeScreen`.
- [ ] **Step 6:** Chạy lại widget test để xác nhận PASS.
- [ ] **Step 7:** Commit task 5 vào `main`.

---

### Task 6: Quality Gate, Graphify Update & Cập Nhật Roadmap

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md` (Đánh dấu hoàn tất B2)
- Update: `graphify-out/` qua `python -m graphify update .`

- [ ] **Step 1:** Chạy `dart analyze` đảm bảo 0 warning, 0 error.
- [ ] **Step 2:** Chạy `flutter test` đảm bảo 100% tests (665+ tests) vượt qua.
- [ ] **Step 3:** Chạy `python -m graphify update .` cập nhật Knowledge Graph.
- [ ] **Step 4:** Cập nhật mục `B2` thành `[x]` trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.
- [ ] **Step 5:** Commit hoàn tất toàn bộ tính năng B2 vào `main`.

