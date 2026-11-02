# Kế Hoạch Thực Thi: Cảnh Báo SLA Đa Tầng, Phân Công Chuyên Môn & Quản Lý Vật Tư Tiêu Hao Sự Cố (D3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Xây dựng hệ thống giám sát thời hạn xử lý sự cố (SLA đa tầng tự động), phân công kỹ thuật viên theo chuyên môn (điện, nước, nội thất, PCCC) và quản lý xuất kho/tính phí vật tư tiêu hao sửa chữa cho căn hộ và tòa nhà.

**Architecture:** Bổ sung cột SLA và phân loại chuyên môn trên `issue_reports`; bảng danh mục kho vật tư `maintenance_materials` và nhật ký sử dụng `issue_materials`; Trigger tính deadline tự động; Repository với Offline Fallback Engine 10 vật tư mẫu; UI Ban Quản Lý (KPI SLA, đếm ngược thời gian thực, bảng kê vật tư nghiệm thu, quản lý kho vật tư) và UI Cư Dân (chọn chuyên môn, theo dõi tiến độ SLA và bảng vật tư minh bạch).

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL 15), Riverpod 2.x, TDD.

## Global Constraints
- Commit trực tiếp trên nhánh `main` (không tạo branch phụ/worktree).
- Giao diện 100% tiếng Việt chuẩn mực, không hardcode màu sắc, không giới hạn chiều cao cứng (tránh RenderFlex overflow).
- Tuân thủ nghiêm ngặt quy trình TDD: Viết test trước -> Test fail -> Viết code tối thiểu -> Test pass -> Commit.
- Đảm bảo 0 issue static analysis (`dart analyze`) và 100% tests pass.

---

## Danh Sách Tasks

### Task 1: Migration SQL & Schema Tests (D3)
- **Mục tiêu:** Tạo migration PostgreSQL bổ sung các cột SLA trên `issue_reports`, tạo bảng `maintenance_materials`, `issue_materials`, các triggers và RPCs.
- **Files:**
  - Create: `supabase/migrations/20261102_02_issue_sla_and_materials.sql`
  - Test: `test/integration/issue_sla_and_materials_migration_test.dart`
- **Interfaces:**
  - Produces: Migration SQL hợp lệ và các RPCs `get_issue_sla_stats`, `record_issue_materials_usage`, `charge_issue_materials_to_invoice`.
- [x] **Step 1:** Viết failing test `test/integration/issue_sla_and_materials_migration_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận test fail.
- [x] **Step 3:** Tạo migration `supabase/migrations/20261102_02_issue_sla_and_materials.sql`.
- [x] **Step 4:** Chạy test xác minh 100% test pass.
- [x] **Step 5:** Commit: `feat(db): migration sql canh bao sla va kho vat tu su co D3`.

---

### Task 2: Data Models Cho Vật Tư Tiêu Hao & SLA (D3)
- **Mục tiêu:** Xây dựng các models strongly-typed cho vật tư kho, vật tư sử dụng, thống kê SLA và mở rộng `IssueModel`.
- **Files:**
  - Create: `lib/data/models/maintenance_material_model.dart`
  - Create: `lib/data/models/issue_material_usage_model.dart`
  - Create: `lib/data/models/issue_sla_stats_model.dart`
  - Modify: `lib/data/models/issue_model.dart`
  - Test: `test/data/models/maintenance_material_model_test.dart`
  - Test: `test/data/models/issue_material_usage_model_test.dart`
  - Test: `test/data/models/issue_sla_stats_model_test.dart`
- **Interfaces:**
  - Consumes: JSON từ Supabase tables `maintenance_materials`, `issue_materials`, `issue_reports`.
  - Produces: `MaintenanceMaterialModel`, `IssueMaterialUsageModel`, `IssueSlaStatsModel`, `IssueModel` (với getters `isSlaBreached`, `isSlaWarning`, `slaRemainingFormatted`, `categoryDisplayName`).
- [x] **Step 1:** Viết failing unit tests cho các models.
- [x] **Step 2:** Chạy tests để xác nhận fail.
- [x] **Step 3:** Tạo các models và mở rộng `IssueModel`.
- [x] **Step 4:** Chạy unit tests xác minh 100% pass.
- [x] **Step 5:** Commit: `feat(data): them models vat tu va sla su co D3`.

---

### Task 3: Repository & Provider Quản Lý Vật Tư & SLA (D3)
- **Mục tiêu:** Xây dựng `MaterialRepository` và mở rộng `ManagementRepository` với cơ chế Offline Fallback Engine cho danh mục vật tư kho và ghi nhận sử dụng.
- **Files:**
  - Create: `lib/data/repositories/material_repository.dart`
  - Create: `lib/data/providers/material_provider.dart`
  - Modify: `lib/data/repositories/management_repository.dart`
  - Test: `test/data/repositories/material_repository_test.dart`
- **Interfaces:**
  - Consumes: Models từ Task 2.
  - Produces: `MaterialRepository` với `fetchMaterials`, `fetchIssueMaterials`, `recordMaterialsUsage`, `fetchSlaStats`, và các Riverpod providers.
- [x] **Step 1:** Viết failing test `material_repository_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận fail.
- [x] **Step 3:** Cài đặt `material_repository.dart` và `material_provider.dart`.
- [x] **Step 4:** Chạy test xác minh 100% pass.
- [x] **Step 5:** Commit: `feat(data): them repository va provider vat tu va sla D3`.

