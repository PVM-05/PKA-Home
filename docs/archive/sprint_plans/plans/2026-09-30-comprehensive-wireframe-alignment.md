# Kế Hoạch Thực Thi: Đồng Bộ Toàn Diện Giao Diện Theo Wireframe

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện 100% giao diện và câu chữ của 3 màn hình còn lại (Đăng nhập, Gửi Phản Ánh, Dashboard BQL) theo đúng tài liệu wireframes.md, chuẩn hóa AppCard và Dark Mode.

**Architecture:** Sử dụng kiến trúc Feature-first, áp dụng `AppCard` cho các khối card, Riverpod để đọc dữ liệu và StateNotifier để đăng xuất.

**Tech Stack:** Flutter, Flutter Riverpod, Material Design 3.

## Global Constraints

- 100% Tiếng Việt chuẩn mực, không dùng tiếng Anh giải nghĩa trong ngoặc đơn.
- Dùng Icon từ thư viện `Icons.*` của Flutter Material Design.
- Thích ứng hoàn hảo Dark Mode/Light Mode thông qua `AppCard` và `Theme.of(context)`.
- Áp dụng TDD: Viết test trước, code sau, đảm bảo 0 lỗi linter và 100% test pass.

---

### Task 1: Màn hình Đăng nhập (Section 1) - Viết Widget Test & Cập nhật UI

**Files:**
- Create: `test/features/auth/login_screen_wireframe_test.dart`
- Modify: `lib/features/auth/screens/login_screen.dart`

- [ ] **Step 1: Viết failing test kiểm tra tiêu đề "Ứng Dụng Quản Lý Chung Cư" và dòng "Quên mật khẩu? Vui lòng liên hệ Ban quản lý" dưới nút Đăng nhập**
- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**
- [ ] **Step 3: Chuyển Card sang AppCard, cập nhật tiêu đề và chuyển dòng Quên mật khẩu xuống dưới nút Đăng nhập**
- [ ] **Step 4: Chạy lại test để xác nhận test chuyển sang Green**

---

### Task 2: Màn hình Gửi Phản Ánh (Section 3) - Viết Widget Test & Cập nhật UI

**Files:**
- Create: `test/features/resident/create_issue_wireframe_test.dart`
- Modify: `lib/features/resident/screens/create_issue_screen.dart`

- [ ] **Step 1: Viết failing test kiểm tra tiêu đề "Gửi Phản Ánh", câu gợi ý "Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:", hint "Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...", và nút "GỬI YÊU CẦU"**
- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**
- [ ] **Step 3: Cập nhật AppBar title, label, hint text, và button text thành "GỬI YÊU CẦU", tối ưu màu Dark Mode cho khung chọn ảnh**
- [ ] **Step 4: Chạy lại test để xác nhận test chuyển sang Green**

---

### Task 3: Trang chủ Ban Quản Lý (Section 4) - Viết Widget Test & Cập nhật UI

**Files:**
- Create: `test/features/management/management_home_wireframe_test.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`

- [ ] **Step 1: Viết failing test kiểm tra tiêu đề "Phản ánh cần xử lý gấp", "Tổng quan trạng thái", và nút Đăng xuất trên AppBar BQL**
- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**
- [ ] **Step 3: Cập nhật tiêu đề thành "Phản ánh cần xử lý gấp", "Tổng quan trạng thái", chuyển các thẻ sự cố khẩn cấp sang AppCard, và thêm nút Đăng xuất trên AppBar BQL**
- [ ] **Step 4: Chạy lại test để xác nhận test chuyển sang Green**

---

### Task 4: Kiểm thử Toàn diện & Xác thực (Verification)

**Files:**
- Review: Tất cả các file đã chỉnh sửa

- [ ] **Step 1: Chạy `dart analyze` để đảm bảo 0 lỗi linter**
- [ ] **Step 2: Chạy `flutter test` đảm bảo toàn bộ bộ test suite passed**
- [ ] **Step 3: Commit và đẩy lên nhánh `main`**
