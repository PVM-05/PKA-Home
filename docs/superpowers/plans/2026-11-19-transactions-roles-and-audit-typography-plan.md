# Kế Hoạch Chuẩn Hóa Typography & Tokens - Gói 2.11 (Giao Dịch Thanh Toán, Ủy Quyền Vai Trò, Ma Trận Phân Quyền & Nhật Ký Kiểm Toán)

## 1. Mục tiêu & Phạm vi
- **Phạm vi**: 4 màn hình quản trị cuối cùng của phân hệ `management/screens/`:
  1. `lib/features/management/screens/management_payment_transactions_screen.dart` (7 fontSizes)
  2. `lib/features/management/screens/role_delegation_screen.dart` (6 fontSizes, 1 showSnackBar)
  3. `lib/features/management/screens/permission_matrix_screen.dart` (5 fontSizes)
  4. `lib/features/management/screens/audit_trail_screen.dart` (4 fontSizes)
- **Mục tiêu**:
  - Xóa sạch 100% 22 điểm `fontSize:` cứng, chuyển đổi sang Design Tokens `AppTypography` (`context.titleLarge`, `context.titleSmall`, `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`).
  - Chuẩn hóa lệnh gọi `ScaffoldMessenger.of(context).showSnackBar` trong `role_delegation_screen.dart` sang `AppSnackBar.showWarning`.
  - **Cán mốc lịch sử**: Đưa toàn bộ thư mục `lib/features/management/screens/` (100% màn hình BQL) đạt chuẩn **Zero Typography Debt**!
  - Bổ sung cả 4 file vào Whitelist Module 19 trong `test/core/theme_and_color_guard_test.dart`.
  - Đảm bảo `dart analyze lib test` đạt 0 issues và vượt qua toàn bộ test suite.

## 2. Kế hoạch chi tiết từng file

### File 1: `management_payment_transactions_screen.dart` (7 fontSizes)
- Dòng 40: `fontSize: 18, fontWeight: FontWeight.bold` -> `ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold)` (gỡ `const` khỏi `Row` ở dòng 33)
- Dòng 101: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 108: `fontSize: 13, fontWeight: FontWeight.bold, color: ...` -> `context.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: ...)`
- Dòng 238: `fontSize: 14, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 245: `fontSize: 12, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 260: `fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
- Dòng 281: `fontSize: 10, color: _getStatusColor(tx), fontWeight: FontWeight.bold` -> `context.labelSmall?.copyWith(color: _getStatusColor(tx), fontWeight: FontWeight.bold)`

### File 2: `role_delegation_screen.dart` (6 fontSizes, 1 showSnackBar)
- Dòng 38-45: `ScaffoldMessenger.of(context).showSnackBar` -> `AppSnackBar.showWarning(context, ...)`
- Dòng 175: `fontSize: 12, fontWeight: FontWeight.bold, color: roleColor` -> `context.labelSmall?.copyWith(color: roleColor, fontWeight: FontWeight.bold)`
- Dòng 201: `fontSize: 12, fontWeight: FontWeight.bold, color: statusColor` -> `context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)`
- Dòng 225: `fontSize: 16, fontWeight: FontWeight.bold` -> `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 233: `fontSize: 13, color: AppTheme.textSecondary` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 248: `fontSize: 13` -> `context.bodySmall`
- Dòng 265: `fontSize: 12, fontStyle: FontStyle.italic` -> `context.labelSmall?.copyWith(fontStyle: FontStyle.italic)`

### File 3: `permission_matrix_screen.dart` (5 fontSizes)
- Dòng 63: `fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
- Dòng 71: `fontSize: 12, color: AppTheme.textSecondary, height: 1.3` -> `context.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.3)`
- Dòng 171: `fontSize: 13, fontWeight: FontWeight.bold` -> `context.bodySmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 180: `fontSize: 11, color: AppTheme.textSecondary` -> `context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
- Dòng 228: `fontSize: 12, color: Colors.amber.shade900, height: 1.4, fontWeight: FontWeight.w500` -> `context.bodySmall?.copyWith(color: Colors.amber.shade900, height: 1.4, fontWeight: FontWeight.w500)`

### File 4: `audit_trail_screen.dart` (4 fontSizes)
- Dòng 348: `fontSize: 13, fontWeight: ...` -> `context.bodySmall?.copyWith(...)`
- Dòng 448: `fontSize: 15, fontWeight: FontWeight.bold` -> `context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
- Dòng 464: `fontSize: 12, color: log.color` -> `context.labelSmall?.copyWith(color: log.color)`
- Dòng 493: `fontSize: 13, fontWeight: ...` -> `context.bodySmall?.copyWith(...)`

## 3. Whitelist Module 19 & Kiểm thử
- Thêm Module 19 vào `test/core/theme_and_color_guard_test.dart`.
- Chạy toàn bộ test suites và kiểm tra tĩnh `dart analyze lib test`.