---

### Task 4: Giao Diện Quản Lý SLA & Nghiệm Thu Vật Tư BQL (D3)
- **Mục tiêu:** 
  - Cập nhật `IssueManagementScreen` hiển thị dải KPI SLA, chip SLA đếm ngược đổi màu động, bộ lọc chuyên môn.
  - Xây dựng hộp thoại nghiệm thu và xuất kho vật tư `ResolveIssueWithMaterialsSheet`.
  - Xây dựng màn hình quản lý kho vật tư `MaintenanceMaterialsScreen`.
- **Files:**
  - Create: `lib/features/management/widgets/resolve_issue_materials_sheet.dart`
  - Create: `lib/features/management/screens/maintenance_materials_screen.dart`
  - Modify: `lib/features/management/screens/issue_management_screen.dart`
  - Test: `test/features/management/screens/issue_management_sla_test.dart`
- **Interfaces:**
  - Consumes: `MaterialRepository`, `material_provider.dart`, `IssueModel`.
  - Produces: Giao diện quản lý giám sát SLA và kho vật tư hoàn chỉnh cho BQL.
- [x] **Step 1:** Viết widget test `issue_management_sla_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận fail.
- [x] **Step 3:** Cài đặt các widget và màn hình quản lý.
- [x] **Step 4:** Chạy widget test xác minh pass.
- [x] **Step 5:** Commit: `feat(ui): giao dien giam sat sla va xuat kho vat tu su co D3`.

---

### Task 5: Tích Hợp Luồng Nghiệp Vụ & Cư Dân (D3)
- **Mục tiêu:** 
  - Đăng ký route `/management/materials` và lối tắt BQL.
  - Cập nhật màn hình báo cáo sự cố của cư dân (`CreateIssueScreen`) bổ sung chọn Chuyên môn và hiển thị cam kết SLA.
  - Cập nhật chi tiết sự cố (`IssueDetailScreen`) hiển thị tiến độ SLA và bảng vật tư thay thế minh bạch.
- **Files:**
  - Modify: `lib/core/router/route_names.dart`
  - Modify: `lib/core/router/app_router.dart`
  - Modify: `lib/features/management/screens/management_home_screen.dart`
  - Modify: `lib/features/resident/screens/create_issue_screen.dart`
  - Modify: `lib/features/resident/screens/issue_detail_screen.dart`
  - Test: `test/integration/issue_sla_and_materials_workflow_integration_test.dart`
- **Interfaces:**
  - Consumes: Mọi tính năng từ Task 1-4.
  - Produces: Luồng nghiệp vụ khép kín từ báo cáo -> tiếp nhận -> tính SLA -> nghiệm thu xuất kho vật tư -> cư dân tra cứu.
- [x] **Step 1:** Cập nhật routes, màn hình cư dân.
- [x] **Step 2:** Viết integration test luồng toàn diện.
- [x] **Step 3:** Chạy test xác minh 100% pass.
- [x] **Step 4:** Commit: `feat(management): tich hop sla va vat tu vao luong su co va cu dan D3`.

---

### Task 6: Verification, Roadmap & Quality Gate (D3)
- **Mục tiêu:** Kiểm tra static analysis toàn dự án, chạy full test suite, cập nhật Knowledge Graph và Roadmap.
- **Files:**
  - Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
  - Modify: `docs/superpowers/plans/2026-11-02-issue-sla-and-materials.md`
- [x] **Step 1:** Chạy `dart analyze` toàn dự án (đạt 0 issue).
- [x] **Step 2:** Chạy `flutter test` toàn dự án (100% pass).
- [x] **Step 3:** Chạy `python -m graphify update .` đồng bộ Knowledge Graph.
- [x] **Step 4:** Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] D3`.
- [x] **Step 5:** Commit: `feat: hoan tat D3 canh bao sla va quan ly vat tu su co`.

