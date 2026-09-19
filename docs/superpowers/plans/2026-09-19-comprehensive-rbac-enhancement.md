# Kế Hoạch Thực Thi: Hệ Thống RBAC Toàn Diện & Trải Nghiệm Vai Trò

- **Ngày lập**: 2026-09-19
- **Tài liệu đặc tả**: [`docs/superpowers/specs/2026-09-19-comprehensive-rbac-enhancement-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-09-19-comprehensive-rbac-enhancement-design.md)
- **Mục tiêu**: Hoàn thiện toàn bộ 5 hạng mục nâng cấp RBAC, chuẩn hóa RLS Least Privilege, ủy quyền tạm thời có thời hạn, RoleGuard 2 lớp phòng thủ, nâng cấp Audit Trail & hiệu suất, Onboarding theo vai trò và Bảng ma trận quyền hạn trực quan.

---

## Danh Mục File Thay Đổi & Tạo Mới

### File Tạo Mới
1. `supabase/migrations/20260920_01_comprehensive_rbac_and_delegations.sql` (Migration CSDL)
2. `lib/core/constants/permissions.dart` (Single Source of Truth cho quyền hạn)
3. `lib/core/widgets/role_guard.dart` (Widget bảo vệ màn hình 2 lớp)
4. `lib/data/models/role_delegation_model.dart` (Data class ánh xạ `role_delegations`)
5. `lib/data/providers/role_delegation_provider.dart` (Quản lý trạng thái ủy quyền thời gian thực)
6. `lib/features/management/screens/role_delegation_screen.dart` (Giao diện Admin quản lý ủy quyền)
7. `lib/features/management/screens/permission_matrix_screen.dart` (Bảng ma trận quyền hạn)
8. `lib/features/management/widgets/role_onboarding_dialog.dart` (Dialog chào mừng & onboarding theo vai trò)
9. `lib/features/management/widgets/technician_performance_card.dart` (Thẻ tổng kết hiệu suất Kỹ thuật viên)
10. `test/core/constants/permissions_test.dart` (Unit test phân quyền)
11. `test/core/widgets/role_guard_test.dart` (Widget test RoleGuard)
12. `test/data/models/role_delegation_model_test.dart` (Unit test model ủy quyền)

### File Chỉnh Sửa
1. `pubspec.yaml` (Thêm package `shared_preferences`)
2. `lib/data/repositories/management_repository.dart` (Thêm các phương thức CRUD ủy quyền & thống kê sự cố)
3. `lib/features/management/screens/management_home_screen.dart` (Tích hợp onboarding, menu ma trận, ủy quyền)
4. `lib/features/management/screens/audit_trail_screen.dart` (Tích hợp bộ lọc, hiệu suất KTV, log đổi quyền)
5. `lib/features/management/screens/invoice_management_screen.dart` (Bọc RoleGuard)
6. `lib/features/management/screens/create_invoice_screen.dart` (Bọc RoleGuard)
7. `lib/features/management/screens/issue_management_screen.dart` (Bọc RoleGuard)
8. `lib/features/management/screens/resident_management_screen.dart` (Bọc RoleGuard)
9. `lib/features/management/screens/link_request_management_screen.dart` (Bọc RoleGuard)
10. `lib/features/management/screens/apartment_management_screen.dart` (Bọc RoleGuard)
11. `lib/features/management/screens/handbook_management_screen.dart` (Bọc RoleGuard)

---

## Các Bước Thực Thi Chi Tiết (Bite-Sized Tasks)

### Task 1: Thiết Lập CSDL & Migration RLS Toàn Diện (Database Layer)
- **Mục tiêu**: Tạo file migration `20260920_01_comprehensive_rbac_and_delegations.sql`:
  - `is_management()` chuyển thành alias gọi `public.is_admin()`.
  - Tạo `is_staff()` (`role IN ('admin', 'management', 'accountant', 'technician')`).
  - Cài đặt extension `btree_gist`.
  - Tạo bảng `public.role_delegations` với các ràng buộc:
    - `chk_no_admin_delegation CHECK (delegated_role IN ('accountant', 'technician'))`
    - `chk_valid_time_range CHECK (ends_at > starts_at)`
    - `chk_no_self_delegation CHECK (delegator_id <> delegate_id)`
    - `no_overlapping_delegations EXCLUDE USING gist (delegate_id WITH =, delegated_role WITH =, tstzrange(starts_at, ends_at) WITH &&)`
  - Mở rộng `is_accountant()` và `is_technician()` để kiểm tra thêm `role_delegations` active.
  - Chuẩn hóa policy bảng `apartment_link_requests` dùng `is_admin()` để đồng bộ với RPC `approve_link_request`.
  - Siết chặt quyền sửa/xóa các bảng `apartments`, `residents_apartments`, `announcements`, `building_rules`, `building_amenities`, `emergency_contacts` chỉ dành cho `is_management()`.

### Task 2: Cài Đặt Dependencies & Single Source of Truth (`permissions.dart`)
- **Bước 2.1**: Thêm `shared_preferences: ^2.5.4` vào `pubspec.yaml`, chạy `flutter pub get`.
- **Bước 2.2**: Viết test `test/core/constants/permissions_test.dart` kiểm tra:
  - Phân quyền mặc định của từng `PermissionItem` cho từng vai trò (`admin`, `accountant`, `technician`, `resident`).
  - Kiểm tra mở rộng quyền khi có `activeDelegations`.
- **Bước 2.3**: Tạo `lib/core/constants/permissions.dart` với `PermissionItem` và `AppPermissions` chứa đầy đủ 7 danh mục quyền.
- **Bước 2.4**: Chạy `flutter test test/core/constants/permissions_test.dart` để xác nhận pass.

### Task 3: Phát Triển Widget `RoleGuard` & Bọc Các Màn Hình Entry-Point
- **Bước 3.1**: Viết widget test `test/core/widgets/role_guard_test.dart` kiểm tra 2 tình huống:
  - Người dùng có quyền -> hiển thị `child`.
  - Người dùng không có quyền -> hiển thị màn hình từ chối truy cập với nút "Quay lại".
- **Bước 3.2**: Tạo `lib/core/widgets/role_guard.dart`. Tích hợp kiểm tra `currentUser.role` và `activeDelegationsProvider`.
- **Bước 3.3**: Chạy test widget xác nhận pass.
- **Bước 3.4**: Bọc `RoleGuard` vào tất cả các màn hình quản trị nhạy cảm:
  - `InvoiceManagementScreen`, `CreateInvoiceScreen`, `EditInvoiceScreen` (`AppPermissions.invoiceManagement`)
  - `IssueManagementScreen` (`AppPermissions.issueManagement`)
  - `ResidentManagementScreen` (`AppPermissions.residentManagement`)
  - `LinkRequestManagementScreen` (`AppPermissions.linkRequestManagement`)
  - `ApartmentManagementScreen` (`AppPermissions.apartmentManagement`)
  - `HandbookManagementScreen` (`AppPermissions.handbookManagement`)

### Task 4: Tầng Dữ Liệu Cho Tính Năng Ủy Quyền Tạm Thời (Model, Repo, Provider)
- **Bước 4.1**: Viết unit test `test/data/models/role_delegation_model_test.dart` kiểm tra parse JSON, format ngày, trạng thái `isActive`, `isExpired`.
- **Bước 4.2**: Tạo `lib/data/models/role_delegation_model.dart`.
- **Bước 4.3**: Bổ sung các phương thức vào `ManagementRepository`:
  - `fetchDelegations()`: Lấy danh sách ủy quyền kèm thông tin người nhận và người tạo.
  - `createDelegation(delegateId, role, startsAt, endsAt, note)`: Tạo ủy quyền mới.
  - `revokeDelegation(delegationId)`: Hủy ủy quyền trước hạn (cập nhật `ends_at = now()`).
- **Bước 4.4**: Tạo `lib/data/providers/role_delegation_provider.dart`:
  - `activeDelegationsProvider`: Lấy danh sách các role đang được ủy quyền hợp lệ cho `currentUser` tại thời điểm hiện tại (`DateTime.now()`), kèm cơ chế làm mới định kỳ mỗi 60s.
  - `delegationsListProvider`: Cho Admin quản lý.

### Task 5: Giao Diện Quản Lý Ủy Quyền Cho Admin (`RoleDelegationScreen`)
- **Bước 5.1**: Tạo `lib/features/management/screens/role_delegation_screen.dart` (bọc `AppPermissions.roleDelegation`):
  - Hiển thị danh sách các ủy quyền: Đang hiệu lực (Xanh), Hết hạn (Xám).
  - Nút FloatingActionButton "Tạo ủy quyền mới":
    - Dialog chọn nhân viên nhận ủy quyền (dropdown danh sách staff).
    - Chọn vai trò tạm thời: Kế toán hoặc Kỹ thuật viên (chặn Admin).
    - Bộ chọn thời gian: Ngày bắt đầu và Ngày kết thúc.
    - Nhập lý do ủy quyền.
  - Thao tác "Thu hồi ủy quyền" với xác nhận Dialog.

### Task 6: Nâng Cấp `AuditTrailScreen` & Thẻ Hiệu Suất Kỹ Thuật Viên
- **Bước 6.1**: Bổ sung truy vấn `role_change_log` và `role_delegations` vào `auditTrailProvider` trong `audit_trail_screen.dart`.
- **Bước 6.2**: Thêm bộ lọc Filter Chips: Tất cả, Hóa đơn, Sự cố, Liên kết, Phân quyền & Ủy quyền.
- **Bước 6.3**: Thêm bộ lọc "Hoạt động của tôi" (`changed_by == currentUser.id`).
- **Bước 6.4**: Tạo `lib/features/management/widgets/technician_performance_card.dart` hiển thị tổng kết hiệu suất KTV (số sự cố đã giao, đã giải quyết, thời gian giải quyết trung bình). Tích hợp vào đầu màn hình `AuditTrailScreen` khi user là Admin.

### Task 7: Onboarding Dialog Theo Vai Trò Lần Đầu Đăng Nhập
- **Bước 7.1**: Tạo `lib/features/management/widgets/role_onboarding_dialog.dart`.
  - Hiển thị lời chào cá nhân hóa, màu sắc và icon theo vai trò.
  - Liệt kê các chức năng được phân quyền tương ứng.
  - Hướng dẫn liên hệ Quản trị viên khi cần nâng quyền.
- **Bước 7.2**: Tích hợp vào `ManagementHomeScreen`: Kiểm tra cờ `has_seen_onboarding_${user.id}_${user.role}` qua `SharedPreferences`. Nếu chưa xem, tự động hiển thị sau khi frame đầu tiên render (`WidgetsBinding.instance.addPostFrameCallback`).

### Task 8: Giao Diện Bảng Ma Trận Quyền Hạn (`PermissionMatrixScreen`)
- **Bước 8.1**: Tạo `lib/features/management/screens/permission_matrix_screen.dart`.
  - Đọc trực tiếp danh sách `AppPermissions.all`.
  - Dựng bảng DataTable trực quan với các cột: Nghiệp vụ | Quản trị viên | Kế toán viên | Kỹ thuật viên | Cư dân.
  - Đặt ghi chú nghiệp vụ ở chân bảng về quyền mặc định và cơ chế mở rộng qua ủy quyền tạm thời.
- **Bước 8.2**: Thêm nút mở màn hình "Bảng phân quyền" trong PopupMenu của `ManagementHomeScreen`.

### Task 9: Kiểm Thử Tự Động & Xác Minh Toàn Bộ Hệ Thống (Verification)
- **Bước 9.1**: Chạy `flutter test` đảm bảo toàn bộ unit test và widget test đều pass 100%.
- **Bước 9.2**: Chạy `dart analyze` đảm bảo 0 lỗi, 0 cảnh báo.
