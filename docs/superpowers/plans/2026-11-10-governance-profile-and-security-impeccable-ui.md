# Kế Hoạch Triển Khai: Phân Hệ Quản Trị Hệ Thống, Hồ Sơ & Bảo Mật Impeccable UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Quản trị hệ thống, Hồ sơ cư dân & Bảo mật (`ResidentProfileScreen`, `LinkRequestManagementScreen`, `LinkRequestScreen`, `PermissionMatrixScreen`, `RoleDelegationScreen`, `MaintenanceMaterialsScreen`, `RegisterScreen`, `ChangePasswordScreen`) theo chuẩn `pbakaus/impeccable`, cam kết **Anti-RenderFlex Guarantee 100%** từ mobile 320dp x 600dp (Text Zoom 1.3x) đến Enterprise Desktop $\ge 900$dp.

**Architecture:** Áp dụng Feature-First kiến trúc Flutter, bọc `ConstrainedBox` căn giữa nội dung trên Web/Desktop, chuyển đổi toàn bộ thẻ sang `AppCard`, loại bỏ lồng ghép `Row` cứng nhắc, bảo vệ nhãn bằng `FittedBox` / `Wrap`. Quản lý trạng thái qua Riverpod.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, AppTheme / AppCard, Flutter Test.

## Global Constraints
- Toàn bộ commit trực tiếp vào nhánh `main`. Không tạo branch hoặc worktree phụ.
- 100% tiếng Việt chuẩn mực SaaS B2B, không emoji.
- Anti-RenderFlex Guarantee trên mọi kích thước.
- Đạt 0 issues trên `dart analyze lib test`.

---

