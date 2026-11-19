# Kế Hoạch Triển Khai Gói 2.5: Chuẩn Hóa Typography & SnackBar Phân Hệ Tiền Sảnh, Khách Thăm & Bàn Giao

> **Mục tiêu**: Loại bỏ 100% 60 điểm `fontSize:` cứng và 9 lệnh gọi `ScaffoldMessenger.showSnackBar` thủ công tại 3 màn hình nghiệp vụ Lễ tân - Tiền sảnh & Cư dân, đồng thời bổ sung cả 3 màn hình vào Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`).

---

## 1. Phạm Vi Triển Khai

| STT | Màn hình | Đường dẫn tệp | Nợ `fontSize:` | Lệnh gọi `ScaffoldMessenger` | Nghiệp vụ chính |
| :---: | :--- | :--- | :---: | :---: | :--- |
| 1 | **Bàn Làm Việc Lễ Tân** | `lib/features/management/screens/front_desk_workstation_screen.dart` | 20 | 3 | Quầy tiếp đón BQL: check-in khách thăm, tiếp nhận bưu kiện giao đến, cấp thẻ ra vào |
| 2 | **Khách Thăm & Bưu Kiện Cư Dân** | `lib/features/resident/screens/resident_visitor_parcel_screen.dart` | 20 | 1 | Cư dân đăng ký trước khách đến chơi, nhận mã QR khách thăm, theo dõi bưu kiện chờ nhận |
| 3 | **Chi Tiết Bàn Giao Căn Hộ** | `lib/features/resident/screens/resident_handover_detail_screen.dart` | 20 | 5 | Biên bản nghiệm thu bàn giao căn hộ, checklist hạng mục, ký xác nhận, ghi nhận khiếm khuyết |

---

## 2. Tiêu Chuẩn Kỹ Thuật Áp Dụng

1. **Typography**:
   - `fontSize: 20/18` $\rightarrow$ `context.titleLarge` / `context.titleMedium`
   - `fontSize: 16/15` $\rightarrow$ `context.titleSmall` / `context.bodyLarge`
   - `fontSize: 14/13` $\rightarrow$ `context.bodyMedium`
   - `fontSize: 12/11` $\rightarrow$ `context.labelMedium` / `context.bodySmall`
   - `fontSize: 10` $\rightarrow$ `context.labelSmall`
2. **Thông Báo (SnackBar)**:
   - Sử dụng `AppSnackBar.showSuccess(context, ...)` khi check-in, ký nhận, sao chép mã QR thành công.
   - Sử dụng `AppSnackBar.showError(context, ...)` khi có lỗi kết nối hoặc thao tác thất bại.
   - Sử dụng `AppSnackBar.showWarning(context, ...)` khi thiếu trường thông tin bắt buộc.
3. **Guardrail CI**:
   - Bổ sung cả 3 file vào Whitelist Module 13 của `test/core/theme_and_color_guard_test.dart`.
   - Chạy kiểm thử xác nhận 4/4 tests pass và `dart analyze` 0 issues.

---

## 3. Các Bước Thực Hiện

1. **Bước 1**: Chuẩn hóa `front_desk_workstation_screen.dart` (20 fontSizes, 3 showSnackBar).
2. **Bước 2**: Chuẩn hóa `resident_visitor_parcel_screen.dart` (20 fontSizes, 1 showSnackBar).
3. **Bước 3**: Chuẩn hóa `resident_handover_detail_screen.dart` (20 fontSizes, 5 showSnackBar).
4. **Bước 4**: Mở rộng Whitelist `test/core/theme_and_color_guard_test.dart` và chạy kiểm thử guardrail.
5. **Bước 5**: Chạy `dart analyze lib test` đảm bảo 0 warning/error.
6. **Bước 6**: Cập nhật `CHANGELOG.md`, chạy `graphify update .`, commit trực tiếp vào `main` và push lên `origin/main`.

