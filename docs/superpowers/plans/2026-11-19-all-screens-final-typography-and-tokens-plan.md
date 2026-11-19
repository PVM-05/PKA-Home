# Kế Hoạch Triển Khai Gói 2.13: Chuẩn Hóa Typography, Mã Màu Cứng & SnackBar Cho 4 Màn Hình Cuối Cùng Toàn Ứng Dụng (Cán Mốc 100% Toàn Bộ Screens Zero Debt)

> **Mục tiêu tối thượng**: Hoàn tất chuẩn hóa Typography Tokens (`AppTypography`), mã màu Design Tokens và phản hồi `AppSnackBar` cho 4 màn hình cuối cùng (`change_password_screen.dart`, `verify_otp_screen.dart`, `document_lookup_screen.dart`, `document_preview_screen.dart`). Sau gói này, **100% tất cả các màn hình (`*/screens/*.dart`) trong toàn bộ mã nguồn Vivona sẽ chính thức đạt trạng thái Zero Debt Typography & Zero Hardcoded Color**.

---

## 1. Danh Sách 4 Màn Hình & Chi Tiết Xử Lý

### 1.1 `lib/features/auth/screens/change_password_screen.dart`
- **Hiện trạng**:
  - 2 điểm `fontSize:` cứng (dòng 96: `fontSize: 14`, dòng 164: `fontSize: 16`).
  - 2 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` (dòng 39: success, dòng 49: error).
- **Chuyển đổi**:
  - Dòng 96: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Dòng 164: `style: context.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)`
  - Thay 2 SnackBars bằng `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - Import `AppTypographyExtension` và `AppSnackBar`.

### 1.2 `lib/features/auth/screens/verify_otp_screen.dart`
- **Hiện trạng**:
  - 2 điểm `fontSize:` cứng (dòng 256: `fontSize: 13`, dòng 280: `fontSize: 13`).
  - 1 lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` (dòng 71: success gửi lại OTP).
- **Chuyển đổi**:
  - Dòng 256: `style: context.bodySmall?.copyWith(color: _secondsRemaining > 0 ? AppTheme.textSecondary : AppTheme.textPrimary)`
  - Dòng 280: `style: context.labelMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Thay SnackBar bằng `AppSnackBar.showSuccess(context, 'Đã gửi lại mã OTP mới vào hòm thư của bạn.');`.
  - Import `AppTypographyExtension` và `AppSnackBar`.

### 1.3 `lib/features/document/screens/document_lookup_screen.dart`
- **Hiện trạng**:
  - 7 điểm `fontSize:` cứng (dòng 258: 16, dòng 267: 13, dòng 345: 16, dòng 354: 14, dòng 362: 12, dòng 396: 13, dòng 407: 13).
  - 11 điểm mã màu cứng `Color(0x...)` (`0xFFF0FDF4`, `0xFF15803D`, `0xFFBBF7D0`, `0xFF166534`, `0xFFFEF2F2`, `0xFFB91C1C`, `0xFF991B1B`, `0xFF7F1D1D`, `0xFF374151`, `0xFF0F172A`, `0xFF1F2937`).
- **Chuyển đổi**:
  - Dọn sạch 100% 7 điểm `fontSize:` sang `context.titleMedium`, `context.bodySmall`, `context.bodyMedium`, `context.labelSmall`.
  - Dọn sạch 100% 11 điểm mã màu cứng sang `AppTheme.success`, `AppTheme.error`, `AppTheme.textPrimary`, `AppTheme.textSecondary` và `theme.colorScheme`.
  - Import `AppTypographyExtension`.

### 1.4 `lib/features/document/screens/document_preview_screen.dart`
- **Hiện trạng**:
  - 1 điểm `fontSize:` cứng (dòng 27: `fontSize: 18`).
- **Chuyển đổi**:
  - Dòng 27: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)`
  - Import `AppTypographyExtension`.

---

## 2. Quy Trình Thực Hiện & Kiểm Tra

1. **Chỉnh sửa mã nguồn 4 màn hình** theo đúng quy tắc kiến trúc và không thay đổi logic nghiệp vụ.
2. **Cập nhật Whitelist CI Guardrail (`test/core/theme_and_color_guard_test.dart`)**:
   - Thêm Module 21 gồm 4 file trên vào whitelist.
3. **Phân tích tĩnh**: Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
4. **Kiểm thử tự động**:
   - Chạy `flutter test test/core/theme_and_color_guard_test.dart`.
   - Chạy 4 file test tương ứng: `register_and_password_responsive_test.dart`, `password_reset_screens_test.dart`, `document_lookup_screen_test.dart`, `document_preview_screen_test.dart`.
5. **Cập nhật CHANGELOG.md & Knowledge Graph**:
   - Ghi nhận Gói 2.13.
   - Chạy `graphify update .`.
6. **Git Commit & Push trực tiếp vào `main`**:
   - `git commit -m "feat(ui): can moc lich su 100% zero debt typography toan bo cac man hinh (goi 2.13)"`
   - `git push origin main`.
