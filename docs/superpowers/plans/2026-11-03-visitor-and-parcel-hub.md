# Kế Hoạch Thực Thi: An Ninh Tòa Nhà, Đăng Ký Khách Trước Bằng Mã QR & Quản Lý Bưu Kiện Lễ Tân (D6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống an ninh kiểm soát khách viếng thăm bằng mã QR (Visitor Pre-registration) và trung tâm quản lý giao nhận bưu kiện tại quầy lễ tân (Front-Desk Parcel Hub) cho cả Ban Quản Lý/An Ninh và Cư Dân.

**Architecture:** Bảng CSDL `visitor_access_passes` và `parcels`; các DB triggers sinh mã tự động; 4 RPCs PostgreSQL (check-in, check-out, nhận bưu kiện, KPI sảnh); Data Models strongly-typed; `FrontDeskRepository` với Offline Fallback Engine; Màn hình trạm làm việc lễ tân BQL (`FrontDeskWorkstationScreen`); Màn hình đón khách & nhận bưu kiện của cư dân (`ResidentVisitorParcelScreen`).

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL 15), Riverpod 2.x, TDD.

## Global Constraints
- Commit trực tiếp trên nhánh `main` (không tạo branch phụ/worktree).
- Giao diện 100% tiếng Việt chuẩn mực, không hardcode màu sắc, không giới hạn chiều cao cứng (tránh RenderFlex overflow).
- Tuân thủ nghiêm ngặt quy trình TDD: Viết test trước -> Test fail -> Viết code tối thiểu -> Test pass -> Commit.
- Đảm bảo 0 issue static analysis (`dart analyze`) và 100% tests pass.

---

## Danh Sách Tasks

### Task 1: Migration SQL & Schema Tests (D6)
- **Mục tiêu:** Tạo migration PostgreSQL định nghĩa bảng `visitor_access_passes`, `parcels`, triggers sinh mã và 4 RPCs.
- **Files:**
  - Create: `supabase/migrations/20261103_01_visitor_and_parcel_hub.sql`
  - Test: `test/integration/visitor_and_parcel_migration_test.dart`
- **Interfaces:**
  - Produces: Migration SQL hợp lệ và các RPCs `check_in_visitor_pass`, `check_out_visitor_pass`, `collect_parcel`, `get_front_desk_stats`.
- [x] **Step 1:** Viết failing test `test/integration/visitor_and_parcel_migration_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận test fail.
- [x] **Step 3:** Tạo migration `supabase/migrations/20261103_01_visitor_and_parcel_hub.sql`.
- [x] **Step 4:** Chạy test xác minh 100% test pass.
- [x] **Step 5:** Commit: `feat(db): migration sql dang ky khach qr va buu kien le tan D6`.

---

### Task 2: Data Models Khách Viếng Thăm & Bưu Kiện (D6)
- **Mục tiêu:** Xây dựng các models strongly-typed cho vé khách, bưu kiện và thống kê quầy lễ tân.
- **Files:**
  - Create: `lib/data/models/visitor_pass_model.dart`
  - Create: `lib/data/models/parcel_model.dart`
  - Create: `lib/data/models/front_desk_stats_model.dart`
  - Test: `test/data/models/visitor_pass_model_test.dart`
  - Test: `test/data/models/parcel_model_test.dart`
  - Test: `test/data/models/front_desk_stats_model_test.dart`
- **Interfaces:**
  - Consumes: JSON từ Supabase tables `visitor_access_passes`, `parcels`.
  - Produces: `VisitorPassModel`, `ParcelModel`, `FrontDeskStatsModel` với đầy đủ getters logic hiển thị.
- [x] **Step 1:** Viết failing unit tests cho các models.
- [x] **Step 2:** Chạy tests để xác nhận fail.
- [x] **Step 3:** Cài đặt các models.
- [x] **Step 4:** Chạy unit tests xác minh 100% pass.
- [x] **Step 5:** Commit: `feat(data): them models ve khach va buu kien le tan D6`.

---

### Task 3: Repository & Provider Quản Lý Sảnh & Bưu Kiện (D6)
- **Mục tiêu:** Xây dựng `FrontDeskRepository` và các Riverpod providers với cơ chế Offline Fallback Engine phong phú.
- **Files:**
  - Create: `lib/data/repositories/front_desk_repository.dart`
  - Create: `lib/data/providers/front_desk_provider.dart`
  - Test: `test/data/repositories/front_desk_repository_test.dart`
- **Interfaces:**
  - Consumes: Models từ Task 2.
  - Produces: `FrontDeskRepository` với các phương thức nghiệp vụ và providers cho BQL và Cư dân.
- [x] **Step 1:** Viết failing test `front_desk_repository_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận fail.
- [x] **Step 3:** Cài đặt `front_desk_repository.dart` và `front_desk_provider.dart`.
- [x] **Step 4:** Chạy test xác minh 100% pass.
- [x] **Step 5:** Commit: `feat(data): them repository va provider quan ly sanh le tan D6`.

