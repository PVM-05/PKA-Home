# Kế Hoạch Thực Thi: Nâng Cấp Toàn Diện Wireframe & Chuẩn Hóa UI/UX

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp tài liệu `docs/wireframes.md` thành bộ tài liệu mô phỏng wireframe 10 màn hình cốt lõi đạt tiêu chuẩn báo cáo đồ án xuất sắc, đồng thời rà soát chuẩn hóa mã nguồn UI/UX theo kỹ năng `thiet-ke-giao-dien`.

**Architecture:** Tài liệu Markdown chi tiết với sơ đồ ASCII trực quan, kết hợp rà soát component Flutter (AppCard, Dark Mode, Responsive textScale).

**Tech Stack:** Markdown, ASCII Art, Flutter Material 3, Riverpod.

## Global Constraints

- 100% Tiếng Việt chuẩn mực, đúng văn phong quản lý chung cư hiện đại.
- Không dùng biểu tượng cảm xúc (emoji).
- Bám sát hệ thống Design Tokens trong `docs/theme_spec.md`.
- Duy trì 0 lỗi linter (`dart analyze`) và toàn bộ test suite tiếp tục passed.

---

### Task 1: Nâng cấp tài liệu `docs/wireframes.md` lên 10 Màn hình Cốt lõi

**Files:**
- Modify: `docs/wireframes.md`

- [x] **Step 1: Viết phần mở đầu, nguyên tắc thiết kế UI/UX và các Design Tokens (màu sắc, font Segoe UI / Inter, bo góc, khoảng cách, dark mode)**
- [x] **Step 2: Vẽ sơ đồ khối wireframe chi tiết cho 5 màn hình Cư dân đầu tiên (Đăng nhập, Trang chủ Cư dân, Chi tiết Hóa đơn & VietQR, Gửi Phản Ánh, Cẩm nang & Hotline Khẩn cấp)**
- [x] **Step 3: Vẽ sơ đồ khối wireframe chi tiết cho 5 màn hình tiếp theo (Đặt lịch Tiện ích, Đăng ký Phương tiện, Hồ sơ Cư dân & Trợ năng, Dashboard BQL, Xử lý Sự cố & Nghiệm thu BQL)**
- [x] **Step 4: Kiểm tra tính hoàn thiện và chuẩn xác của tài liệu**

---

### Task 2: Rà soát & Chuẩn hóa UI/UX trong Mã Nguồn Flutter

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`
- Modify: `lib/features/management/screens/issue_management_screen.dart`

- [x] **Step 1: Rà soát màn hình Chi tiết Hóa đơn (`resident_invoice_detail_screen.dart`) đảm bảo dùng AppCard và hiển thị VietQR QuickLink chuẩn đẹp trên cả Dark Mode**
- [x] **Step 2: Rà soát màn hình Hồ sơ Cư dân (`resident_profile_screen.dart`) đảm bảo các thẻ dùng AppCard và responsive**
- [x] **Step 3: Rà soát màn hình Xử lý Sự cố BQL (`issue_management_screen.dart`) đảm bảo các thẻ sự cố dùng AppCard**

---

### Task 3: Kiểm thử Toàn diện & Xác thực (Verification)

**Files:**
- Review: Tất cả các file đã cập nhật

- [x] **Step 1: Chạy `dart analyze` để đảm bảo 0 lỗi linter**
- [x] **Step 2: Chạy `flutter test` đảm bảo 115+ tests tiếp tục passed**
- [x] **Step 3: Commit và đẩy lên nhánh `main`**
