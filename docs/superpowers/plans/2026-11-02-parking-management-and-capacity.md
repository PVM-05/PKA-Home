# Kế Hoạch Thực Thi: Quản Lý Ô Đỗ Hầm, Sức Chứa Bãi Xe & Vé Xe Vãng Lai (D2)

- **Giai đoạn:** D2 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Tài liệu đặc tả:** [docs/superpowers/specs/2026-11-02-parking-management-and-capacity-design.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-02-parking-management-and-capacity-design.md)
- **Quy chuẩn thực thi:** TDD (Test-Driven Development), cam kết commit trực tiếp vào `main`.

---

## Danh Sách Tasks

### Task 1: Migration SQL & Schema Tests
- **Mục tiêu:** Tạo migration PostgreSQL bổ sung bảng `parking_slots`, `visitor_parking_tickets`, trường `parking_slot_id` / `parking_slot_number` vào `vehicles`, và các RPCs `get_parking_capacity_stats`, `calculate_visitor_parking_fee`, `checkout_visitor_ticket`.
- **Files:**
  - `supabase/migrations/20261102_01_parking_slots_and_visitor_tickets.sql`
  - `test/integration/parking_management_migration_test.dart`
- **Các bước:**
  1. Viết failing integration test `test/integration/parking_management_migration_test.dart`.
  2. Tạo migration `20261102_01_parking_slots_and_visitor_tickets.sql`.
  3. Chạy test `parking_management_migration_test.dart` -> PASS.
  4. Commit: `feat(db): migration sql quan ly o do ham va ve xe vang lai D2`.

### Task 2: Data Models Cho Ô Đỗ & Vé Xe Vãng Lai
- **Mục tiêu:** Xây dựng các models strongly-typed: `ParkingSlotModel`, `VisitorParkingTicketModel`, `ParkingCapacityStatsModel`, hỗ trợ format trạng thái, tiền tệ và ngày tháng.
- **Files:**
  - `lib/data/models/parking_slot_model.dart`
  - `lib/data/models/visitor_parking_ticket_model.dart`
  - `lib/data/models/parking_capacity_stats_model.dart`
  - `test/data/models/parking_slot_model_test.dart`
  - `test/data/models/visitor_parking_ticket_model_test.dart`
- **Các bước:**
  1. Viết failing unit tests cho các models.
  2. Tạo các file model.
  3. Chạy tests -> PASS.
  4. Commit: `feat(data): them models o do ham va ve xe vang lai D2`.

### Task 3: Repository & Provider Quản Lý Bãi Xe
- **Mục tiêu:** Xây dựng `ParkingRepository` và `parking_provider.dart` với cơ chế tính toán và offline fallback engine đầy đủ cho ô đỗ và vé vãng lai.
- **Files:**
  - `lib/data/repositories/parking_repository.dart`
  - `lib/data/providers/parking_provider.dart`
  - `test/data/repositories/parking_repository_test.dart`
- **Các bước:**
  1. Viết failing test `parking_repository_test.dart`.
  2. Tạo repository và provider.
  3. Chạy test -> PASS.
  4. Commit: `feat(data): them parking repository va providers D2`.

### Task 4: Giao Diện Quản Lý Ô Đỗ & Trạm Soát Vé Bảo Vệ
- **Mục tiêu:** Xây dựng màn hình `ParkingManagementScreen`:
  - Tab 1: Sơ đồ Ô đỗ tầng hầm (Slots Grid) với bộ lọc tầng B1/B2, ô tô/xe máy, ô trống/đã đỗ, thao tác gán ô đỗ.
  - Tab 2: Trạm soát vé cổng (Gate Workstation): Check-in xe vào sinh mã QR vé, Check-out xe ra tự động tính cước theo giờ và xuất mã VietQR thanh toán.
- **Files:**
  - `lib/features/management/screens/parking_management_screen.dart`
  - `test/features/management/screens/parking_management_screen_test.dart`
- **Các bước:**
  1. Viết failing widget test.
  2. Tạo file `parking_management_screen.dart`.
  3. Chạy test -> PASS.
  4. Commit: `feat(ui): man hinh quan ly o do ham va tram kiem soat cong D2`.

### Task 5: Tích Hợp Vào Dashboard BQL & Màn Hình Cư Dân
- **Mục tiêu:** 
  - Đăng ký route `/management/parking` trong `AppRoutes`.
  - Tích hợp mục "Bãi xe & Ô đỗ" vào Sidebar / Tab BQL và lối tắt tại Dashboard.
  - Hiển thị vị trí ô đỗ cố định trên thẻ xe tại `VehicleManagementScreen`.
- **Files:**
  - `lib/core/router/route_names.dart`
  - `lib/core/router/app_router.dart`
  - `lib/features/management/screens/management_home_screen.dart`
  - `lib/features/resident/screens/vehicle_management_screen.dart`
  - `test/integration/parking_workflow_integration_test.dart`
- **Các bước:**
  1. Cập nhật route và giao diện BQL.
  2. Cập nhật thẻ xe cư dân.
  3. Viết và chạy test tích hợp luồng `parking_workflow_integration_test.dart` -> PASS.
  4. Commit: `feat(management): tich hop bai xe va vi tri o do vao app D2`.

### Task 6: Verification & Quality Gate
- **Mục tiêu:** Xác minh 0 issue tĩnh (`dart analyze`), 100% tests pass (`flutter test`), cập nhật Knowledge Graph và Roadmap.
- **Các bước:**
  1. Chạy `dart analyze` (đạt 0 issue).
  2. Chạy `flutter test` (100% tests pass).
  3. Chạy `python -m graphify update .`.
  4. Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] D2`.
  5. Commit hoàn tất Giai đoạn D2 vào `main`.
