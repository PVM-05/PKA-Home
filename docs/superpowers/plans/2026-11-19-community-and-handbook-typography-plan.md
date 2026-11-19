# Kế Hoạch Triển Khai Gói 2.7: Chuẩn Hóa Typography & SnackBar Phân Hệ Bảng Tin Cộng Đồng & Sổ Tay Cư Dân

> **Mục tiêu**: Loại bỏ 100% 51 điểm `fontSize:` cứng và 6 lệnh gọi `ScaffoldMessenger.showSnackBar` thủ công tại 3 màn hình nghiệp vụ Bảng tin cộng đồng, Trao đổi cư dân & Sổ tay hướng dẫn tòa nhà, đồng thời bổ sung cả 3 màn hình vào Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`).

---

## 1. Phạm Vi Triển Khai

| STT | Màn hình | Đường dẫn tệp | Nợ `fontSize:` | Lệnh gọi `ScaffoldMessenger` | Nghiệp vụ chính |
| :---: | :--- | :--- | :---: | :---: | :--- |
| 1 | **Quản Trị Bảng Tin Cộng Đồng** | `lib/features/management/screens/community_management_screen.dart` | 19 | 0 | Kiểm duyệt bài viết, ghim bài cộng đồng, xử lý báo cáo vi phạm tiêu chuẩn văn minh |
| 2 | **Bảng Tin & Tương Tác Cư Dân** | `lib/features/resident/screens/resident_community_screen.dart` | 17 | 4 | Đăng tin trao đổi đồ cũ, tìm bạn thể thao, hỏi đáp láng giềng, bình luận & tương tác |
| 3 | **Cẩm Nang & Sổ Tay Cư Dân** | `lib/features/resident/screens/resident_handbook_screen.dart` | 15 | 2 | Quy chế tòa nhà, số điện thoại khẩn cấp (Hotline/Công an/Bảo vệ), sơ đồ thoát hiểm, hướng dẫn dịch vụ |

---

## 2. Tiêu Chuẩn Kỹ Thuật Áp Dụng

1. **Typography**:
   - `fontSize: 20/18` $\rightarrow$ `context.titleLarge` / `context.titleMedium`
   - `fontSize: 16/15` $\rightarrow$ `context.titleSmall` / `context.bodyLarge`
   - `fontSize: 14/13` $\rightarrow$ `context.bodyMedium`
   - `fontSize: 12/11` $\rightarrow$ `context.labelMedium` / `context.bodySmall`
   - `fontSize: 10` $\rightarrow$ `context.labelSmall`
2. **Thông Báo (SnackBar)**:
   - Sử dụng `AppSnackBar.showSuccess(context, ...)` khi đăng bài, sao chép hotline, gửi bình luận thành công.
   - Sử dụng `AppSnackBar.showError(context, ...)` khi gặp lỗi kết nối hoặc thao tác thất bại.
   - Sử dụng `AppSnackBar.showWarning(context, ...)` khi vi phạm điều khoản hoặc thiếu thông tin.
3. **Guardrail CI**:
   - Bổ sung cả 3 file vào Whitelist Module 15 của `test/core/theme_and_color_guard_test.dart`.
   - Chạy kiểm thử xác nhận 4/4 tests pass và `dart analyze lib test` 0 issues.

---

## 3. Các Bước Thực Hiện

1. **Bước 1**: Chuẩn hóa `community_management_screen.dart` (19 fontSizes, 0 showSnackBar).
2. **Bước 2**: Chuẩn hóa `resident_community_screen.dart` (17 fontSizes, 4 showSnackBar).
3. **Bước 3**: Chuẩn hóa `resident_handbook_screen.dart` (15 fontSizes, 2 showSnackBar).
4. **Bước 4**: Mở rộng Whitelist `test/core/theme_and_color_guard_test.dart` (Module 15) và chạy kiểm thử guardrail & widget tests.
5. **Bước 5**: Chạy `dart analyze lib test` xác minh toàn diện dự án đạt 0 issues.
6. **Bước 6**: Cập nhật `CHANGELOG.md`, chạy `graphify update .`, commit trực tiếp vào `main` và push lên `origin/main`.

