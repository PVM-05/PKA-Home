# Kế Hoạch Triển Khai Gói 2.14: Chuẩn Hóa Typography, Mã Màu Cứng & Tokens Cho Cụm Auth Widgets & Resident Identity/Safety Widgets (Cán Mốc 100% Zero Debt Toàn Bộ Phân Hệ Auth)

> **Mục tiêu**: Hoàn tất chuẩn hóa Design Tokens Typography (`AppTypography`), mã màu Design Tokens và phản hồi `AppSnackBar` cho 7 components/dialogs cốt lõi:
> 1. Toàn bộ Auth Widgets: `mfa_setup_dialog.dart`, `mfa_verification_dialog.dart`, `otp_input_boxes.dart` $\rightarrow$ **Đưa 100% phân hệ `lib/features/auth/` (cả screens và widgets) đạt mốc Zero Debt Typography**.
> 2. Các widget định danh, thanh tiện ích khẩn cấp & cảnh báo gián đoạn cư dân: `accept_invitation_dialog.dart`, `apartment_switcher_chip.dart`, `sticky_emergency_bar.dart`, `equipment_interruption_banner.dart`.

---

## 1. Danh Sách 7 Tệp & Chi Tiết Xử Lý

### 1.1 `lib/features/auth/widgets/mfa_setup_dialog.dart`
- **Hiện trạng**:
  - 6 điểm `fontSize:` cứng (dòng 113: 17, dòng 125: 13, dòng 143: 14, dòng 159: 13, dòng 167: 22, dòng 186: 12).
  - 1 mã màu cứng `Colors.red` (dòng 186).
  - 1 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` (dòng 52: copy secret).
- **Chuyển đổi**:
  - Dọn sạch 6 điểm `fontSize:` sang `context.titleMedium`, `context.bodySmall`, `context.bodyMedium`, `context.headlineSmall`, `context.labelSmall`.
  - Thay `Colors.red` bằng `AppTheme.error`.
  - Chuẩn hóa SnackBar sang `AppSnackBar.showSuccess`.
  - Import `AppTypographyExtension` và `AppSnackBar`.

### 1.2 `lib/features/auth/widgets/mfa_verification_dialog.dart`
- **Hiện trạng**:
  - 4 điểm `fontSize:` cứng (dòng 93: 18, dòng 106: 13, dòng 115: 24, dòng 152: 12).
  - 2 điểm màu cứng `Colors.red` (dòng 147 icon, dòng 152 text).
- **Chuyển đổi**:
  - Dọn sạch 4 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`, `context.headlineMedium`, `context.labelSmall`.
  - Thay `Colors.red` bằng `AppTheme.error`.
  - Import `AppTypographyExtension`.

### 1.3 `lib/features/auth/widgets/otp_input_boxes.dart`
- **Hiện trạng**:
  - 1 điểm TextStyle(fontSize: fontSize) chưa kết nối kiểu chữ Design System.
- **Chuyển đổi**:
  - Kết nối `context.titleLarge?.copyWith(fontSize: fontSize, fontWeight: FontWeight.bold)`.
  - Import `AppTypographyExtension`.

### 1.4 `lib/features/resident/widgets/accept_invitation_dialog.dart`
- **Hiện trạng**:
  - 4 điểm `fontSize:` cứng (dòng 71: 18, dòng 82: 13, dòng 100: 13, dòng 112: 13).
- **Chuyển đổi**:
  - Dọn sạch 4 điểm `fontSize:` sang `context.titleLarge`, `context.bodySmall`.
  - Import `AppTypographyExtension`.

### 1.5 `lib/features/resident/widgets/apartment_switcher_chip.dart`
- **Hiện trạng**:
  - 6 điểm `fontSize:` cứng (dòng 54: 18, dòng 64: 13, dòng 109: 12, dòng 165: 13, dòng 205: 13, dòng 238: 13).
- **Chuyển đổi**:
  - Dọn sạch 6 điểm `fontSize:` sang `context.titleLarge`, `context.labelMedium`, `context.labelSmall`.
  - Import `AppTypographyExtension`.

### 1.6 `lib/features/resident/widgets/sticky_emergency_bar.dart`
- **Hiện trạng**:
  - 4 điểm `fontSize:` cứng (dòng 77: 10.5, dòng 94: 9.5, dòng 109: 13, dòng 135: 12).
- **Chuyển đổi**:
  - Dọn sạch 4 điểm `fontSize:` sang `context.labelSmall`, `context.bodySmall`.
  - Import `AppTypographyExtension`.

### 1.7 `lib/features/resident/widgets/equipment_interruption_banner.dart`
- **Hiện trạng**:
  - 6 điểm `fontSize:` cứng (dòng 108: 14, dòng 116: 12, dòng 133: 11, dòng 169: 13, dòng 186: 11, dòng 202: 12).
  - 14 điểm mã màu cứng `Color(0x...)`.
- **Chuyển đổi**:
  - Dọn sạch 6 điểm `fontSize:` sang `context.titleSmall`, `context.labelSmall`, `context.bodySmall`.
  - Dọn sạch 14 mã màu cứng sang `AppTheme.warning`, `AppTheme.error`, `AppTheme.textPrimary`, `AppTheme.textSecondary`.
  - Import `AppTypographyExtension`.

---

## 2. Quy Trình Thực Hiện & Kiểm Tra

1. Chỉnh sửa mã nguồn 7 files theo đúng nguyên tắc Clean Architecture.
2. Cập nhật Whitelist Module 22 trong `test/core/theme_and_color_guard_test.dart`.
3. Chạy `dart analyze lib test` đảm bảo 0 issues.
4. Chạy toàn bộ test suites liên quan:
   - `test/core/theme_and_color_guard_test.dart`
   - `test/features/resident/widgets/accept_invitation_dialog_test.dart`
   - `test/features/resident/widgets/sticky_emergency_bar_test.dart`
   - `test/core/security/mfa_service_test.dart`
5. Cập nhật `CHANGELOG.md` & `graphify update .`.
6. Commit & Push trực tiếp vào `main`.
