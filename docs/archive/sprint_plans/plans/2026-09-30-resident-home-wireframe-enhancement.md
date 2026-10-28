# Kế Hoạch Thực Thi: Cải Tiến Giao Diện Trang Chủ Cư Dân Theo Wireframe

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện giao diện Trang chủ Cư dân khớp với tài liệu wireframes.md, bao gồm thẻ Tổng quan hóa đơn đầy đủ thông tin & nút Thanh toán ngay, nút Đăng xuất nhanh trên Header, và chuẩn hóa AppCard thích ứng Dark Mode.

**Architecture:** Sử dụng kiến trúc Feature-first, dùng Riverpod lắng nghe dữ liệu từ `residentInvoiceProvider` và `authProvider`. Sử dụng `AppCard` cho các thẻ thông tin và kích hoạt chuyển tab mượt mà.

**Tech Stack:** Flutter, Flutter Riverpod, Material 3, fl_chart, timeago.

## Global Constraints

- 100% Tiếng Việt chuẩn mực trong giao diện và thông báo.
- Dùng Icon từ thư viện `Icons.*` của Flutter Material Design.
- Màu sắc và theme thông qua `Theme.of(context)` và `AppTheme`, tuyệt đối không hardcode màu sắc.
- Kiểm thử tự động với TDD trước khi hoàn tất.

---

### Task 1: Viết Widget Test cho tính năng Tổng quan Hóa đơn & Nút Đăng xuất theo Wireframe

**Files:**
- Create: `test/features/resident/resident_home_wireframe_test.dart`

- [ ] **Step 1: Viết test kịch bản kiểm tra thẻ Hóa đơn hiển thị số lượng hóa đơn chưa đóng, nút THANH TOÁN NGAY và nút Đăng xuất**
- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**
- [ ] **Step 3: Ghi nhận kết quả**

---

### Task 2: Cải tiến Thẻ Tổng quan Hóa đơn trên ResidentHomeScreen

**Files:**
- Modify: `lib/features/resident/screens/resident_home_screen.dart`

- [ ] **Step 1: Thay thế thẻ Card hardcode bằng AppCard với tiêu đề "Tổng quan hóa đơn"**
- [ ] **Step 2: Hiển thị dòng chú thích số lượng hóa đơn chưa thanh toán: `( X hóa đơn chưa thanh toán )` hoặc `( Đã thanh toán đầy đủ các kỳ phí )`**
- [ ] **Step 3: Bổ sung nút bấm "THANH TOÁN NGAY" (hoặc "XEM HÓA ĐƠN") chuyển trực tiếp sang tab Hóa đơn (`_onItemTapped(1)`)**
- [ ] **Step 4: Chuyển thẻ "Tiến độ phản ánh" sang dùng AppCard**
- [ ] **Step 5: Chạy test để kiểm tra thẻ Hóa đơn đã Pass**

---

### Task 3: Bổ sung Nút Đăng xuất Nhanh trên SliverAppBar của ResidentHomeScreen

**Files:**
- Modify: `lib/features/resident/screens/resident_home_screen.dart`

- [ ] **Step 1: Bổ sung IconButton Đăng xuất (`Icons.logout_outlined`) cạnh chuông thông báo trên SliverAppBar**
- [ ] **Step 2: Hiện AlertDialog xác nhận Đăng xuất ("Bạn có chắc chắn muốn đăng xuất không?")**
- [ ] **Step 3: Chạy test để xác nhận Task 1 widget test chuyển sang Green**

---

### Task 4: Kiểm thử Toàn diện & Xác thực (Verification)

**Files:**
- Review: `lib/features/resident/screens/resident_home_screen.dart`
- Review: `test/features/resident/resident_home_wireframe_test.dart`

- [ ] **Step 1: Chạy `dart analyze` để đảm bảo 0 lỗi linter**
- [ ] **Step 2: Chạy `flutter test` đảm bảo toàn bộ bộ test suite passed**
- [ ] **Step 3: Commit và đẩy lên nhánh `main`**
