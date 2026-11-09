# Phân Hệ Bàn Giao & Kiểm Kê Căn Hộ Impeccable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Bàn Giao Căn Hộ & Kiểm Kê Tài Sản Số Hóa (`ResidentHandoverScreen`, `ResidentHandoverDetailScreen`, `HandoverManagementScreen`, `InspectionWorkstationScreen`) theo tiêu chuẩn thiết kế `pbakaus/impeccable`, cam đoan chống tràn bố cục 100% (**Anti-RenderFlex Guarantee**) trên cả Mobile cực hẹp (320dp x 600dp, Text zoom 1.3x) và Web Enterprise Desktop ($\ge 900$dp, `maxWidth: 1400`).

**Architecture:** Áp dụng Feature-First kiến trúc Flutter, bọc `LayoutBuilder` cho các widget co giãn linh hoạt, xây dựng Executive KPI Dashboard cho Ban Quản Lý trên Web Desktop, thiết kế Split-Screen 2 cột cho Cư dân và Trạm kiểm kê BQL trên Web Desktop. Quản lý trạng thái qua Riverpod `handoverProvider`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, Printing / PDF, AppTheme / AppCard, Flutter Test.

## Global Constraints

- **Toàn bộ commit trực tiếp vào nhánh `main`**: Tuyệt đối không tạo nhánh phụ hay worktree ngoài `main`.
- **Anti-RenderFlex Guarantee**: 0 lỗi `RenderFlex overflowed` trên mọi độ phân giải từ 320dp x 600dp (kèm text scale 1.3x) đến Desktop 1920dp x 1080dp.
- **Tiêu chuẩn B2B SaaS**: 100% tiếng Việt chuẩn mực, không hardcode mã màu, sử dụng `AppTheme` và `AppCard`.
- **Chất lượng mã nguồn**: 0 lỗi / 0 cảnh báo khi chạy `dart analyze lib test`.

---

### Task 1: Nâng cấp `ResidentHandoverScreen` & `ResidentHandoverDetailScreen` (Cư Dân)

**Files:**
- Modify: `lib/features/resident/screens/resident_handover_screen.dart`
- Modify: `lib/features/resident/screens/resident_handover_detail_screen.dart`
- Create: `test/features/resident/resident_handover_responsive_test.dart`

**Interfaces:**
- Consumes: `residentHandoversProvider`, `handoverDetailProvider`, `handoverRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces:
  - `ResidentHandoverScreen` thích ứng với thẻ `AppCard` viền siêu mỏng, căn giữa `maxWidth: 1000`, header thẻ bọc `Expanded` và `ConstrainedBox` chống tràn.
  - `ResidentHandoverDetailScreen` hỗ trợ Split-Screen 2 cột trên Desktop Web $\ge 900$dp (`maxWidth: 1200`), và bố cục cuộn 1 cột an toàn tuyệt đối trên Mobile 320dp kèm Text Zoom 1.3x.

- [ ] **Step 1: Viết test kiểm tra Responsive cho phân hệ Bàn Giao Cư Dân**
  Tạo `test/features/resident/resident_handover_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Danh sách và Chi tiết không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Danh sách và Chi tiết ở bố cục Split-Screen cân đối.
- [ ] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/resident/resident_handover_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `ResidentHandoverScreen` với kiến trúc Responsive Impeccable**
  - Chuyển `Card` sang `AppCard` viền mỏng mờ, loại bỏ mã màu hardcode, căn giữa `maxWidth: 1000`.
  - Bọc mã biên bản trong `Expanded` + `ellipsis`, badge trạng thái trong `ConstrainedBox(maxWidth: 105)` + `FittedBox`.
  - Hàng thông tin căn hộ và BQL bọc `Wrap` linh hoạt.
