# Kế Hoạch Chuẩn Hóa Typography, Colors & SnackBar - Gói 2.12 (5 Màn Hình Cư Dân Cuối Cùng: Thông Báo, Lịch Sử Thanh Toán, Sửa Phản Ánh, Bàn Giao & Liên Kết Căn Hộ)

## 1. Mục tiêu & Phạm vi
- **Phạm vi**: 5 màn hình cư dân còn lại trong `lib/features/resident/screens/`:
  1. `lib/features/resident/screens/notification_center_screen.dart` (9 fontSizes, 3 hardcoded colors, 1 showSnackBar)
  2. `lib/features/resident/screens/payment_history_screen.dart` (8 fontSizes, 1 hardcoded color, 0 showSnackBar)
  3. `lib/features/resident/screens/edit_issue_screen.dart` (8 fontSizes, 0 hardcoded color, 4 showSnackBar)
  4. `lib/features/resident/screens/resident_handover_screen.dart` (6 fontSizes, 0 hardcoded color, 0 showSnackBar)
  5. `lib/features/resident/screens/link_request_screen.dart` (6 fontSizes, 0 hardcoded color, 5 showSnackBar)
- **Mục tiêu**:
  - Xóa sạch 100% 37 điểm `fontSize:` cứng, chuyển sang Design Tokens `AppTypography` (`context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`).
  - Xóa sạch 100% 4 điểm mã màu cứng `Color(0x...)` tại `notification_center_screen.dart` và `payment_history_screen.dart`.
  - Chuẩn hóa toàn bộ 10 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` sang `AppSnackBar` (`AppSnackBar.showSuccess`, `AppSnackBar.showWarning`, `AppSnackBar.showError`).
  - **Cán Mốc Toàn Diện Lịch Sử**: 100% TẤT CẢ các màn hình (Screens) trong toàn bộ ứng dụng Vivona (cả BQL lẫn Cư dân) sạch bóng 100% nợ typography!
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 5 file trên (Module 20).
  - Đảm bảo `dart analyze lib test` đạt 0 issues và vượt qua 100% widget tests.

## 2. Kế hoạch chi tiết từng file

### File 1: `notification_center_screen.dart` (9 fontSizes, 3 colors, 1 SnackBar)
- Dòng 40: `fontSize: 18, fontWeight: FontWeight.bold` -> `context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 53: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showSuccess(context, 'Đã đánh dấu tất cả thông báo là đã đọc');`
- Dòng 99: `fontSize: 18, fontWeight: FontWeight.bold` -> `context.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)`
- Dòng 109: `fontSize: 14, color: AppTheme.textSecondary, height: 1.4` -> `context.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.4)`
- Dòng 128: `fontSize: 14, color: AppTheme.textSecondary` -> `context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
- Dòng 185: `fontSize: 13, fontWeight: ...` -> `context.bodySmall?.copyWith(...)`
- Dòng 223: `Color(0xFFE65100)` -> `AppTheme.warning`
- Dòng 230: `Color(0xFFF57C00)` -> `AppTheme.warning`
- Dòng 232: `Color(0xFF00897B)` -> `AppTheme.secondary`
- Dòng 344: `fontSize: 15, fontWeight: ...` -> `context.titleSmall?.copyWith(...)`
- Dòng 374: `fontSize: 10, fontWeight: FontWeight.bold, color: iconColor` -> `context.labelSmall?.copyWith(color: iconColor, fontWeight: FontWeight.bold)`
- Dòng 397: `fontSize: 13, height: 1.4` -> `context.bodySmall?.copyWith(...)`
- Dòng 410: `fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500` -> `context.labelSmall?.copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.w500)`

