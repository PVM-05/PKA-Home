# Kế Hoạch Triển Khai Gói 2.16: Chuẩn Hóa Typography, Mã Màu Cứng & Tokens Cho 7 Resident Widgets Còn Lại (Cán Mốc 100% Zero Debt Toàn Bộ Phân Hệ Resident)

> **Mục tiêu**: Hoàn tất chuẩn hóa Design Tokens Typography (`AppTypography`), mã màu Design Tokens và phản hồi `AppSnackBar` cho toàn bộ 7 widgets/dialogs/sheets còn lại của phân hệ Cư dân (`lib/features/resident/widgets/`):
> 1. `amenity_qr_code_dialog.dart` (6 fontSizes)
> 2. `amenity_receipt_bottom_sheet.dart` (4 fontSizes, 1 Color(0x...), 2 SnackBars)
> 3. `create_petition_sheet.dart` (3 fontSizes, 3 SnackBars)
> 4. `create_visitor_pass_sheet.dart` (4 fontSizes, 1 SnackBar)
> 5. `notification_card.dart` (3 fontSizes)
> 6. `reschedule_booking_bottom_sheet.dart` (7 fontSizes, 4 SnackBars)
> 7. `visitor_pass_qr_sheet.dart` (5 fontSizes, 1 SnackBar)
> 
> **KẾT QUẢ ĐẠT ĐƯỢC**: Cán mốc lịch sử **100% Zero Debt Typography** cho TOÀN BỘ phân hệ Resident (`lib/features/resident/`, bao gồm tất cả screens và widgets), cùng với phân hệ Auth đã đạt 100% và toàn bộ screens trong toàn ứng dụng.

---

## 1. Danh Sách 7 Tệp & Kế Hoạch Chi Tiết

### 1.1 `lib/features/resident/widgets/amenity_qr_code_dialog.dart`
- Dọn sạch 6 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.titleMedium`, `context.labelSmall`.
- Thay `Colors.green` bằng `AppTheme.success`.
- Import `app_typography.dart`.

### 1.2 `lib/features/resident/widgets/amenity_receipt_bottom_sheet.dart`
- Dọn sạch 4 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.titleMedium`.
- Thay `Color(0xFFF9FAFB)` bằng `AppTheme.background`.
- Chuẩn hóa 2 SnackBar sang `AppSnackBar.showSuccess`.
- Import `app_typography.dart`, `app_snack_bar.dart`.

### 1.3 `lib/features/resident/widgets/create_petition_sheet.dart`
- Dọn sạch 3 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.labelLarge`.
- Chuẩn hóa 3 SnackBar sang `AppSnackBar.showError`, `AppSnackBar.showSuccess`.
- Import `app_typography.dart`, `app_snack_bar.dart`, `error_formatter.dart`.

### 1.4 `lib/features/resident/widgets/create_visitor_pass_sheet.dart`
- Dọn sạch 4 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.titleMedium`, `context.labelLarge`.
- Chuẩn hóa SnackBar sang `AppSnackBar.showError`.
- Import `app_typography.dart`, `app_snack_bar.dart`, `error_formatter.dart`.

### 1.5 `lib/features/resident/widgets/notification_card.dart`
- Dọn sạch 3 điểm `fontSize:` sang `context.titleMedium`, `context.bodySmall`, `context.bodyMedium`.
- Import `app_theme.dart`, `app_typography.dart`.

### 1.6 `lib/features/resident/widgets/reschedule_booking_bottom_sheet.dart`
- Dọn sạch 7 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.labelSmall`, `context.titleMedium`.
- Chuẩn hóa 4 SnackBar sang `AppSnackBar.showWarning`, `AppSnackBar.showSuccess`, `AppSnackBar.showError`.
- Import `app_typography.dart`, `app_snack_bar.dart`.

### 1.7 `lib/features/resident/widgets/visitor_pass_qr_sheet.dart`
- Dọn sạch 5 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.titleMedium`, `context.bodyMedium`.
- Chuẩn hóa SnackBar sang `AppSnackBar.showSuccess`.
- Import `app_typography.dart`, `app_snack_bar.dart`.

---

## 2. Quy Trình Thực Hiện & Kiểm Tra

1. Chỉnh sửa mã nguồn 7 files theo chuẩn Clean Architecture & Design Tokens.
2. Thêm Module 24 vào Whitelist trong `test/core/theme_and_color_guard_test.dart`.
3. Chạy `dart analyze lib test` đảm bảo 0 issues.
4. Chạy toàn bộ test suites liên quan:
   - `test/core/theme_and_color_guard_test.dart`
   - `test/features/resident/amenity_reschedule_test.dart`
5. Cập nhật `CHANGELOG.md` & `graphify update .`.
6. Commit & Push trực tiếp vào `main`.

