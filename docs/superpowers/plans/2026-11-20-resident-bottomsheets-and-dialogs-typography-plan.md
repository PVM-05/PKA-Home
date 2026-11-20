# Kế Hoạch Triển Khai Gói 2.15: Chuẩn Hóa Typography, Mã Màu Cứng & Tokens Cho Cụm Bottom Sheets & Dialogs Cư Dân (Cán Mốc 36 Điểm Nợ Về 0)

> **Mục tiêu**: Hoàn tất chuẩn hóa Design Tokens Typography (`AppTypography`), mã màu Design Tokens và phản hồi `AppSnackBar` cho 4 Bottom Sheet / Dialog cư dân trọng yếu:
> 1. `lib/features/resident/widgets/tiered_fee_breakdown_dialog.dart` (13 fontSizes, 2 Color(0x...), 4 Colors.blue)
> 2. `lib/features/resident/widgets/vote_poll_sheet.dart` (9 fontSizes, 5 ScaffoldMessenger SnackBars)
> 3. `lib/features/resident/widgets/resident_ledger_history_sheet.dart` (7 fontSizes, hardcoded Material colors)
> 4. `lib/features/resident/widgets/issue_rating_bottom_sheet.dart` (7 fontSizes, 2 ScaffoldMessenger SnackBars)

---

## 1. Danh Sách 4 Tệp & Chi Tiết Xử Lý

### 1.1 `lib/features/resident/widgets/tiered_fee_breakdown_dialog.dart`
- **Hiện trạng**:
  - 13 điểm `fontSize:` cứng.
  - 2 mã màu `Color(0x...)` tại dòng 22 (`Color(0xFF0288D1)` và `Color(0xFFE65100)`).
  - 4 điểm `Colors.blue` tại dòng 133, 135, 139, 145.
- **Chuyển đổi**:
  - Thay màu tiêu đề nước/điện bằng `AppTheme.secondary` (Sky Cyan) và `AppTheme.warning` (Amber).
  - Thay `Colors.blue` bằng `AppTheme.secondary` và `AppTheme.primary`.
  - Dọn sạch 13 điểm `fontSize:` sang `context.titleMedium`, `context.bodySmall`, `context.labelSmall`, `context.headlineSmall`, `context.labelLarge`, `context.bodyMedium`.
  - Import `AppTypographyExtension`.

### 1.2 `lib/features/resident/widgets/vote_poll_sheet.dart`
- **Hiện trạng**:
  - 9 điểm `fontSize:` cứng.
  - 5 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar`.
- **Chuyển đổi**:
  - Dọn sạch 9 điểm `fontSize:` sang `context.labelSmall`, `context.titleLarge`, `context.titleMedium`, `context.bodySmall`, `context.titleSmall`, `context.bodyMedium`, `context.labelLarge`.
  - Chuẩn hóa 5 SnackBar sang `AppSnackBar.showWarning`, `AppSnackBar.showError`, `AppSnackBar.showSuccess`.
  - Import `AppTypographyExtension`, `AppSnackBar`, `error_formatter.dart`.

### 1.3 `lib/features/resident/widgets/resident_ledger_history_sheet.dart`
- **Hiện trạng**:
  - 7 điểm `fontSize:` cứng.
  - Hardcoded Material colors (`Colors.deepOrange`, `Colors.green`, `Colors.blue`, `Colors.blueGrey`, `Colors.grey`).
- **Chuyển đổi**:
  - Dọn sạch 7 điểm `fontSize:` sang `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`.
  - Thay các màu cứng bằng `AppTheme.error`, `AppTheme.success`, `AppTheme.primary`, `AppTheme.textSecondary`.
  - Import `AppTheme` và `AppTypographyExtension`.

### 1.4 `lib/features/resident/widgets/issue_rating_bottom_sheet.dart`
- **Hiện trạng**:
  - 7 điểm `fontSize:` cứng.
  - 2 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar`.
  - Hardcoded `Colors.amber` và `Colors.grey.shade600`.
- **Chuyển đổi**:
  - Dọn sạch 7 điểm `fontSize:` sang `context.bodyMedium`, `context.bodySmall`, `context.titleLarge`, `context.titleMedium`, `context.labelLarge`.
  - Chuẩn hóa 2 SnackBar sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - Thay `Colors.amber` và `Colors.grey.shade600` bằng `AppTheme.warning` và `AppTheme.textSecondary`.
  - Import `AppTypographyExtension` và `AppSnackBar`.

---

## 2. Quy Trình Thực Hiện & Kiểm Tra

1. Chỉnh sửa mã nguồn 4 files theo chuẩn Clean Architecture và Design Tokens.
2. Thêm Module 23 vào danh sách Whitelist trong `test/core/theme_and_color_guard_test.dart`.
3. Chạy `dart analyze lib test` đảm bảo 0 issues.
4. Chạy toàn bộ test suites liên quan:
   - `test/core/theme_and_color_guard_test.dart`
   - `test/features/resident/resident_tiered_fee_ui_test.dart`
   - `test/features/resident/issue_rating_widget_test.dart`
5. Cập nhật `CHANGELOG.md` & `graphify update .`.
6. Commit & Push trực tiếp vào `main`.

