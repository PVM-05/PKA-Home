# Phân Hệ Điện Nước & Chỉ Số Tiện Ích Impeccable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Điện Nước & Chỉ Số Tiện Ích (`ManagementMeterReadingScreen` & `ResidentMeterReadingScreen`) theo tiêu chuẩn thiết kế `pbakaus/impeccable`, cam đoan chống tràn bố cục 100% (**Anti-RenderFlex Guarantee**) trên cả Mobile cực hẹp (320dp x 600dp, Text zoom 1.3x) và Web Enterprise Desktop ($\ge 900$dp, `maxWidth: 1400`).

**Architecture:** Áp dụng Feature-First kiến trúc Flutter, bọc `LayoutBuilder` cho các widget co giãn linh hoạt, xây dựng Executive KPI Dashboard cho Ban Quản Lý trên Web Desktop, chuyển đổi Hộp thoại chốt số thành Adaptive Dialog thích ứng màn hình hẹp, và thiết kế Split-Screen 2 cột cho Cư dân trên Web Desktop. Quản lý trạng thái qua Riverpod `meterReadingProvider`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, GoRouter, GoogleFonts / AppTheme, Flutter Test.

## Global Constraints

- **Toàn bộ commit trực tiếp vào nhánh `main`**: Tuyệt đối không tạo nhánh phụ hay worktree ngoài `main`.
- **Anti-RenderFlex Guarantee**: 0 lỗi `RenderFlex overflowed` trên mọi độ phân giải từ 320dp x 600dp (kèm text scale 1.3x) đến Desktop 1920dp x 1080dp.
- **Tiêu chuẩn B2B SaaS**: 100% tiếng Việt chuẩn mực, không hardcode mã màu, sử dụng `AppTheme` và `AppCard`.
- **Chất lượng mã nguồn**: 0 lỗi / 0 cảnh báo khi chạy `dart analyze lib test`.

---

### Task 1: Nâng cấp `ManagementMeterReadingScreen` Responsive Đa Nền Tảng & Adaptive Batch Dialog

**Files:**
- Modify: `lib/features/management/screens/management_meter_reading_screen.dart`
- Create: `test/features/management/management_meter_reading_responsive_test.dart`

**Interfaces:**
- Consumes: `allMeterReadingsProvider`, `anomalyMeterReadingsProvider`, `pendingMeterReadingsCountProvider`, `pendingAnomalyCountProvider`, `buildingUtilityRatesProvider`, `meterReadingRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces: `ManagementMeterReadingScreen` thích ứng:
  - Mobile (< 900dp): Thẻ phiếu (`_buildSubmissionCard`) bọc `FittedBox` trên nút bấm, tiêu đề bọc `Flexible`, các khối Điện/Nước thích ứng, không tràn trên 320dp zoom 1.3x.
  - Adaptive Batch Dialog: Thích ứng tự động: nếu width < 600dp, hiển thị các khối thẻ dọc cho từng căn; nếu width $\ge 600$dp, hiển thị bảng ngang.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Executive Utility KPI Bar (Chờ duyệt, Bất thường AI, Đã duyệt, Tỷ lệ hoàn thành) + Danh sách lưới 2 cột.

- [x] **Step 1: Viết test kiểm tra Responsive cho `ManagementMeterReadingScreen`**
  Tạo `test/features/management/management_meter_reading_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render cả 4 tabs không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render Executive KPI Bar và bố cục lưới 2 cột.
