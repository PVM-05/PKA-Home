# Tài Liệu Thiết Kế: Đồng Bộ Toàn Diện Giao Diện Theo Wireframe (PKA-Home)

- **Ngày tạo:** 2026-09-30
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity Agent & Developer

---

## 1. Mục Tiêu & Bối Cảnh

Tài liệu [`docs/wireframes.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/wireframes.md) là đặc tả chuẩn mực cho bố cục và nhãn từ của 4 màn hình cốt lõi trong hệ thống. Đợt cải tiến này hoàn tất đồng bộ 100% cho 3 màn hình còn lại:
1. **Màn hình Đăng nhập (Section 1)**: Đặt lại vị trí "Quên mật khẩu? Vui lòng liên hệ Ban quản lý" dưới nút Đăng nhập, dùng `AppCard` và chuẩn hóa tiêu đề.
2. **Màn hình Gửi Phản Ánh Cư Dân (Section 3)**: Chuẩn hóa tiêu đề "Gửi Phản Ánh", văn bản hướng dẫn "Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:", gợi ý "Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...", và nút "GỬI YÊU CẦU".
3. **Trang chủ Ban Quản Lý (Section 4)**: Cập nhật tiêu đề "TỔNG QUAN TRẠNG THÁI", "PHẢN ÁNH CẦN XỬ LÝ GẤP", dùng `AppCard` cho sự cố khẩn cấp, bổ sung nút Đăng xuất nhanh trên AppBar BQL.

---

## 2. Ràng Buộc Kỹ Thuật (Constraints)

- **Ngôn ngữ**: 100% Tiếng Việt chuẩn mực, đúng ngữ pháp và theo sát tài liệu wireframe.
- **Biểu tượng**: `Icons.*` Material Design mặc định.
- **Giao diện & Theme**: Tương thích Dark Mode / Light Mode thông qua `AppCard` và `Theme.of(context)`.
- **Chất lượng**: 0 cảnh báo linter (`dart analyze`), 100% test case pass (`flutter test`).

---

## 3. Thiết Kế Chi Tiết

### 3.1. Màn hình Đăng nhập (`login_screen.dart`)
- **Khung Form**: Thay `Card` bằng `AppCard` với bo góc chuẩn `AppTheme.radiusLg`.
- **Tiêu đề**: "PKA Home - Ứng Dụng Quản Lý Chung Cư".
- **Dòng Quên mật khẩu**: Đặt ngay dưới nút Đăng nhập theo đúng Wireframe:
  ```dart
  TextButton(
    onPressed: _showForgotPasswordDialog,
    child: const Text('Quên mật khẩu? Vui lòng liên hệ Ban quản lý'),
  )
  ```

### 3.2. Màn hình Gửi Phản Ánh (`create_issue_screen.dart`)
- **AppBar Title**: "Gửi Phản Ánh".
- **Nhãn hướng dẫn**: "Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:".
- **Hint Text**: "Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...".
- **Khung đính kèm ảnh**: Nút/Khung chọn ảnh ghi rõ `Đính kèm hình ảnh (Tối đa 3 ảnh):` và `[ + Chọn ảnh từ máy ]`. Thích ứng Dark Mode bằng `Theme.of(context).cardColor`.
- **Nút gửi**: In hoa trang trọng **`GỬI YÊU CẦU`**.

### 3.3. Trang chủ Ban Quản Lý (`management_home_screen.dart`)
- **AppBar BQL**: Thêm nút `IconButton(icon: Icon(Icons.logout_outlined), tooltip: 'Đăng xuất')` mở hộp thoại xác nhận đăng xuất.
- **Mục Sự cố khẩn cấp**: Đổi tiêu đề thành **"Phản ánh cần xử lý gấp"** (`PHẢN ÁNH CẦN XỬ LÝ GẤP`).
- **Thẻ Sự cố khẩn cấp**: Chuyển sang `AppCard` với viền đỏ cảnh báo thích ứng theme, kèm nút `[ Xem ngay ]`.
- **Mục Thống kê**: Đổi tiêu đề thành **"Tổng quan trạng thái"** (`TỔNG QUAN TRẠNG THÁI`).
- **Thẻ Thống kê Tỷ lệ Đã thanh toán**: Hiển thị tỷ lệ thu phí `%` (ví dụ `85%`) chuẩn theo wireframe.

---

## 4. Kế Hoạch Kiểm Thử (Test Plan)

1. **Widget Test (`test/features/auth/login_screen_wireframe_test.dart`)**:
   - Kiểm tra "Quên mật khẩu? Vui lòng liên hệ Ban quản lý".
   - Kiểm tra tiêu đề "Ứng Dụng Quản Lý Chung Cư".
2. **Widget Test (`test/features/resident/create_issue_wireframe_test.dart`)**:
   - Kiểm tra tiêu đề "Gửi Phản Ánh" và nút "GỬI YÊU CẦU".
   - Kiểm tra hint text "Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...".
3. **Widget Test (`test/features/management/management_home_wireframe_test.dart`)**:
   - Kiểm tra tiêu đề "Phản ánh cần xử lý gấp" và "Tổng quan trạng thái".
   - Kiểm tra nút Đăng xuất trên AppBar BQL.
4. **Kiểm thử Linter (`dart analyze`)** và **Chạy toàn bộ `flutter test`**.