---

### Task 4: Giao Diện Ban Quản Lý - Trạm Lễ Tân & An Ninh (D6)
- **Mục tiêu:** Xây dựng màn hình `FrontDeskWorkstationScreen` với 2 tab lớn (Quản lý khách vào ra & Trạm bưu kiện) kèm modal tiếp nhận kiện hàng và bàn giao mã PIN.
- **Files:**
  - Create: `lib/features/management/screens/front_desk_workstation_screen.dart`
  - Create: `lib/features/management/widgets/receive_parcel_sheet.dart`
  - Create: `lib/features/management/widgets/handover_parcel_dialog.dart`
  - Test: `test/features/management/screens/front_desk_workstation_screen_test.dart`
- **Interfaces:**
  - Consumes: `FrontDeskRepository`, `front_desk_provider.dart`.
  - Produces: Màn hình trạm làm việc lễ tân thích ứng đa nền tảng.
- [x] **Step 1:** Viết widget test `front_desk_workstation_screen_test.dart`.
- [x] **Step 2:** Chạy test để xác nhận fail.
- [x] **Step 3:** Cài đặt các màn hình và widgets BQL.
- [x] **Step 4:** Chạy widget test xác minh pass.
- [x] **Step 5:** Commit: `feat(ui): tram lam viec le tan an ninh va tiep nhan buu kien D6`.

---

### Task 5: Giao Diện Cư Dân & Tích Hợp Luồng Nghiệp Vụ Toàn App (D6)
- **Mục tiêu:** Xây dựng màn hình cư dân `ResidentVisitorParcelScreen`, tạo vé đón khách kèm mã QR lớn, hiển thị danh mục bưu phẩm chờ nhận và tích hợp router, lối tắt Home.
- **Files:**
  - Create: `lib/features/resident/screens/resident_visitor_parcel_screen.dart`
  - Create: `lib/features/resident/widgets/create_visitor_pass_sheet.dart`
  - Create: `lib/features/resident/widgets/visitor_pass_qr_sheet.dart`
  - Modify: `lib/core/router/route_names.dart`
  - Modify: `lib/core/router/app_router.dart`
  - Modify: `lib/features/management/screens/management_home_screen.dart`
  - Modify: `lib/features/resident/screens/resident_home_screen.dart`
  - Test: `test/features/resident/screens/resident_visitor_parcel_screen_test.dart`
  - Test: `test/integration/visitor_and_parcel_workflow_integration_test.dart`
- **Interfaces:**
  - Consumes: Mọi tính năng từ Task 1-4.
  - Produces: Luồng khép kín từ cư dân tạo vé đón khách -> bảo vệ check-in -> shipper gửi bưu phẩm -> cư dân dùng mã PIN nhận hàng.
- [x] **Step 1:** Cài đặt màn hình cư dân, routes và lối tắt Dashboard.
- [x] **Step 2:** Viết integration test luồng toàn diện.
- [x] **Step 3:** Chạy test xác minh 100% pass.
- [x] **Step 4:** Commit: `feat(management): tich hop ve khach va buu kien vao ung dung D6`.

---

### Task 6: Verification, Roadmap & Quality Gate (D6)
- **Mục tiêu:** Kiểm tra static analysis toàn dự án, chạy test suite, cập nhật Knowledge Graph và Roadmap.
- **Files:**
  - Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
  - Modify: `docs/superpowers/plans/2026-11-03-visitor-and-parcel-hub.md`
- [x] **Step 1:** Chạy `dart analyze` toàn dự án (đạt 0 issue).
- [x] **Step 2:** Chạy toàn bộ test suite D6 (100% pass: 22/22 tests).
- [x] **Step 3:** Chạy `python -m graphify update .` đồng bộ Knowledge Graph (8.881 nodes, 12.518 edges).
- [x] **Step 4:** Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] D6`.
- [x] **Step 5:** Commit: `feat: hoan tat D6 an ninh dang ky khach va buu kien le tan`.
