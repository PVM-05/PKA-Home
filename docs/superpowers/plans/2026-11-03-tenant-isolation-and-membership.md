# Kế Hoạch Thực Thi: Gói 1 - Cách Ly Tenant & Mô Hình Membership Đa Tầng (SEC-01, SEC-02, SaaS-01)

**Mã kế hoạch:** `PLAN-HARDENING-01`  
**Tài liệu thiết kế:** [`docs/superpowers/specs/2026-11-03-tenant-isolation-and-membership-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-03-tenant-isolation-and-membership-design.md)  
**Quy tắc Git:** Toàn bộ công việc commit trực tiếp vào `main`, không tạo branch/worktree phụ.

---

## Danh Sách Các Bước Thực Thi (Tasks)

- [x] **Task 1: Migration CSDL Cách Ly Tenant & Bảng Memberships (`20261103_05_tenant_isolation_and_memberships.sql`)**
  - Viết test kiểm tra migration SQL: `test/database/tenant_isolation_migration_test.dart` (4/4 tests pass)
  - Viết migration: `supabase/migrations/20261103_05_tenant_isolation_and_memberships.sql`
    - Tạo bảng `organization_memberships` và `building_memberships`
    - Cài đặt 3 hàm bảo mật: `get_user_accessible_organizations`, `get_user_accessible_buildings`, `has_building_role`
    - Xóa bỏ toàn bộ chính sách RLS `USING (true)` trên `organizations`, `buildings`, `apartments`, `building_staff`, `maintenance_funds`, `maintenance_fund_transactions`
    - Thiết lập các chính sách RLS siết chặt theo `building_id` và quyền thành viên
    - Tự động di chuyển dữ liệu cũ từ `building_staff` và `residents_apartments` sang `building_memberships`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`: `a8c2398`

- [x] **Task 2: Data Models Dart (`OrganizationMembershipModel`, `BuildingMembershipModel`)**
  - Viết unit test: `test/data/models/membership_model_test.dart` (3/3 tests pass)
  - Tạo model `lib/data/models/organization_membership_model.dart`
  - Tạo model `lib/data/models/building_membership_model.dart`
  - Đảm bảo đầy đủ `fromJson`, `toJson`, `copyWith`, kiểm tra hạn dùng ủy quyền `isExpired`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`: `09f7b0f`

- [x] **Task 3: Tầng Dữ Liệu Membership Repository (`MembershipRepository`)**
  - Viết unit test repository: `test/data/repositories/membership_repository_test.dart` (7/7 tests pass)
  - Tạo repository: `lib/data/repositories/membership_repository.dart`
    - `fetchUserBuildingMemberships(String userId)`
    - `fetchBuildingMembers(String buildingId)`
    - `assignBuildingMembership(...)`
    - `revokeBuildingMembership(String membershipId)`
  - Đăng ký Provider Riverpod: `membershipRepositoryProvider`, `userBuildingMembershipsProvider`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`: `c066265`

- [x] **Task 4: Tích Hợp Kiểm Tra Quyền Theo Tòa Nhà Trong Tầng Quản Trị**
  - Cập nhật logic phân quyền trong tầng ứng dụng: kiểm tra quyền theo `building_id` thay vì dựa vào trường `users.role` toàn cục
  - Nâng cấp `PermissionItem.allows(role, buildingRoles: ...)` và `RoleGuard(buildingId: ...)`
  - Viết test xác nhận: `test/features/management/tenant_isolation_guard_test.dart` (3/3 tests pass)
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`: `a969832`

- [x] **Task 5: Nghiệm Thu Gói 1, Cập Nhật Roadmap & Quality Gate**
  - Kiểm tra toàn bộ mã nguồn: `dart analyze lib test` (0 lỗi, 0 cảnh báo, 0 info)
  - Chạy toàn bộ test suite Gói 1 (17/17 tests pass)
  - Cập nhật Knowledge Graph: `python -m graphify update .`
  - Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md`
  - Commit nghiệm thu vào `main`
