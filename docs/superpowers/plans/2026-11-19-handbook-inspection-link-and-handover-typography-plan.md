# Kế Hoạch Chuẩn Hóa Typography & SnackBar - Gói 2.10 (Quản Trị Cẩm Nang, Tuần Tra/Giám Sát Hiện Trường, Duyệt Liên Kết Cư Dân & Bàn Giao Căn Hộ)

## 1. Mục tiêu & Phạm vi
- **Phạm vi**: 4 màn hình quản trị thuộc phân hệ vận hành & tuân thủ tòa nhà:
  1. `lib/features/management/screens/handbook_management_screen.dart` (12 fontSizes, 8 showSnackBar)
  2. `lib/features/management/screens/inspection_workstation_screen.dart` (12 fontSizes, 5 showSnackBar)
  3. `lib/features/management/screens/link_request_management_screen.dart` (10 fontSizes, 0 showSnackBar)
  4. `lib/features/management/screens/handover_management_screen.dart` (8 fontSizes, 1 showSnackBar)
- **Mục tiêu**:
  - Xóa sạch 100% 42 điểm `fontSize:` cứng, chuyển đổi sang Design Tokens `AppTypography` (`context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`).
  - Chuẩn hóa toàn bộ 14 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` sang `AppSnackBar.showSuccess`, `AppSnackBar.showError`, `AppSnackBar.showWarning`.
  - Không phá vỡ bất kỳ bố cục responsive hay hợp đồng dữ liệu nào.
  - Bổ sung cả 4 file vào Whitelist Module 18 trong `test/core/theme_and_color_guard_test.dart`.
  - Xác minh `flutter test` và `dart analyze lib test` đạt 0 issues.

## 2. Kế hoạch chi tiết từng file

### File 1: `handover_management_screen.dart` (8 fontSizes, 1 SnackBar)
- Dòng 178: `fontSize: 15` -> `context.bodyMedium?.copyWith(color: Colors.grey.shade600)`
- Dòng 368: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)`
- Dòng 379: `fontSize: 11, color: AppTheme.textSecondary` -> `context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 440: `fontSize: 12, fontWeight: FontWeight.w600` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: statusColor)`
- Dòng 457: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 466: `fontSize: 12` -> `context.labelSmall`
- Dòng 474: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 483: `fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500` -> `context.bodySmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w500)`
- Dòng 519-521: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showError(context, 'Lỗi tạo PDF: $e');`

### File 2: `inspection_workstation_screen.dart` (12 fontSizes, 5 SnackBars)
- Dòng 166-173: `showSnackBar` -> `AppSnackBar.showWarning(context, 'Vui lòng nhập đầy đủ chỉ số đồng hồ điện và nước thực tế tại hiện trường.');`
- Dòng 179-186: `showSnackBar` -> `AppSnackBar.showWarning(context, 'Vui lòng nhập số tiền cọc hiện đang giữ để chiết tính hoàn trả cư dân.');`
- Dòng 191-196: `showSnackBar` -> `AppSnackBar.showWarning(context, 'Vui lòng ký tên đại diện Ban Quản Lý trước khi gửi.');`
- Dòng 252-258: `showSnackBar` -> `AppSnackBar.showSuccess(context, 'Đã lưu và gửi biên bản bàn giao cho cư dân xác nhận!');`
- Dòng 263-269: `showSnackBar` -> `AppSnackBar.showError(context, 'Lỗi lưu biên bản: $e');`
- Dòng 315: `fontSize: 12, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: AppStatusColors.paid, fontWeight: FontWeight.bold)`
- Dòng 450: `fontSize: 18, fontWeight: FontWeight.bold` -> `context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 462: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 506: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 586: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 642: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppStatusColors.paid)`
- Dòng 662: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 727: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 739: `fontSize: 11` -> `context.labelSmall`
- Dòng 822: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 871: `fontSize: 12, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: AppStatusColors.paid, fontWeight: FontWeight.bold)`
- Dòng 901: `fontSize: 12, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: AppStatusColors.paid, fontWeight: FontWeight.bold)`

### File 3: `link_request_management_screen.dart` (10 fontSizes, 0 SnackBar)
- Dòng 79: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 88: `fontSize: 12, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 117: `fontSize: 12, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: isOwner ? AppTheme.primary : Colors.teal.shade800, fontWeight: FontWeight.bold)`
- Dòng 161: `fontSize: 11.5, color: Colors.brown` -> `context.labelSmall?.copyWith(color: Colors.brown)`
- Dòng 241: `fontSize: 18, fontWeight: FontWeight.bold` -> `ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 283: `fontSize: 11.5, color: Colors.brown` -> `ctx.labelSmall?.copyWith(color: Colors.brown)`
- Dòng 340: `fontSize: 18, fontWeight: FontWeight.bold` -> `ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 352: `fontSize: 13.5` -> `ctx.bodyMedium`
- Dòng 357: `fontSize: 13, fontWeight: FontWeight.bold` -> `ctx.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 421: `fontSize: 11` -> `context.labelSmall`

### File 4: `handbook_management_screen.dart` (12 fontSizes, 8 SnackBars)
- Dòng 137: `fontSize: 14.5, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 147: `fontSize: 12.5, fontWeight: FontWeight.w600` -> `context.bodySmall?.copyWith(fontWeight: FontWeight.w600)`
- Dòng 158: `fontSize: 10.5, color: AppTheme.primary, fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)`
- Dòng 166: `fontSize: 11, color: AppTheme.textSecondary` -> `context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 340-350: `showSnackBar` -> `AppSnackBar.showSuccess(context, isEditing ? 'Đã cập nhật đường dây nóng!' : 'Đã thêm đường dây nóng thành công!');`
- Dòng 353-359: `showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`
- Dòng 409: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 457: `fontSize: 14, color: Colors.grey.shade700, height: 1.5` -> `context.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.5)`
- Dòng 557-567: `showSnackBar` -> `AppSnackBar.showSuccess(context, isEditing ? 'Đã cập nhật nội quy!' : 'Đã thêm nội quy thành công!');`
- Dòng 570-576: `showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`
- Dòng 624: `fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
- Dòng 701: `fontSize: 12, fontWeight: FontWeight.w600, color: AppStatusColors.paid` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppStatusColors.paid)`
- Dòng 737: `fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primary)`
- Dòng 759: `fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.blue)`
- Dòng 779: `fontSize: 12, fontWeight: FontWeight.w600, color: Colors.brown` -> `context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.brown)`
- Dòng 793: `fontSize: 14, color: Colors.grey.shade700, height: 1.4` -> `context.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.4)`
- Dòng 1038-1048: `showSnackBar` -> `AppSnackBar.showSuccess(context, isEditing ? 'Đã cập nhật tiện ích!' : 'Đã thêm tiện ích thành công!');`
- Dòng 1051-1057: `showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`
- Dòng 1096-1102: `showSnackBar` -> `AppSnackBar.showSuccess(context, successMessage);`
- Dòng 1105-1111: `showSnackBar` -> `AppSnackBar.showError(context, formatErrorMessage(e));`

## 3. Whitelist & Test Verification
- Bổ sung Module 18 vào `test/core/theme_and_color_guard_test.dart`:
  - `lib/features/management/screens/handbook_management_screen.dart`
  - `lib/features/management/screens/inspection_workstation_screen.dart`
  - `lib/features/management/screens/link_request_management_screen.dart`
  - `lib/features/management/screens/handover_management_screen.dart`
- Chạy:
  - `flutter test test/core/theme_and_color_guard_test.dart`
  - `flutter test test/features/management/handbook_screens_responsive_test.dart test/features/management/inspection_workstation_screen_test.dart test/features/management/link_request_responsive_test.dart test/features/management/handover_management_responsive_test.dart test/features/management/handover_management_screen_test.dart`
  - `dart analyze lib test`

