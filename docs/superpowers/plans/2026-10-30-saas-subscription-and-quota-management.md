# Kế Hoạch Thực Thi: Gói Dịch Vụ SaaS & Quản Lý Hạn Mức Tòa Nhà (B3)

- **Giai đoạn:** B3 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Tài liệu đặc tả:** [docs/superpowers/specs/2026-10-30-saas-subscription-and-quota-management-design.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-10-30-saas-subscription-and-quota-management-design.md)
- **Quy chuẩn thực thi:** TDD (Test-Driven Development), cam kết commit trực tiếp vào `main`.

---

## Danh Sách Tasks

### Task 1: Migration CSDL & RPC Kiểm Soát Hạn Mức (Database Migration & Integration Test)
- **Mục tiêu:** Tạo bảng `subscription_plans`, `organization_subscriptions`, seed 3 gói dịch vụ chuẩn, trigger `trg_enforce_apartment_quota` và RPC `get_organization_subscription_status`.
- **Files:**
  - `test/integration/subscription_quota_migration_test.dart`
  - `supabase/migrations/20261030_03_saas_subscription_plans_and_quota.sql`
- **Các bước:**
  1. Viết failing integration test `test/integration/subscription_quota_migration_test.dart`.
  2. Viết migration SQL `20261030_03_saas_subscription_plans_and_quota.sql`.
  3. Chạy `flutter test test/integration/subscription_quota_migration_test.dart` -> PASS.
  4. Commit: `feat(db): migration bang subscription_plans va trigger han muc B3`.

### Task 2: Data Models (Subscription & Quota Models)
- **Mục tiêu:** Xây dựng các model quản lý thông tin gói cước, số liệu đo lường hạn mức sử dụng (căn hộ, tòa nhà, nhân viên), tỷ lệ phần trăm và cảnh báo.
- **Files:**
  - `test/data/models/subscription_model_test.dart`
  - `lib/data/models/subscription_plan_model.dart`
  - `lib/data/models/subscription_model.dart`
- **Các bước:**
  1. Viết failing unit test `test/data/models/subscription_model_test.dart`.
  2. Tạo `lib/data/models/subscription_plan_model.dart` và `lib/data/models/subscription_model.dart`.
  3. Chạy `flutter test test/data/models/subscription_model_test.dart` -> PASS.
  4. Commit: `feat(data): them subscription models va quota metrics B3`.

### Task 3: Subscription Repository
- **Mục tiêu:** Hiện thực tầng truy xuất dữ liệu `SubscriptionRepository` gọi RPC máy chủ và có engine offline fallback tính toán chính xác số liệu sử dụng thực tế.
- **Files:**
  - `test/data/repositories/subscription_repository_test.dart`
  - `lib/data/repositories/subscription_repository.dart`
- **Các bước:**
  1. Viết failing test `test/data/repositories/subscription_repository_test.dart`.
  2. Hiện thực `lib/data/repositories/subscription_repository.dart`.
  3. Chạy `flutter test test/data/repositories/subscription_repository_test.dart` -> PASS.
  4. Commit: `feat(repo): subscription repository ho tro lay trang thai thue bao va han muc B3`.

### Task 4: UI Màn Hình Quản Lý Gói Cước & Hạn Mức (Subscription Management Screen)
- **Mục tiêu:** Tạo provider Riverpod và màn hình `SubscriptionManagementScreen` gồm: thẻ thông tin gói hiện tại, thanh tiến độ đo lường hạn mức trực quan 3 màu, bảng so sánh 3 gói cước và nút gửi yêu cầu nâng cấp/gia hạn.
- **Files:**
  - `test/features/management/screens/subscription_management_screen_test.dart`
  - `lib/data/providers/subscription_provider.dart`
  - `lib/features/management/screens/subscription_management_screen.dart`
- **Các bước:**
  1. Viết failing widget test `test/features/management/screens/subscription_management_screen_test.dart`.
  2. Tạo `lib/data/providers/subscription_provider.dart`.
  3. Tạo `lib/features/management/screens/subscription_management_screen.dart`.
  4. Chạy `flutter test test/features/management/screens/subscription_management_screen_test.dart` -> PASS.
  5. Commit: `feat(ui): man hinh quan ly goi dich vu va han muc su dung B3`.

### Task 5: Routing & Lối Tắt Trên Dashboard BQL
- **Mục tiêu:** Đăng ký route `AppRoutes.managementSubscription = '/management/subscription'`, thêm GoRoute và thêm lối tắt "Gói dịch vụ" trên Dashboard BQL.
- **Files:**
  - `lib/core/router/route_names.dart`
  - `lib/core/router/app_router.dart`
  - `lib/features/management/screens/management_home_screen.dart`
- **Các bước:**
  1. Đăng ký route trong `route_names.dart` và `app_router.dart`.
  2. Thêm lối tắt "Gói cước" trong menu Quick Actions của `management_home_screen.dart`.
  3. Commit: `feat(router): tich hop route va loi tat man hinh quan ly goi cuoc B3`.

### Task 6: Verification & Quality Gate
- **Mục tiêu:** Đảm bảo toàn bộ hệ thống đạt 0 issue static analysis, 100% tests pass, cập nhật Graphify Knowledge Graph và roadmap thương mại.
- **Các bước:**
  1. Chạy `dart analyze` (phải đạt 0 issue).
  2. Chạy `flutter test` (đảm bảo 100% tests pass).
  3. Chạy `python -m graphify update .` để đồng bộ Knowledge Graph.
  4. Cập nhật `docs/COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] B3. Gói dịch vụ & Billing cho khách`.
  5. Commit hoàn tất Giai đoạn B3 vào `main`.

