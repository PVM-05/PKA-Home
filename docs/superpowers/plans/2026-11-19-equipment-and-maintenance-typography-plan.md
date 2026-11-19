# Kế Hoạch Triển Khai Gói 2.6: Chuẩn Hóa Typography & SnackBar Phân Hệ Kỹ Thuật, Thiết Bị & Bảo Trì

> **Mục tiêu**: Loại bỏ 100% 52 điểm `fontSize:` cứng và 8 lệnh gọi `ScaffoldMessenger.showSnackBar` thủ công tại 3 màn hình nghiệp vụ Kỹ thuật, Quản lý thiết bị tòa nhà & Vật tư bảo dưỡng, đồng thời bổ sung cả 3 màn hình vào Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`).

---

## 1. Phạm Vi Triển Khai

| STT | Màn hình | Đường dẫn tệp | Nợ `fontSize:` | Lệnh gọi `ScaffoldMessenger` | Nghiệp vụ chính |
| :---: | :--- | :--- | :---: | :---: | :--- |
| 1 | **Chi Tiết Trang Thiết Bị** | `lib/features/management/screens/equipment_detail_screen.dart` | 21 | 6 | Hồ sơ thiết bị kỹ thuật (thang máy, máy bơm, máy phát điện, PCCC), lịch sử bảo trì định kỳ, ghi nhận sửa chữa & QR code |
| 2 | **Quản Lý Trang Thiết Bị** | `lib/features/management/screens/equipment_management_screen.dart` | 16 | 2 | Danh mục thiết bị tòa nhà, bộ lọc vị trí/phân loại/trạng thái vận hành, cảnh báo đến hạn bảo trì |
| 3 | **Quản Lý Vật Tư Bảo Dưỡng** | `lib/features/management/screens/maintenance_materials_screen.dart` | 15 | 0 | Kho phụ tùng thay thế & vật tư kỹ thuật, cảnh báo tồn kho tối thiểu, lịch sử xuất/nhập kho cho sự cố |

---

## 2. Tiêu Chuẩn Kỹ Thuật Áp Dụng

1. **Typography**:
   - `fontSize: 20/18` $\rightarrow$ `context.titleLarge` / `context.titleMedium`
   - `fontSize: 16/15` $\rightarrow$ `context.titleSmall` / `context.bodyLarge`
   - `fontSize: 14/13` $\rightarrow$ `context.bodyMedium`
   - `fontSize: 12/11` $\rightarrow$ `context.labelMedium` / `context.bodySmall`
   - `fontSize: 10` $\rightarrow$ `context.labelSmall`
2. **Thông Báo (SnackBar)**:
   - Sử dụng `AppSnackBar.showSuccess(context, ...)` khi lưu thiết bị, cập nhật bảo trì, xuất QR code thành công.
   - Sử dụng `AppSnackBar.showError(context, ...)` khi gặp lỗi hoặc không tìm thấy thiết bị.
   - Sử dụng `AppSnackBar.showWarning(context, ...)` khi cảnh báo đến hạn kiểm định hoặc thiếu vật tư.
3. **Guardrail CI**:
   - Bổ sung cả 3 file vào Whitelist Module 14 của `test/core/theme_and_color_guard_test.dart`.
   - Chạy kiểm thử xác nhận 4/4 tests pass và `dart analyze lib test` 0 issues.

---

## 3. Các Bước Thực Hiện

1. **Bước 1**: Chuẩn hóa `equipment_detail_screen.dart` (21 fontSizes, 6 showSnackBar).
2. **Bước 2**: Chuẩn hóa `equipment_management_screen.dart` (16 fontSizes, 2 showSnackBar).
3. **Bước 3**: Chuẩn hóa `maintenance_materials_screen.dart` (15 fontSizes, 0 showSnackBar).
4. **Bước 4**: Mở rộng Whitelist `test/core/theme_and_color_guard_test.dart` (Module 14) và chạy kiểm thử guardrail & widget tests.
5. **Bước 5**: Chạy `dart analyze lib test` xác minh toàn diện dự án đạt 0 issues.
6. **Bước 6**: Cập nhật `CHANGELOG.md`, chạy `graphify update .`, commit trực tiếp vào `main` và push lên `origin/main`.

