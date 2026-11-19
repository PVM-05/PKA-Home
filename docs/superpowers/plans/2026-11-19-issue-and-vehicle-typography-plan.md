# Kế Hoạch Triển Khai: Gói 2.3 - Chuẩn Hóa Typography & SnackBar Cụm Phản Ánh Sự Cố & Quản Lý Xe/Bãi Đỗ

> **Mục tiêu:** Xóa bỏ hoàn toàn 62 điểm `fontSize:` cứng và 12 lệnh gọi `ScaffoldMessenger.showSnackBar` thủ công trong 3 màn hình nghiệp vụ trọng yếu: Màn hình Tạo sự cố cư dân (`create_issue_screen.dart`), Màn hình Duyệt xe BQL (`vehicle_approval_screen.dart`), và Màn hình Quản lý bãi đỗ xe BQL (`parking_management_screen.dart`). Mở rộng CI Guardrail Whitelist để bảo vệ các màn hình này vĩnh viễn.

---

## 1. Phạm Vi & Hạng Mục Refactor

### A. Màn hình Tạo sự cố cư dân (`lib/features/resident/screens/create_issue_screen.dart`)
- **Nợ UI**: 20 điểm `fontSize:` cứng, 7 lệnh gọi `ScaffoldMessenger.showSnackBar`.
- **Nội dung chuẩn hóa**:
  - Tiêu đề section & tiêu đề form: `context.titleMedium`, `context.titleSmall`.
  - Smart Triage badge & nhãn gợi ý AI: `context.labelSmall`, `context.bodySmall`.
  - Danh sách ảnh đính kèm & hướng dẫn chụp: `context.bodySmall`, `context.labelSmall`.
  - Thay thế 7 lệnh `showSnackBar` bằng `AppSnackBar.showSuccess` và `AppSnackBar.showError`.

### B. Màn hình Duyệt xe Ban Quản Lý (`lib/features/management/screens/vehicle_approval_screen.dart`)
- **Nợ UI**: 20 điểm `fontSize:` cứng, 4 lệnh gọi `ScaffoldMessenger.showSnackBar`.
- **Nội dung chuẩn hóa**:
  - Biển số xe & thông tin loại phương tiện: `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`.
  - Căn hộ, trạng thái đăng ký, slot bãi đỗ: `context.bodySmall`, `context.labelSmall`.
  - Dialog duyệt & từ chối: `context.titleMedium`, `context.bodyMedium`.
  - Thay thế 4 lệnh `showSnackBar` bằng `AppSnackBar.showSuccess` và `AppSnackBar.showError`.

### C. Màn hình Quản lý bãi đỗ xe Ban Quản Lý (`lib/features/management/screens/parking_management_screen.dart`)
- **Nợ UI**: 22 điểm `fontSize:` cứng, 1 lệnh gọi `ScaffoldMessenger.showSnackBar`.
- **Nội dung chuẩn hóa**:
  - Tỷ lệ lấp đầy, sơ đồ vị trí đỗ, phân loại xe: `context.titleMedium`, `context.bodyMedium`, `context.labelSmall`.
  - Dialog cập nhật sức chứa & phân bổ slot: `context.titleLarge`, `context.bodySmall`.
  - Thay thế lệnh `showSnackBar` bằng `AppSnackBar.showSuccess`.

---

## 2. Quy Trình Thực Thi & Kiểm Chứng

1. **Thực thi refactor từng màn hình**:
   - Thêm `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
   - Chuyển đổi toàn bộ `fontSize:` sang context extension tokens.
   - Chuyển đổi toàn bộ `showSnackBar` sang `AppSnackBar`.
2. **Cập nhật CI Guardrail Whitelist** (`test/core/theme_and_color_guard_test.dart`):
   - Bổ sung `lib/features/resident/screens/create_issue_screen.dart`.
   - Bổ sung `lib/features/management/screens/vehicle_approval_screen.dart`.
   - Bổ sung `lib/features/management/screens/parking_management_screen.dart`.
3. **Kiểm tra & Phân tích tĩnh**:
   - `dart analyze lib test` (yêu cầu 0 issues).
   - `flutter test test/core/theme_and_color_guard_test.dart` (yêu cầu 4/4 passed).
   - `flutter test test/features/resident/create_issue_*` & `vehicle_*`.
4. **Cập nhật đồ thị tri thức & CHANGELOG**:
   - `graphify update .`.
   - Cập nhật `CHANGELOG.md`.
   - Commit trực tiếp vào `main` và push lên `origin/main`.

