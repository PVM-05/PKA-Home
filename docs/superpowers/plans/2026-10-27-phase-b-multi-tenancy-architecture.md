# Kế Hoạch Thực Thi: Giai Đoạn B - Kiến Trúc Đa Tòa Nhà & Tổ Chức Vận Hành (Multi-Tenancy Architecture)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi hệ thống sang kiến trúc Multi-Tenancy 2 cấp (Organization -> Building -> Units/Staff) với CSDL tách biệt bằng RLS, hỗ trợ nhiều tòa nhà có cùng mã căn (`UNIQUE(building_id, code)`), bộ chuyển đổi tòa nhà trên AppBar cho BQL, đồng thời bảo toàn tính tương thích ngược 100% cho toàn bộ dữ liệu và test suite.

**Architecture:**
- CSDL: Tạo migration `20261027_03_multi_tenancy_organizations_and_buildings.sql` tạo bảng `organizations`, `buildings`, `building_staff`, bổ sung `building_id` vào các bảng nghiệp vụ, backfill với Tòa nhà mẫu canonical và cập nhật RLS policies.
- Flutter Data: Bổ sung `OrganizationModel`, `BuildingModel`, `BuildingStaffModel`, cập nhật `ApartmentModel.buildingId`, tạo `BuildingRepository` và `building_provider.dart` (`activeBuildingProvider`, `userBuildingsProvider`).
- Flutter UI: Thêm widget `BuildingSwitcherDropdown` tích hợp vào AppBar của `ManagementHomeScreen`.

**Tech Stack:** Flutter, Dart, Riverpod, PostgreSQL 15+, Supabase.

## Global Constraints

- Tuân thủ 100% tiếng Việt chuẩn trong nhãn UI theo `design-rules.md`.
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main` theo quy định `AGENTS.md`.
- Đảm bảo 430+ test hiện có không bị đứt gãy nhờ cơ chế canonical backfill default building.
- TDD: Viết test trước, xác nhận fail, viết code, xác nhận pass.

---

### Task 1: Database Migration Multi-Tenancy & Canonical Backfill

**Files:**
- Create: `supabase/migrations/20261027_03_multi_tenancy_organizations_and_buildings.sql`
- Test: `test/integration/multi_tenancy_migration_test.dart`

**Interfaces:**
- Consumes: Bảng hiện có (`apartments`, `announcements`, `building_amenities`, `fee_schedules`, `maintenance_funds`).
- Produces: 
  - Bảng `organizations`, `buildings`, `building_staff`.
  - Canonical Organization (`00000000-0000-0000-0000-000000000001`, slug: `pka-corp`).
  - Canonical Building (`00000000-0000-0000-0000-000000000002`, code: `PKAL`).
  - Cột `building_id` trên `apartments`, `announcements`, `building_amenities`, `fee_schedules`, `maintenance_funds`.
  - Ràng buộc `UNIQUE(building_id, code)` trên bảng `apartments`.
  - Multi-tenant RLS policies.

- [ ] **Step 1: Viết test kiểm tra migration multi-tenancy**
Tạo file `test/integration/multi_tenancy_migration_test.dart` kiểm tra sự tồn tại của migration, các bảng `organizations`, `buildings`, `building_staff`, cột `building_id`, ràng buộc `UNIQUE(building_id, code)` và seed canonical.

- [ ] **Step 2: Chạy test để xác nhận FAIL (TDD)**
Chạy: `flutter test test/integration/multi_tenancy_migration_test.dart`

- [ ] **Step 3: Viết migration `20261027_03_multi_tenancy_organizations_and_buildings.sql`**
Triển khai DDL tạo bảng, seed dữ liệu mẫu, add column, backfill data, drop constraint cũ, add constraint mới và RLS.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/integration/multi_tenancy_migration_test.dart`

- [ ] **Step 5: Commit migration**
```bash
git add supabase/migrations/20261027_03_multi_tenancy_organizations_and_buildings.sql test/integration/multi_tenancy_migration_test.dart ; git commit -m "feat(db): migration multi-tenancy tao organizations, buildings va backfill building_id"
```

---

### Task 2: Data Models (Organization, Building, BuildingStaff & ApartmentModel)

**Files:**
- Create: `lib/data/models/organization_model.dart`
- Create: `lib/data/models/building_model.dart`
- Create: `lib/data/models/building_staff_model.dart`
- Modify: `lib/data/models/apartment_model.dart`
- Test: `test/data/models/multi_tenancy_models_test.dart`

**Interfaces:**
- Consumes: Bảng Supabase `organizations`, `buildings`, `building_staff`, `apartments`.
- Produces: Data classes có đầy đủ `fromJson`, `toJson`, `operator ==`, `hashCode`.

