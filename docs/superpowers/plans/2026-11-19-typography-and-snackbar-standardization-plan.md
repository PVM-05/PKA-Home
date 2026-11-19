# Kế Hoạch Triển Khai Gói 2.1: Chuẩn Hóa Typography Module Thông Báo & Hệ Thống AppSnackBar

> **Mục tiêu:** Xóa bỏ 54 điểm nợ `fontSize` cứng tại module Thông báo (đứng top 2 nợ typography toàn hệ thống), đưa cả 2 màn hình vào Whitelist bảo vệ của `theme_and_color_guard_test.dart`, đồng thời thống nhất 280+ lời gọi SnackBar rời rạc về hệ thống chuẩn `AppSnackBar` & `runAction`.
> **Tiêu chuẩn:** Tuân thủ `AGENTS.md`, `coding-rules.md`, `design-rules.md`, không làm giảm độ phủ test (Zero-Regression), 100% tiếng Việt chuẩn mực.

---

## Danh Mục Công Việc Chi Tiết

### Task 1: Xây Dựng `AppSnackBar` Chuẩn Công Nghiệp & Nâng Cấp `runAction`
- **Tập tin:** `lib/core/widgets/app_snack_bar.dart` và `lib/core/utils/action_runner.dart`
- **Mục tiêu:**
  - Cung cấp 3 phương thức chuẩn:
    - `AppSnackBar.showSuccess(BuildContext context, String message)`: Nền xanh thành công `AppStatusColors.paid` / `Color(0xFF2E7D32)`, icon check tròn, floating, haptics `AppHaptics.light()`.
    - `AppSnackBar.showError(BuildContext context, dynamic error)`: Nền đỏ `AppTheme.error`, icon cảnh báo, thông điệp tự động qua `formatErrorMessage(error)`, haptics `AppHaptics.medium()`.
    - `AppSnackBar.showInfo(BuildContext context, String message)`: Nền xanh thương hiệu `AppTheme.primary`, icon thông tin.
  - Tích hợp `AppSnackBar` vào `runAction`.
- **Kiểm thử:** Viết widget test trong `test/core/widgets/app_snack_bar_test.dart`.

### Task 2: Chuẩn Hóa Typography & Design Tokens Cho `resident_announcement_detail_screen.dart`
- **Tập tin:** `lib/features/resident/screens/resident_announcement_detail_screen.dart`
- **Mục tiêu:**
  - Xóa bỏ toàn bộ 16 điểm `fontSize:` cứng.
  - Chuyển đổi sang `context.titleLarge`, `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`.
  - Thay thế `EdgeInsets` / `BorderRadius` viết tay bằng `AppSpacing` và `AppRadius`.
  - Đồng bộ SnackBar sang `AppSnackBar`.
- **Kiểm thử:** Chạy `test/features/resident/resident_announcement_detail_responsive_test.dart`.

### Task 3: Chuẩn Hóa Typography & Design Tokens Cho `announcement_management_screen.dart`
- **Tập tin:** `lib/features/management/screens/announcement_management_screen.dart`
- **Mục tiêu:**
  - Xóa bỏ toàn bộ 38 điểm `fontSize:` cứng.
  - Chuyển đổi sang `AppTypographyExtension`.
  - Đồng bộ SnackBar sang `AppSnackBar` / `runAction`.
- **Kiểm thử:** Chạy `test/features/management/announcement_management_responsive_test.dart` và `announcement_targeting_test.dart`.

### Task 4: Mở Rộng Whitelist Của Guardrail CI Test
- **Tập tin:** `test/core/theme_and_color_guard_test.dart`
- **Mục tiêu:**
  - Bổ sung 2 màn hình module Thông báo vào Whitelist:
    - `lib/features/management/screens/announcement_management_screen.dart`
    - `lib/features/resident/screens/resident_announcement_detail_screen.dart`
  - Đảm bảo `theme_and_color_guard_test.dart` chạy pass 100%.
- **Kiểm thử:** Chạy toàn bộ test suite dự án (`flutter test`).