- [x] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/management/management_meter_reading_responsive_test.dart`.
- [x] **Step 3: Cập nhật `ManagementMeterReadingScreen` với kiến trúc Responsive Impeccable**
  - Sửa `_showBatchRecordDialog`: Dialog dùng `Builder` + `MediaQuery.sizeOf(context)` để hiển thị dạng khối thẻ dọc khi chiều rộng $< 500$dp, và bảng ngang khi $\ge 500$dp.
  - Sửa `_buildSubmissionCard`: Bọc nhãn nút trong `FittedBox(fit: BoxFit.scaleDown, child: Text(...))`, tiêu đề và huy hiệu bọc `Flexible` & `ConstrainedBox`.
  - Sửa `build`:
    - Thêm `_buildExecutiveKpiBar` trên Desktop ($\ge 900$dp).
    - Thêm bố cục lưới 2 cột trên Desktop cho danh sách phiếu.
- [x] **Step 4: Chạy kiểm thử toàn bộ test của management meter reading**
  Chạy `flutter test test/features/management/management_meter_reading*` đảm bảo cả test chức năng lẫn responsive pass 100%.
- [x] **Step 5: Commit thay đổi Task 1 vào `main`**
  `git commit -m "feat(management): nang cap quan ly chi so dien nuoc responsive web workstation va mobile"`

---

### Task 2: Nâng cấp `ResidentMeterReadingScreen` Responsive Đa Nền Tảng (Mobile 320dp & Desktop 2 Cột)

**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Create: `test/features/resident/resident_meter_reading_responsive_test.dart`

**Interfaces:**
- Consumes: `currentApartmentReadingsProvider`, `residentMeterReadingsProvider`, `meterReadingRepositoryProvider`, `AppTheme`, `AppCard`.
- Produces: `ResidentMeterReadingScreen` thích ứng:
  - Mobile (< 900dp): Bỏ `height: 50` cứng ở nút gửi, bọc thẻ đính kèm và nút bấm với `Flexible` & `FittedBox`.
  - Desktop Web ($\ge 900$dp, `maxWidth: 1200`): Split-Screen 2 cột (Cột trái: Chỉ số kỳ trước + Lịch sử khai báo; Cột phải: Form khai báo & OCR Scanner).

- [x] **Step 1: Viết test kiểm tra Responsive cho `ResidentMeterReadingScreen`**
  Tạo `test/features/resident/resident_meter_reading_responsive_test.dart`:
  - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Form và Lịch sử không có lỗi RenderFlex.
  - Test 2: Desktop 1200dp render bố cục Split-Screen 2 cột hoàn chỉnh.
- [x] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/resident/resident_meter_reading_responsive_test.dart`.
- [x] **Step 3: Cập nhật `ResidentMeterReadingScreen` với kiến trúc Responsive Impeccable**
  - Sửa nút gửi: Dùng `ConstrainedBox(constraints: BoxConstraints(minHeight: 48))` thay vì cố định `height: 50`.
  - Sửa thẻ ảnh công tơ: Bọc tên file trong `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`.
  - Tách header thẻ công tơ điện nước trong `Wrap` thành 3 phần tử con độc lập tránh tràn 320dp.
  - Sửa `build`: Thêm bố cục Split-Screen 2 cột khi `maxWidth >= 900`.
- [x] **Step 4: Chạy kiểm thử toàn bộ test của resident meter reading**
  Chạy `flutter test test/features/resident/*meter*` đảm bảo pass 100%.
- [x] **Step 5: Commit thay đổi Task 2 vào `main`**
  `git commit -m "feat(resident): nang cap khai bao chi so dien nuoc responsive split-screen va mobile"`

---

### Task 3: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống

**Files:**
- Verify: Toàn bộ codebase `lib/` và `test/`
- Update: Knowledge Graph qua `graphify update .`

- [x] **Step 1: Chạy toàn bộ test suite của phân hệ Điện Nước**
  Chạy `flutter test test/features/management/*meter* test/features/resident/*meter* test/features/meter_reading/` đảm bảo 100% test pass.
- [x] **Step 2: Chạy static analysis toàn dự án**
  Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- [x] **Step 3: Cập nhật Knowledge Graph**
  Chạy `graphify update .` đồng bộ kiến trúc dự án.
- [x] **Step 4: Commit tài liệu hoàn thành và tri thức hệ thống vào `main`**
  `git commit -m "docs: hoan thanh cai tien giao dien phan he dien nuoc theo chuan impeccable"`

