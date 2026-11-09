# Phân Hệ Phương Tiện & Bãi Đỗ Xe Impeccable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Phương Tiện & Bãi Đỗ Xe (`VehicleManagementScreen`, `VehicleApprovalScreen`, `ParkingManagementScreen`) theo tiêu chuẩn thiết kế `pbakaus/impeccable`, cam đoan chống tràn bố cục 100% (**Anti-RenderFlex Guarantee**) trên cả Mobile cực hẹp (320dp x 600dp, Text zoom 1.3x) và Web Enterprise Desktop ($\ge 900$dp, `maxWidth: 1400`).

**Architecture:** Áp dụng Feature-First kiến trúc Flutter, bọc `LayoutBuilder` cho các widget co giãn linh hoạt, xây dựng Executive KPI Dashboard cho BQL trên Web Desktop, chuyển đổi Thẻ Hạn Mức sang Adaptive Quota Card, và thiết kế Split-Screen 2 cột cho Cư dân trên Web Desktop. Quản lý trạng thái qua Riverpod `vehicleProvider` và `parkingProvider`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, GoRouter, GoogleFonts / AppTheme, Flutter Test.

## Global Constraints

- **Toàn bộ commit trực tiếp vào nhánh `main`**: Tuyệt đối không tạo nhánh phụ hay worktree ngoài `main`.
- **Anti-RenderFlex Guarantee**: 0 lỗi `RenderFlex overflowed` trên mọi độ phân giải từ 320dp x 600dp (kèm text scale 1.3x) đến Desktop 1920dp x 1080dp.
- **Tiêu chuẩn B2B SaaS**: 100% tiếng Việt chuẩn mực, không hardcode mã màu, sử dụng `AppTheme` và `AppCard`.
- **Chất lượng mã nguồn**: 0 lỗi / 0 cảnh báo khi chạy `dart analyze lib test`.

---

### Task 1: Nâng cấp `VehicleManagementScreen` Responsive Đa Nền Tảng (Mobile 320dp & Desktop 2 Cột)

**Files:**
- Modify: `lib/features/resident/screens/vehicle_management_screen.dart`
- Create: `test/features/resident/vehicle_management_responsive_test.dart`

**Interfaces:**
- Consumes: `residentApartmentIdProvider`, `apartmentVehiclesProvider`, `apartmentVehicleCountsProvider`, `parkingSlotsProvider`, `vehicleRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces: `VehicleManagementScreen` thích ứng:
  - Mobile (< 900dp): Thẻ hạn mức chuyển sang khối xếp dọc khi width < 380dp, các nhãn trạng thái và biển số bọc `Flexible` & `FittedBox`.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1200`): Bố cục Split-Screen 2 cột (Cột trái 38%: Hạn mức & Quy chế bãi đỗ; Cột phải 62%: Danh sách xe & Slot ô đỗ).

- [x] **Step 1: Viết test kiểm tra Responsive cho `VehicleManagementScreen`**
  Tạo `test/features/resident/vehicle_management_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Thẻ hạn mức và Danh sách xe không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render bố cục Split-Screen 2 cột hoàn chỉnh.
- [x] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/resident/vehicle_management_responsive_test.dart`.
- [x] **Step 3: Cập nhật `VehicleManagementScreen` với kiến trúc Responsive Impeccable**
  - Cải tiến Thẻ hạn mức căn hộ dùng `LayoutBuilder` (xếp dọc khi width < 360dp, text bọc `Flexible` & `FittedBox`).
  - Tái cấu trúc thẻ xe: Header làm phẳng với icon 36x36, biển số, badge trạng thái và nút thao tác bọc gọn; bọc `brandModel` với `Expanded(Flexible)` chống tràn; hiển thị vị trí ô đỗ và ảnh cà vẹt trong `Wrap`.
  - Cải tiến `build` với Split-Screen 2 cột trên Desktop $\ge 900$dp (`maxWidth: 1200`) và dải hướng dẫn quy chế bãi xe.
- [x] **Step 4: Chạy kiểm thử toàn bộ test của resident vehicle**
  Chạy `flutter test test/features/resident/*vehicle*` đảm bảo pass 100%.
- [x] **Step 5: Commit thay đổi Task 1 vào `main`**
  `git commit -m "feat(resident): nang cap giao dien quan ly phuong tien responsive split-screen va mobile"`

---

### Task 2: Nâng cấp `VehicleApprovalScreen` Responsive Web Workstation & Mobile

**Files:**
- Modify: `lib/features/management/screens/vehicle_approval_screen.dart`
- Create: `test/features/management/vehicle_approval_responsive_test.dart`