### Task 1: Nâng cấp `ResidentProfileScreen` (Hồ Sơ Cư Dân)
**Files:**
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`
- Create: `test/features/resident/resident_profile_responsive_test.dart`

- [x] **Step 1: Viết test kiểm tra responsive cho `ResidentProfileScreen`**
  Tạo `test/features/resident/resident_profile_responsive_test.dart` kiểm tra 320dp x 600dp (Text scale 1.3x) và Desktop 1200dp.
- [x] **Step 2: Chạy test để xác nhận kiểm thử**
  Chạy `flutter test test/features/resident/resident_profile_responsive_test.dart`.
- [x] **Step 3: Cải tiến `ResidentProfileScreen`**
  - Bọc `Center(ConstrainedBox(maxWidth: 800))` chống giãn tràn trên Desktop.
  - Cải tiến danh sách thành viên cùng căn hộ: Bọc thông tin tên, số điện thoại và vai trò với `Wrap` / `Flexible` chống tràn.
  - Cải tiến hàng tiêu đề 'Căn hộ của bạn' và nút 'Xin liên kết' với `Wrap`.
- [x] **Step 4: Chạy test xác nhận pass 100%**
- [x] **Step 5: Commit thay đổi Task 1 vào `main`**
  `feat(resident): nang cap ho so cu dan can giua responsive va app card`

---

### Task 2: Nâng cấp `LinkRequestManagementScreen` & `LinkRequestScreen` (Liên Kết Căn Hộ)
**Files:**
- Modify: `lib/features/management/screens/link_request_management_screen.dart`
- Modify: `lib/features/resident/screens/link_request_screen.dart`
- Create: `test/features/management/link_request_responsive_test.dart`

- [x] **Step 1: Viết test kiểm tra responsive cho Link Request**
  Tạo `test/features/management/link_request_responsive_test.dart`.
- [x] **Step 2: Chạy test xác nhận**
- [x] **Step 3: Cải tiến `LinkRequestManagementScreen` & `LinkRequestScreen`**
  - Chuyển toàn bộ `Card` sang `AppCard`.
  - Thêm `Center(ConstrainedBox(maxWidth: 1000))` cho BQL.
  - Nút bấm và badge bọc `FittedBox` và `Wrap`.
- [x] **Step 4: Chạy test xác nhận pass 100%**
- [x] **Step 5: Commit thay đổi Task 2 vào `main`**
  `feat(management): nang cap quan ly yeu cau lien ket can ho responsive va app card`

---

### Task 3: Nâng cấp `PermissionMatrixScreen` & `RoleDelegationScreen` (Phân Quyền & Ủy Quyền)
**Files:**
- Modify: `lib/features/management/screens/permission_matrix_screen.dart`
- Modify: `lib/features/management/screens/role_delegation_screen.dart`
- Create: `test/features/management/governance_screens_responsive_test.dart`

- [x] **Step 1: Viết test kiểm tra responsive cho Phân quyền & Ủy quyền**
  Tạo `test/features/management/governance_screens_responsive_test.dart`.
- [x] **Step 2: Chạy test xác nhận**
- [x] **Step 3: Cải tiến `PermissionMatrixScreen` & `RoleDelegationScreen`**
  - Chuyển `Card` sang `AppCard`.
  - Thêm `Center(ConstrainedBox(maxWidth: 1200))` trên Desktop.
  - Sửa `RoleDelegationScreen`: Hàng huy hiệu vai trò bọc `Wrap` chống tràn trên 320dp.
- [x] **Step 4: Chạy test xác nhận pass 100%**
- [x] **Step 5: Commit thay đổi Task 3 vào `main`**
  `feat(management): nang cap ma tran phan quyen va uy quyen vai tro responsive`

---

### Task 4: Nâng cấp `MaintenanceMaterialsScreen` (Kho Vật Tư Kỹ Thuật)
**Files:**
- Modify: `lib/features/management/screens/maintenance_materials_screen.dart`
- Create: `test/features/management/maintenance_materials_responsive_test.dart`

- [x] **Step 1: Viết test kiểm tra responsive cho Kho Vật Tư**
  Tạo `test/features/management/maintenance_materials_responsive_test.dart`.
- [x] **Step 2: Chạy test xác nhận**
- [x] **Step 3: Cải tiến `MaintenanceMaterialsScreen`**
  - Bọc `Center(ConstrainedBox(maxWidth: 1200))`.
  - Thanh KPI Kho: Bọc `LayoutBuilder`, chuyển sang cuộn ngang khi chiều rộng $< 420$dp.
  - Thẻ vật tư: Bọc mã hàng và số lượng tồn kho với `Flexible` và `FittedBox`.
- [x] **Step 4: Chạy test xác nhận pass 100%**
- [x] **Step 5: Commit thay đổi Task 4 vào `main`**
  `feat(management): nang cap quan ly kho vat tu responsive va app card`

---

### Task 5: Nâng cấp `RegisterScreen` & `ChangePasswordScreen` (Bảo Mật & Đăng Ký)
**Files:**
- Modify: `lib/features/auth/screens/register_screen.dart`
- Modify: `lib/features/auth/screens/change_password_screen.dart`
- Create: `test/features/auth/register_and_password_responsive_test.dart`

- [x] **Step 1: Viết test kiểm tra responsive cho Đăng ký & Đổi mật khẩu**
  Tạo `test/features/auth/register_and_password_responsive_test.dart`.
- [x] **Step 2: Chạy test xác nhận**
- [x] **Step 3: Cải tiến `RegisterScreen` & `ChangePasswordScreen`**
  - Chuyển `Card` sang `AppCard`.
  - Thêm `Center(ConstrainedBox(maxWidth: 440))` cho `ChangePasswordScreen`.
  - Đảm bảo các trường nhập liệu và nút bấm co giãn an toàn trên 320dp với Text scale 1.3x.
- [x] **Step 4: Chạy test xác nhận pass 100%**
- [x] **Step 5: Commit thay đổi Task 5 vào `main`**
  `feat(auth): nang cap dang ky va doi mat khau responsive va app card`

---

### Task 6: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống
**Files:**
- Toàn bộ codebase
- Update: Knowledge graph via `graphify update .`

- [x] **Step 1: Chạy toàn bộ test suite phân hệ**
- [x] **Step 2: Chạy `dart analyze lib test` đảm bảo 0 issues**
- [x] **Step 3: Cập nhật Knowledge Graph qua `graphify update .`**
- [x] **Step 4: Commit tài liệu hoàn thành vào `main`**
