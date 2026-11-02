# Kế Hoạch Thực Thi: Vòng Đời Cư Dân, Hợp Đồng Thuê & Mã Mời Kích Hoạt Tự Phục Vụ (D1)

- **Giai đoạn:** D1 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Tài liệu đặc tả:** [docs/superpowers/specs/2026-10-30-resident-lifecycle-and-contracts-design.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-10-30-resident-lifecycle-and-contracts-design.md)
- **Quy chuẩn thực thi:** TDD (Test-Driven Development), cam kết commit trực tiếp vào `main`.

---

## Danh Sách Tasks

### Task 1: Migration SQL & Schema Tests
- **Mục tiêu:** Tạo migration PostgreSQL bổ sung các cột hợp đồng vào `residents_apartments`, tạo bảng `apartment_invitations`, và các RPCs `create_apartment_invitation`, `accept_apartment_invitation`, `terminate_resident_stay`.
- **Files:**
  - `supabase/migrations/20261030_04_resident_lifecycle_and_contracts.sql`
  - `test/integration/resident_lifecycle_migration_test.dart`
- **Các bước:**
  1. Viết failing integration test `test/integration/resident_lifecycle_migration_test.dart`.
  2. Tạo migration `20261030_04_resident_lifecycle_and_contracts.sql`.
  3. Chạy test `resident_lifecycle_migration_test.dart` -> PASS.
  4. Commit: `feat(db): migration sql quan ly hop dong va ma moi cu dan D1`.

### Task 2: Data Models Cho Hợp Đồng & Mã Mời
- **Mục tiêu:** Xây dựng models `ResidentLeaseContractModel` và `ApartmentInvitationModel` strongly-typed, hỗ trợ format tiền tệ, ngày tháng, và kiểm tra hết hạn.
- **Files:**
  - `lib/data/models/resident_lease_contract_model.dart`
  - `lib/data/models/apartment_invitation_model.dart`
  - `test/data/models/resident_lease_contract_model_test.dart`
  - `test/data/models/apartment_invitation_model_test.dart`
- **Các bước:**
  1. Viết failing unit tests cho 2 models.
  2. Tạo 2 model files.
  3. Chạy tests -> PASS.
  4. Commit: `feat(data): them models hop dong va ma moi cu dan D1`.

### Task 3: Repository & Provider Vòng Đời Cư Dân
- **Mục tiêu:** Xây dựng `ResidentLifecycleRepository` và `resident_lifecycle_provider.dart` với cơ chế tính toán và offline fallback engine.
- **Files:**
  - `lib/data/repositories/resident_lifecycle_repository.dart`
  - `lib/data/providers/resident_lifecycle_provider.dart`
  - `test/data/repositories/resident_lifecycle_repository_test.dart`
- **Các bước:**
  1. Viết failing test `resident_lifecycle_repository_test.dart`.
  2. Tạo repository và provider.
  3. Chạy test -> PASS.
  4. Commit: `feat(data): them resident lifecycle repository va providers D1`.

### Task 4: Giao Diện Tạo Mã Mời & Quản Lý Hợp Đồng
- **Mục tiêu:** Xây dựng các UI components chuyên biệt:
  - `CreateApartmentInvitationSheet`: Sinh mã QR, mã chữ 8 ký tự, nút sao chép liên kết.
  - `ApartmentContractSheet`: Xem danh sách cư dân hiện tại/cũ, số hợp đồng, tiền cọc, nút kết thúc lưu trú có lưu vết.
  - `AcceptInvitationDialog`: Nhập mã mời để kích hoạt vào căn hộ.
- **Files:**
  - `lib/features/management/widgets/create_apartment_invitation_sheet.dart`
  - `lib/features/management/widgets/apartment_contract_sheet.dart`
  - `lib/features/resident/widgets/accept_invitation_dialog.dart`
  - `test/features/management/widgets/apartment_contract_sheet_test.dart`
  - `test/features/resident/widgets/accept_invitation_dialog_test.dart`
- **Các bước:**
  1. Viết failing widget tests.
  2. Tạo các widget files.
  3. Chạy tests -> PASS.
  4. Commit: `feat(ui): hop thoai tao ma moi va quan ly hop dong cu dan D1`.

### Task 5: Tích Hợp Vào Resident360, Apartment Details & Link Request
- **Mục tiêu:** Kết nối các thành phần vào các luồng nghiệp vụ hiện hữu (Resident 360, Quản lý Căn hộ, Màn hình Cư dân xin liên kết).
- **Files:**
  - `lib/features/management/widgets/resident_360_detail_sheet.dart`
  - `lib/features/management/screens/apartment_management_screen.dart`
  - `lib/features/resident/screens/link_request_screen.dart`
- **Các bước:**
  1. Tích hợp nút xem hợp đồng & mời thành viên vào màn hình quản lý.
  2. Tích hợp nút nhập mã mời vào `LinkRequestScreen`.
  3. Commit: `feat(management): tich hop ma moi va hop dong vao cac luong van hanh D1`.

### Task 6: Verification & Quality Gate
- **Mục tiêu:** Xác minh 0 issue tĩnh (`dart analyze`), 100% tests pass (`flutter test`), cập nhật Knowledge Graph và Roadmap.
- **Các bước:**
  1. Chạy `dart analyze` (đạt 0 issue).
  2. Chạy `flutter test` (100% tests pass).
  3. Chạy `python -m graphify update .`.
  4. Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] D1`.
  5. Commit hoàn tất Giai đoạn D1 vào `main`.
