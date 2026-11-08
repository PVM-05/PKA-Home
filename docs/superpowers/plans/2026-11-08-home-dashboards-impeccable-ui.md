# Kế Hoạch Triển Khai: Nâng Cấp Giao Diện Bộ Đôi Trang Chủ Cốt Lõi (Resident Home & Management Executive Dashboard)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện `ResidentHomeScreen` và `ManagementHomeScreen` theo tiêu chuẩn Impeccable Taste và cam đoan chống tràn bố cục 100% (Anti-RenderFlex Guarantee) từ Mobile 320dp (Text Zoom 1.3x) đến Desktop Enterprise $\ge 900$dp.

**Architecture:** Áp dụng Clean Architecture và Feature-First. Sử dụng `LayoutBuilder` để xây dựng bố cục thích ứng đa cột trên Desktop ($\ge 900$dp, maxWidth 1400dp) và cuộn linh hoạt với cơ chế tự động xếp dọc (Fluid Auto-Wrap) trên Mobile hẹp (< 380dp). Tất cả giá trị tiền tệ và chỉ số lớn bọc `FittedBox`, nhãn văn bản bọc `Expanded`/`Flexible`.

**Tech Stack:** Flutter, Material 3, Riverpod, GoRouter, Inti, FlChart, FlutterAnimate.

**Trạng thái:** [x] HOÀN TẤT 100% (3/3 Tasks Nghiệm Thu, 0 Warning, 0 RenderFlex Error).

## Global Constraints
- Toàn bộ commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- 100% tiếng Việt chuẩn mực SaaS B2B, không dịch thô thuật ngữ quốc tế quen thuộc (Hotline, VietQR, App).
- Đạt 0 issue khi chạy `dart analyze lib test`.
- Cam kết 0 lỗi RenderFlex overflowed trên màn hình 320dp x 600dp với font scale 1.3x.

---

## Danh Sách Nhiệm Vụ

### [x] Task 1: Nâng cấp `ResidentHomeScreen` (Trang Chủ Cư Dân)
- **Tệp chỉnh sửa:** `lib/features/resident/screens/resident_home_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_home_responsive_test.dart`
- **Kết quả:**
  - [x] **Bước 1.1:** Viết test suite `resident_home_responsive_test.dart` kiểm tra hiển thị responsive ở Desktop Web (1200dp x 800dp), Mobile chuẩn (390dp x 844dp) và Mobile hẹp (320dp x 600dp với Text Scale 1.3x).
  - [x] **Bước 1.2:** Chạy test để ghi nhận trạng thái ban đầu.
  - [x] **Bước 1.3:** Tối ưu header chào mừng: chống tràn text tên cư dân, hỗ trợ vùng bấm biểu tượng chuẩn tiếp cận $\ge 40$dp.
  - [x] **Bước 1.4:** Tối ưu khối tổng quan hóa đơn: bọc số tiền trong `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` và nút "THANH TOÁN NGAY" chuẩn viền mờ.
  - [x] **Bước 1.5:** Tối ưu dải thao tác nhanh (4 nút): bọc text nhãn trong `FittedBox` nhẹ và kiểm soát kích thước icon container.
  - [x] **Bước 1.6:** Tối ưu khối Dịch vụ & Tiện ích: dùng `LayoutBuilder` tự động xếp dọc 1 cột khi chiều rộng $< 380$dp; khi $\ge 380$dp hiển thị dạng lưới 2 cột.
  - [x] **Bước 1.7:** Xây dựng bố cục 2 cột trên Desktop ($\ge 900$dp, `maxWidth: 1400`):
    - Cột trái (60%): Chào mừng + Hóa đơn VietQR + Thao tác nhanh + Dịch vụ tiện ích.
    - Cột phải (40%): Cảnh báo gián đoạn + Quỹ bảo trì + Phản ánh gần nhất + Thông báo bảng tin.
  - [x] **Bước 1.8:** Chạy lại test `resident_home_responsive_test.dart` xác nhận pass toàn bộ (4/4 tests passed).
  - [x] **Bước 1.9:** Đã commit: `a3e7475` `feat(resident): nang cap resident home screen responsive da cot va chong tran bo cuc`.

---

### [x] Task 2: Nâng cấp `ManagementHomeScreen` (Executive Dashboard BQL)
- **Tệp chỉnh sửa:** `lib/features/management/screens/management_home_screen.dart`
- **Tệp kiểm thử:** `test/features/management/management_home_responsive_test.dart`
- **Kết quả:**
  - [x] **Bước 2.1:** Viết test suite `management_home_responsive_test.dart` kiểm tra hiển thị responsive ở Desktop Web Executive Workstation (1400dp x 900dp) và Mobile hẹp (320dp x 600dp với Text Scale 1.3x).
  - [x] **Bước 2.2:** Chạy test để ghi nhận trạng thái ban đầu.
  - [x] **Bước 2.3:** Tối ưu `AppBar`: trên Mobile hẹp (< 600dp), gom nút đăng xuất ngoài vào menu an toàn, giới hạn chiều rộng `BuildingSwitcherDropdown` tối đa 135dp không đè lên tiêu đề.
  - [x] **Bước 2.4:** Tối ưu dải thẻ chỉ số `StatCard`: dùng `LayoutBuilder` tính toán `childAspectRatio` thích ứng (`0.98` trên mobile hẹp để tăng chiều cao), bọc giá trị số trong `FittedBox`.
  - [x] **Bước 2.5:** Tối ưu khối Công việc cần xử lý ngay: thẻ sự cố khẩn cấp và hóa đơn chờ duyệt dùng widget `_buildUrgentCard` tự động xếp nút hành động xuống dưới tiêu đề khi bề rộng $< 360$dp.
  - [x] **Bước 2.6:** Xây dựng bố cục Desktop Executive Command Center ($\ge 900$dp, `maxWidth: 1400`):
    - Cột trái (65%): Dải KPI tổng quan + Công việc cần xử lý ngay + Biểu đồ doanh thu & Tiến độ thu phí + Vận hành kỹ thuật.
    - Cột phải (35%): Lối tắt nghiệp vụ BQL (Quick Action Workstation) + Quỹ bảo trì + Giao dịch thanh toán gần nhất.
  - [x] **Bước 2.7:** Chạy lại test `management_home_responsive_test.dart` xác nhận pass toàn bộ (3/3 tests passed).
  - [x] **Bước 2.8:** Đã commit: `e942d09` `feat(management): nang cap management executive dashboard responsive web va mobile`.

---

### [x] Task 3: Quality Gate & Full Verification
- **Lệnh thực thi:**
  - [x] **Bước 3.1:** Chạy `dart analyze lib test` -> **No issues found!** (0 warning, 0 error).
  - [x] **Bước 3.2:** Chạy toàn bộ các test responsive của Trang chủ và các màn hình liên quan -> 100% test suites passed.
  - [x] **Bước 3.3:** Chạy `graphify update .` đồng bộ AST knowledge graph.
  - [x] **Bước 3.4:** Cập nhật tài liệu kế hoạch và báo cáo nghiệm thu hoàn tất.