**Interfaces:**
- Consumes: `pendingVehiclesCountProvider`, `allVehiclesProvider`, `parkingSlotsProvider`, `vehicleRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces: `VehicleApprovalScreen` thích ứng:
  - Mobile (< 900dp): Thẻ yêu cầu bọc `Flexible` cho căn hộ và biển số, nút Từ chối & Duyệt bọc `FittedBox`.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Executive Vehicle KPI Bar + Bố cục lưới danh sách 2 cột.

- [x] **Step 1: Viết test kiểm tra Responsive cho `VehicleApprovalScreen`**
  Tạo `test/features/management/vehicle_approval_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render an toàn cả 4 tabs không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Executive Vehicle KPI Bar và danh sách lưới 2 cột.
- [x] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/management/vehicle_approval_responsive_test.dart`.
- [x] **Step 3: Cập nhật `VehicleApprovalScreen` với kiến trúc Responsive Impeccable**
  - Header thẻ phiếu: Bọc căn hộ, biển số và badge trạng thái trong `Flexible` & `TextOverflow.ellipsis`.
  - Nút Từ chối và Phê duyệt: Bọc nhãn văn bản trong `FittedBox(fit: BoxFit.scaleDown)`.
  - Thêm `_buildExecutiveKpiBar` và bố cục lưới 2 cột trên Desktop $\ge 900$dp.
- [x] **Step 4: Chạy kiểm thử toàn bộ test của vehicle approval**
  Chạy `flutter test test/features/management/vehicle_approval*` đảm bảo pass 100%.
- [x] **Step 5: Commit thay đổi Task 2 vào `main`**
  `git commit -m "feat(management): nang cap duyet phuong tien responsive web workstation va mobile"`

---

### Task 3: Nâng cấp `ParkingManagementScreen` Sơ Đồ Ô Đỗ & Trạm Soát Vé

**Files:**
- Modify: `lib/features/management/screens/parking_management_screen.dart`
- Create: `test/features/management/parking_management_responsive_test.dart`

**Interfaces:**
- Consumes: `parkingCapacityStatsProvider`, `parkingSlotsProvider`, `activeVisitorTicketsProvider`, `parkingRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces: `ParkingManagementScreen` thích ứng:
  - Dải KPI sức chứa bọc cuộn ngang mượt mà, không vỡ layout trên 320dp zoom 1.3x.
  - Lưới ô đỗ co giãn số cột động theo kích thước màn hình.
  - Trạm soát vé cổng hỗ trợ cuộn ngang bảng vé vãng lai.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Bố cục căn giữa trang nhã, không dãn biên.

- [ ] **Step 1: Viết test kiểm tra Responsive cho `ParkingManagementScreen`**
  Tạo `test/features/management/parking_management_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Sơ đồ ô đỗ và Trạm soát vé không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Sơ đồ ô đỗ và Trạm soát vé cân đối.
- [ ] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/management/parking_management_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `ParkingManagementScreen` với kiến trúc Responsive Impeccable**
  - Bọc dải KPI sức chứa trong cuộn ngang hoặc `Wrap`.
  - Điều chỉnh `crossAxisCount` và `childAspectRatio` của GridView ô đỗ theo chiều rộng.
  - Bọc bảng soát vé vãng lai trong `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
  - Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 1400))`.
- [ ] **Step 4: Chạy kiểm thử toàn bộ test của parking management**
  Chạy `flutter test test/features/management/screens/parking_management_screen_test.dart` và test responsive mới.
- [ ] **Step 5: Commit thay đổi Task 3 vào `main`**
  `git commit -m "feat(management): nang cap quan ly bai do xe va so do o do responsive"`

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống

**Files:**
- Verify: Toàn bộ codebase `lib/` và `test/`
- Update: Knowledge Graph qua `graphify update .`

- [ ] **Step 1: Chạy toàn bộ test suite của phân hệ Phương Tiện & Bãi Đỗ Xe**
  Chạy `flutter test test/features/resident/*vehicle* test/features/management/vehicle* test/features/management/*parking*` đảm bảo 100% test pass.
- [ ] **Step 2: Chạy static analysis toàn dự án**
  Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- [ ] **Step 3: Cập nhật Knowledge Graph**
  Chạy `graphify update .` đồng bộ kiến trúc dự án.
- [ ] **Step 4: Commit tài liệu hoàn thành và tri thức hệ thống vào `main`**
  `git commit -m "docs: hoan thanh cai tien giao dien phan he phuong tien va bai do xe theo chuan impeccable"`
