# Kế Hoạch Triển Khai: Cải Tiến Tính Năng & UI Toàn Diện (PKA-Home)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp trải nghiệm người dùng toàn diện: dọn sạch cảnh báo linter, tích hợp thanh toán VietQR tự động, xem chi tiết thông báo, phân tích tài chính trực quan cho BQL và bộ lọc tìm kiếm hóa đơn/sự cố.

**Architecture:** Mở rộng kiến trúc Feature-first hiện có: tiện ích VietQR tại `lib/core/utils/`, màn hình thông báo tại `lib/features/resident/screens/`, nâng cấp UI reactive với Riverpod và Supabase Realtime.

**Tech Stack:** Flutter 3.x, Flutter Riverpod 2.6, Supabase Flutter, Google Fonts Inter, Material 3.

## Global Constraints
- 100% Tiếng Việt chuẩn mực, không dùng từ tiếng Anh trong ngoặc đơn.
- Dùng Material Design Icons (`Icons.*`), tuyệt đối không dùng emoji hoặc icon ngoài.
- Tuân thủ palette màu tại `lib/core/theme/app_theme.dart`.
- Responsive tự động xuống dòng và co giãn, không hardcode chiều cao cố định.

---

### Task 1: Dọn Dẹp Cảnh Báo Linter & Cập Nhật Badge BQL

**Files:**
- Modify: `lib/data/providers/resident_issue_provider.dart:24-26`
- Modify: `test/data/providers/resident_issue_provider_test.dart:4`
- Modify: `lib/features/management/screens/management_home_screen.dart:40,113-117`

- [ ] **Step 1: Xóa biến userId không dùng trong `resident_issue_provider.dart`**
- [ ] **Step 2: Xóa import thừa trong `resident_issue_provider_test.dart`**
- [ ] **Step 3: Gắn badge `linkCount` vào tab "Cư dân" trong `management_home_screen.dart`**
- [ ] **Step 4: Chạy `flutter analyze` để xác nhận cảnh báo đã giảm**

---

### Task 2: Tiện Ích VietQR Helper & Unit Test

**Files:**
- Create: `lib/core/utils/vietqr_helper.dart`
- Create: `test/core/utils/vietqr_helper_test.dart`

- [ ] **Step 1: Viết test cho VietQrHelper sinh đúng URL và tham số**
- [ ] **Step 2: Chạy test để xác nhận test fail (TDD Red)**
- [ ] **Step 3: Cài đặt code trong `lib/core/utils/vietqr_helper.dart`**
- [ ] **Step 4: Chạy test để xác nhận test pass (TDD Green)**

---

### Task 3: Tích Hợp VietQR Trong Chi Tiết Hóa Đơn Cư Dân

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`

- [ ] **Step 1: Cập nhật BottomSheet thanh toán hiển thị mã VietQR động từ `VietQrHelper`**
- [ ] **Step 2: Thêm các nút sao chép số tài khoản và cú pháp chuyển khoản bằng `Clipboard`**
- [ ] **Step 3: Kiểm tra hiển thị và thao tác chuyển khoản mượt mà**

---

### Task 4: Màn Hình Chi Tiết Thông Báo & Điều Hướng Từ Home Cư Dân

**Files:**
- Create: `lib/features/resident/screens/resident_announcement_detail_screen.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`

- [ ] **Step 1: Tạo màn hình `ResidentAnnouncementDetailScreen` với giao diện thẻ tin tức hiện đại**
- [ ] **Step 2: Gắn sự kiện `onTap` trên danh sách thông báo tại `resident_home_screen.dart` mở màn hình chi tiết**
- [ ] **Step 3: Kiểm tra hiển thị nhãn khẩn cấp và định dạng thời gian**

---

### Task 5: Làm Đẹp Trang Hồ Sơ Cư Dân

**Files:**
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`

- [ ] **Step 1: Thêm thẻ hiển thị thông tin căn hộ hiện tại của cư dân**
- [ ] **Step 2: Thêm lối tắt đổi mật khẩu và hộp thoại xác nhận khi bấm đăng xuất**
- [ ] **Step 3: Kiểm tra luồng đăng xuất an toàn**

---

### Task 6: Biểu Đồ Phân Tích Tài Chính/Nợ Đọng Tại Dashboard BQL

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`

- [ ] **Step 1: Xây dựng widget thanh phân tích tiến độ thu phí (tỷ lệ đã thu vs còn nợ)**
- [ ] **Step 2: Tích hợp vào thẻ tài chính trong tab "Tổng quan" của BQL**
- [ ] **Step 3: Kiểm tra hiển thị phần trăm và số tiền định dạng VNĐ chuẩn**

---

### Task 7: Bộ Lọc & Tìm Kiếm Hóa Đơn và Phản Ánh Cho BQL

**Files:**
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Modify: `lib/features/management/screens/issue_management_screen.dart`

- [ ] **Step 1: Thêm TextField tìm kiếm theo mã căn hộ và FilterChips trạng thái trong `invoice_management_screen.dart`**
- [ ] **Step 2: Thêm FilterChips phân loại trạng thái phản ánh trong `issue_management_screen.dart`**
- [ ] **Step 3: Kiểm tra tốc độ lọc tức thì không bị giật lag**

---

### Task 8: Kiểm Thử Toàn Diện & Đóng Gói Hoàn Thiện

**Files:**
- Test toàn bộ project

- [ ] **Step 1: Chạy `flutter analyze` xác nhận 0 errors, 0 warnings**
- [ ] **Step 2: Chạy `flutter test` toàn bộ unit tests**
- [ ] **Step 3: Tạo commit git chuẩn mực cho các tính năng nâng cấp**