- [ ] **Step 4: Cập nhật `ResidentHandoverDetailScreen` với kiến trúc Responsive Impeccable**
  - Mobile (< 900dp): Thẻ chỉ số điện nước, bảng chiết tính tiền cọc và danh sách tài sản bọc `FittedBox` / `Expanded`, nút khiếu nại và ký tên bọc `FittedBox`.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1200`): Bố cục Split-Screen 2 cột (Cột trái: Thông tin tổng quan, Chỉ số, Bảng cọc; Cột phải: Bảng kiểm kê chi tiết từng phòng & Tác vụ).
- [ ] **Step 5: Chạy kiểm thử toàn bộ test của resident handover**
  Chạy `flutter test test/features/resident/*handover*` đảm bảo pass 100%.
- [ ] **Step 6: Commit thay đổi Task 1 vào `main`**
  `git commit -m "feat(resident): nang cap giao dien ban giao can ho responsive split-screen va mobile"`

---

### Task 2: Nâng cấp `HandoverManagementScreen` (Ban Quản Lý)

**Files:**
- Modify: `lib/features/management/screens/handover_management_screen.dart`
- Create: `test/features/management/handover_management_responsive_test.dart`

**Interfaces:**
- Consumes: `buildingHandoversProvider`, `handoverRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces:
  - Executive Handover KPI Dashboard: Bọc `LayoutBuilder`, cuộn ngang trên Mobile < 420dp, dãn đều trên màn hình lớn.
  - Thẻ biên bản chuẩn `AppCard`, loại bỏ màu hardcode.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Bố cục lưới 2 cột hoặc Data Table Workstation căn giữa trang nhã.

- [ ] **Step 1: Viết test kiểm tra Responsive cho `HandoverManagementScreen`**
  Tạo `test/features/management/handover_management_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render an toàn không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Executive KPI Bar và danh sách lưới 2 cột.
- [ ] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/management/handover_management_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `HandoverManagementScreen` với kiến trúc Responsive Impeccable**
  - Sửa dải KPI Header: Bọc `LayoutBuilder` cuộn ngang khi width $< 420$dp.
  - Sửa thẻ biên bản: Chuyển sang `AppCard`, bọc mã biên bản trong `Expanded`, badge trạng thái bọc `ConstrainedBox(maxWidth: 105)` + `FittedBox`.
  - Bọc toàn bộ màn hình trong `Center(ConstrainedBox(maxWidth: 1400))` và hỗ trợ lưới 2 cột trên Desktop $\ge 900$dp.
- [ ] **Step 4: Chạy kiểm thử toàn bộ test của handover management**
  Chạy `flutter test test/features/management/*handover*` đảm bảo pass 100%.
- [ ] **Step 5: Commit thay đổi Task 2 vào `main`**
  `git commit -m "feat(management): nang cap quan ly bien ban ban giao responsive web workstation va mobile"`

---

### Task 3: Nâng cấp `InspectionWorkstationScreen` (Hiện Trường)

**Files:**
- Modify: `lib/features/management/screens/inspection_workstation_screen.dart`

**Interfaces:**
- Consumes: `handoverRepositoryProvider`, `SignaturePadDialog`, `AppTheme`, `AppCard`.
- Produces:
  - Mobile (< 900dp): Trường nhập chỉ số, tiền cọc và cụm chip tình trạng bọc `Wrap(spacing: 6, runSpacing: 6)`, nút chụp ảnh minh chứng co giãn an toàn.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Split-Screen Workstation 2 cột (Cột trái: Thông tin hợp đồng & Chỉ số & Cọc & Ký số; Cột phải: Bảng kiểm kê chi tiết từng phòng).

- [ ] **Step 1: Bổ sung kịch bản kiểm thử Responsive cho `InspectionWorkstationScreen` trong `handover_management_responsive_test.dart`**
  - Test kiểm tra màn hình hiện trường trên Mobile 320dp x 600dp (Text Scale 1.3x) và Desktop 1200dp.
- [ ] **Step 2: Chạy test để xác nhận lỗi tràn hiện tại**
  Chạy `flutter test test/features/management/handover_management_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `InspectionWorkstationScreen` với kiến trúc Responsive Impeccable**
  - Tách bố cục theo `isDesktop = MediaQuery.sizeOf(context).width >= 900`.
  - Cụm chip chọn tình trạng tài sản bọc `Wrap` chống ép hàng.
  - Khung chữ ký và nút lưu/gửi biên bản bọc `FittedBox`.
  - Căn giữa `maxWidth: 1400` trên Web Desktop.
- [ ] **Step 4: Chạy kiểm thử toàn bộ test của inspection workstation**
  Chạy `flutter test test/features/management/inspection_workstation*` và test responsive mới.
- [ ] **Step 5: Commit thay đổi Task 3 vào `main`**
  `git commit -m "feat(management): nang cap tram kiem ke ban giao hien truong responsive"`

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống

**Files:**
- Verify: Toàn bộ codebase `lib/` và `test/`
- Update: Knowledge Graph qua `graphify update .`

- [ ] **Step 1: Chạy toàn bộ test suite của phân hệ Bàn Giao Căn Hộ**
  Chạy `flutter test test/features/resident/*handover* test/features/management/*handover* test/data/models/*handover* test/data/repositories/handover*` đảm bảo 100% test pass.
- [ ] **Step 2: Chạy static analysis toàn dự án**
  Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- [ ] **Step 3: Cập nhật Knowledge Graph**
  Chạy `graphify update .` đồng bộ kiến trúc dự án.
- [ ] **Step 4: Commit tài liệu hoàn thành và tri thức hệ thống vào `main`**
  `git commit -m "docs: hoan thanh cai tien giao dien phan he ban giao can ho theo chuan impeccable"`