- [ ] **Step 1: Viết test cho các Multi-Tenancy Models**
Tạo file `test/data/models/multi_tenancy_models_test.dart` test serialization/deserialization cho `OrganizationModel`, `BuildingModel`, `BuildingStaffModel` và `ApartmentModel.buildingId`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `flutter test test/data/models/multi_tenancy_models_test.dart`

- [ ] **Step 3: Tạo các file Model và cập nhật `ApartmentModel`**
Viết `organization_model.dart`, `building_model.dart`, `building_staff_model.dart` và bổ sung `final String? buildingId;` vào `apartment_model.dart` (mặc định tương thích ngược).

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/data/models/multi_tenancy_models_test.dart`

- [ ] **Step 5: Commit Models**
```bash
git add lib/data/models/organization_model.dart lib/data/models/building_model.dart lib/data/models/building_staff_model.dart lib/data/models/apartment_model.dart test/data/models/multi_tenancy_models_test.dart ; git commit -m "feat(models): bo sung organization, building, building_staff va cap nhat apartment model"
```

---

### Task 3: BuildingRepository & BuildingProvider Phía Flutter

**Files:**
- Create: `lib/data/repositories/building_repository.dart`
- Create: `lib/data/providers/building_provider.dart`
- Test: `test/data/repositories/building_repository_test.dart`

**Interfaces:**
- Consumes: Bảng `buildings`, `building_staff`.
- Produces: 
  - `buildingRepositoryProvider`: `BuildingRepository`
  - `userBuildingsProvider`: danh sách tòa nhà nhân viên có quyền
  - `activeBuildingIdProvider`: StateNotifier lưu ID tòa nhà đang chọn
  - `activeBuildingProvider`: Provider trả về chi tiết tòa nhà đang kích hoạt

- [ ] **Step 1: Viết test cho BuildingRepository & Provider**
Tạo file `test/data/repositories/building_repository_test.dart`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `flutter test test/data/repositories/building_repository_test.dart`

- [ ] **Step 3: Tạo `building_repository.dart` và `building_provider.dart`**
Triển khai logic truy vấn danh sách tòa nhà theo user, hàm lấy chi tiết tòa nhà và Riverpod state management.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/data/repositories/building_repository_test.dart`

- [ ] **Step 5: Commit Repository & Provider**
```bash
git add lib/data/repositories/building_repository.dart lib/data/providers/building_provider.dart test/data/repositories/building_repository_test.dart ; git commit -m "feat(tenancy): them building repository va active building provider"
```

---

### Task 4: UI Building Switcher Component & Tích Hợp Management Screen

**Files:**
- Create: `lib/core/widgets/building_switcher_dropdown.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Test: `test/core/widgets/building_switcher_dropdown_test.dart`

**Interfaces:**
- Consumes: `userBuildingsProvider`, `activeBuildingIdProvider`.
- Produces: Dropdown trên AppBar cho phép BQL chuyển đổi tòa nhà khi có từ 2 tòa trở lên, hoặc hiển thị tên tòa tĩnh khi có 1 tòa.

- [ ] **Step 1: Viết test cho `BuildingSwitcherDropdown`**
Tạo file `test/core/widgets/building_switcher_dropdown_test.dart` kiểm tra hiển thị tên tòa nhà và thao tác chọn chuyển tòa nhà kích hoạt `activeBuildingIdProvider`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `flutter test test/core/widgets/building_switcher_dropdown_test.dart`

- [ ] **Step 3: Tạo `building_switcher_dropdown.dart` và nhúng vào `management_home_screen.dart`**
Xây dựng widget `BuildingSwitcherDropdown` và thêm vào `actions` hoặc `title` trên `AppBar` của `ManagementHomeScreen`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/core/widgets/building_switcher_dropdown_test.dart`

- [ ] **Step 5: Commit UI Building Switcher**
```bash
git add lib/core/widgets/building_switcher_dropdown.dart lib/features/management/screens/management_home_screen.dart test/core/widgets/building_switcher_dropdown_test.dart ; git commit -m "feat(ui): them building switcher dropdown vao giao dien quan ly toa nha"
```

---

### Task 5: Rà Soát Toàn Diện & Verification Hồi Quy

**Files:** Toàn bộ dự án

- [ ] **Step 1: Chạy `flutter analyze`**
Đảm bảo 0 errors, 0 warnings.

- [ ] **Step 2: Chạy toàn bộ test suite `flutter test`**
Đảm bảo 100% tests PASS (bao gồm 430 tests cũ + các tests mới).

- [ ] **Step 3: Commit hoàn tất Giai đoạn B**
```bash
git commit --allow-empty -m "chore: hoan thanh xac minh giai doan B multi-tenancy architecture"
```
