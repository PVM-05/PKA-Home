# Kế Hoạch Triển Khai Gói 2.4: Chuẩn Hóa Typography & SnackBar Phân Hệ Tài Chính, Lập Hóa Đơn & Báo Cáo

> **Mục tiêu:** Xóa bỏ 63 điểm nợ `fontSize` cứng và 8 lệnh gọi `ScaffoldMessenger.showSnackBar` thủ công tại 3 màn hình trọng yếu thuộc phân hệ Quản lý Tài chính BQL (`CreateInvoiceScreen`, `FeePolicyManagementScreen`, `FinancialReportScreen`), đưa cả 3 màn hình vào Whitelist bảo vệ của `theme_and_color_guard_test.dart`.
> **Tiêu chuẩn:** Tuân thủ `AGENTS.md`, `coding-rules.md`, `design-rules.md`, 100% tiếng Việt chuẩn mực, Zero-Regression.

---

## Danh Mục Màn Hình & Nhiệm Vụ Chi Tiết

### Task 1: Chuẩn Hóa `lib/features/management/screens/create_invoice_screen.dart`
- **Hiện trạng:** 21 `fontSize:` cứng, 5 `ScaffoldMessenger.showSnackBar` thủ công.
- **Kế hoạch hành động:**
  - Thêm imports: `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
  - Thay thế 5 lệnh gọi `ScaffoldMessenger` bằng `AppSnackBar.showError`, `AppSnackBar.showWarning`, `AppSnackBar.showSuccess`.
  - Chuyển đổi 21 `fontSize:` sang các text style ngữ nghĩa từ `AppTypography`:
    - Tiêu đề Section (Thông tin căn hộ, Mục thu, Kỳ hóa đơn) $\rightarrow$ `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`.
    - Text chi tiết, helper, SLA $\rightarrow$ `context.bodySmall`, `context.labelSmall`.
    - Tổng tiền hóa đơn $\rightarrow$ `context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`.
- **Kiểm thử:** Chạy `flutter test test/features/management/create_invoice_vehicle_billing_test.dart` và `dart analyze lib/features/management/screens/create_invoice_screen.dart`.

---

### Task 2: Chuẩn Hóa `lib/features/management/screens/fee_policy_management_screen.dart`
- **Hiện trạng:** 22 `fontSize:` cứng, 0 `ScaffoldMessenger`.
- **Kế hoạch hành động:**
  - Thêm import: `import '../../../core/theme/app_typography.dart';`.
  - Chuyển đổi 22 `fontSize:` sang Design Tokens:
    - Tiêu đề thẻ chính sách biểu phí $\rightarrow$ `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`.
    - Đơn giá / Định mức lũy tiến $\rightarrow$ `context.bodyMedium`, `context.labelSmall`.
    - Phụ đề giải thích, ngày áp dụng $\rightarrow$ `context.labelSmall?.copyWith(color: AppTheme.textSecondary)`.
- **Kiểm thử:** `dart analyze lib/features/management/screens/fee_policy_management_screen.dart`.

---

### Task 3: Chuẩn Hóa `lib/features/management/screens/financial_report_screen.dart`
- **Hiện trạng:** 20 `fontSize:` cứng, 3 `ScaffoldMessenger.showSnackBar` thủ công.
- **Kế hoạch hành động:**
  - Thêm imports: `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
  - Thay thế 3 lệnh gọi `ScaffoldMessenger` (xuất Excel thành công/lỗi/cảnh báo) bằng `AppSnackBar.showSuccess`, `AppSnackBar.showError`, `AppSnackBar.showInfo`.
  - Chuyển đổi 20 `fontSize:` sang Design Tokens:
    - Tiêu đề báo cáo, thẻ thống kê tổng doanh thu/nợ đọng $\rightarrow$ `context.titleLarge`, `context.titleMedium`.
    - Chỉ số % tăng trưởng $\rightarrow$ `context.labelSmall?.copyWith(fontWeight: FontWeight.bold)`.
    - Chú giải biểu đồ $\rightarrow$ `context.labelSmall`.
- **Kiểm thử:** `dart analyze lib/features/management/screens/financial_report_screen.dart`.

---

### Task 4: Mở Rộng CI Guardrail Whitelist & Xác Minh Hệ Thống
- Mở rộng `targetModulesWhitelist` trong `test/core/theme_and_color_guard_test.dart` thêm 3 màn hình trên (Module 12: Quản lý Biểu phí, Lập Hóa Đơn & Báo cáo Tài chính).
- Chạy `flutter test test/core/theme_and_color_guard_test.dart` (xác minh 4/4 passed).
- Chạy `dart analyze lib test` (xác minh 0 issues found).
- Chạy `graphify update .` đồng bộ kiến trúc codebase.
- Cập nhật `CHANGELOG.md` ghi nhận hoàn thành Gói 2.4.
- Commit trực tiếp vào `main` và push lên `origin/main`.