### File 2: `payment_history_screen.dart` (8 fontSizes, 1 color, 0 SnackBar)
- Dòng 56: `isDark ? const Color(0xFF1E293B) : Colors.white` -> `Theme.of(context).cardColor`
- Dòng 160: `fontSize: 13, fontWeight: ...` -> `context.bodySmall?.copyWith(...)`
- Dòng 209: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 215: `fontSize: 12, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 232: `fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)`
- Dòng 249: `fontSize: 16, fontWeight: FontWeight.w900` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.w900)`
- Dòng 265: `fontSize: 12, fontWeight: FontWeight.bold, color: ...` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: ...)`
- Dòng 300: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 305: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`

### File 3: `edit_issue_screen.dart` (8 fontSizes, 0 color, 4 SnackBars)
- Dòng 101, 191: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showWarning(context, ...)`
- Dòng 222: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showSuccess(context, 'Cập nhật phản ánh thành công!');`
- Dòng 232: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`
- Dòng 141: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 282: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 294: `fontSize: 12, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 356: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 380: `fontSize: 12, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: ...)`
- Dòng 394: `fontSize: 12, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 512: `fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600` -> `context.labelSmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600)`
- Dòng 553: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`

### File 4: `resident_handover_screen.dart` (6 fontSizes, 0 color, 0 SnackBar)
- Dòng 60: `fontSize: 15, color: AppTheme.textSecondary` -> `context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
- Dòng 147: `fontSize: 12, fontWeight: FontWeight.w600, color: statusColor` -> `context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600)`
- Dòng 164: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 173: `fontSize: 12` -> `context.labelSmall`
- Dòng 183: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 204: `fontSize: 13, fontWeight: FontWeight.bold` -> `context.bodySmall?.copyWith(color: item.isPendingResident ? AppTheme.warning : AppTheme.primary, fontWeight: FontWeight.bold)`

### File 5: `link_request_screen.dart` (6 fontSizes, 0 color, 5 SnackBars)
- Dòng 32: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showWarning(context, validationError);`
- Dòng 47: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showSuccess(context, 'Đã gửi yêu cầu liên kết thành công!');`
- Dòng 59: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`
- Dòng 187: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showSuccess(context, 'Đã hủy yêu cầu liên kết căn hộ.');`
- Dòng 196: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));`
- Dòng 255: `fontSize: 20, fontWeight: FontWeight.bold` -> `context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 292: `fontSize: 13, color: AppTheme.warningText` -> `context.bodySmall?.copyWith(color: AppTheme.warningText)`
- Dòng 310: `fontSize: 12, color: AppTheme.warningText` -> `context.labelSmall?.copyWith(color: AppTheme.warningText)`
- Dòng 546: `fontSize: 13, color: AppTheme.error` -> `context.bodySmall?.copyWith(color: AppTheme.error)`
- Dòng 564: `fontSize: 12, color: AppTheme.error` -> `context.labelSmall?.copyWith(color: AppTheme.error)`
- Dòng 630: `fontSize: 12, color: AppTheme.textSecondary` -> `context.labelSmall?.copyWith(color: AppTheme.textSecondary)`

## 3. Whitelist Module 20 & Xác Minh Kiểm Thử
- Bổ sung Module 20 vào `test/core/theme_and_color_guard_test.dart`:
  - `lib/features/resident/screens/notification_center_screen.dart`
  - `lib/features/resident/screens/payment_history_screen.dart`
  - `lib/features/resident/screens/edit_issue_screen.dart`
  - `lib/features/resident/screens/resident_handover_screen.dart`
  - `lib/features/resident/screens/link_request_screen.dart`
- Chạy:
  - `flutter test test/core/theme_and_color_guard_test.dart`
  - `flutter test test/features/resident/notification_center_screen_test.dart test/features/resident/payment_history_screen_test.dart test/features/resident/edit_issue_responsive_test.dart test/features/resident/resident_handover_responsive_test.dart test/features/resident/resident_handover_screen_test.dart test/features/resident/link_request_cancel_test.dart test/features/resident/link_request_fallback_test.dart`
  - `dart analyze lib test`

