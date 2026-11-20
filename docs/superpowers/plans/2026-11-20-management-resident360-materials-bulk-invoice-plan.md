# Gói 2.18: Quản Trị BQL Hồ Sơ Cư Dân 360, Vật Tư Sự Cố & Lập Hóa Đơn Hàng Loạt Typography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triệt tiêu hoàn toàn 54 điểm nợ kỹ thuật hardcoded `fontSize:` trên cụm 3 widget nghiệp vụ BQL trọng yếu (`resident_360_detail_sheet.dart`, `resolve_issue_materials_sheet.dart`, `bulk_invoice_dialog.dart`), chuyển đổi 100% sang hệ thống typography token `AppTypography` (`context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`), tích hợp Module 26 vào CI/CD Guardrail test.

**Architecture:** Áp dụng `AppTypography` extensions theo `BuildContext` (`context.title*`, `context.body*`, `context.label*`), chuẩn hóa màu sắc theo `AppTheme.*` và `AppStatusColors.*`, loại bỏ các mã màu Material hardcoded, đảm bảo 100% tiếng Việt chuẩn mực cho phần mềm thương mại SaaS PropTech Vivona.

**Tech Stack:** Flutter, Dart, Riverpod, Google Fonts (Segoe UI), Flutter Test.

## Global Constraints

- Không hardcode `fontSize:` trong bất kỳ `TextStyle` nào của 3 widget mục tiêu.
- Sử dụng `import '../../../core/theme/app_typography.dart';` để gọi trực tiếp các text token extension trên `BuildContext`.
- Giữ nguyên toàn bộ logic dữ liệu, state Stream/FutureProvider, form validation, và hành vi UI.
- Thêm Module 26 vào `targetModulesWhitelist` trong `test/core/theme_and_color_guard_test.dart`.
- Chạy kiểm thử tự động xác minh: `dart analyze` và `flutter test test/core/theme_and_color_guard_test.dart`.
- Commit trực tiếp vào nhánh `main` theo quy tắc dự án.

---

### Task 1: Chuẩn Hóa Typography Bảng Hồ Sơ Cư Dân 360 Độ (`resident_360_detail_sheet.dart`)

**Files:**
- Modify: `lib/features/management/widgets/resident_360_detail_sheet.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext`.
- Produces: 20 điểm `fontSize:` được loại bỏ.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor Edit Profile Dialog & Header Profile Avatar**
  - Line 244: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
  - Line 431: `style: context.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
  - Line 444: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
  - Line 456: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Line 461: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 2: Refactor Badges, Action Buttons & Filter Chips Đa Căn Hộ**
  - Line 476: `style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primary)`
  - Line 490: `style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: (_resident.isActive && !_resident.isLocked) ? AppTheme.success : AppTheme.error)`
  - Line 518: `style: context.bodySmall`
  - Line 528: `style: context.bodySmall`
  - Line 539: `style: context.bodySmall`
  - Line 557: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 571: `style: context.labelSmall?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppTheme.textPrimary)`
  - Line 616: `style: context.bodySmall`

- [x] **Step 3: Refactor Phương Tiện, Hóa Đơn & Tiện Ích Tabs**
  - Line 696: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 697: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 709: `style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)`
  - Line 766: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 778: `style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)`
  - Line 848: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 860: `style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)`

- [x] **Step 4: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/resident_360_detail_sheet.dart`
  Expected: No issues found!

---

### Task 2: Chuẩn Hóa Typography Trạm Nghiệm Thu & Xuất Kho Vật Tư (`resolve_issue_materials_sheet.dart`)

**Files:**
- Modify: `lib/features/management/widgets/resolve_issue_materials_sheet.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext`.
- Produces: 18 điểm `fontSize:` được loại bỏ.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor Dialog Thêm Vật Tư**
  - Line 89: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 100: `style: context.bodyMedium`
  - Line 113: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primary)`
  - Line 118: `style: context.bodyMedium`
  - Line 123: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 133: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 134: `style: context.labelSmall`

- [x] **Step 2: Refactor Sheet Header, Error Message & Section Titles**
  - Line 290: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
  - Line 295: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Line 315: `style: context.bodyMedium?.copyWith(color: AppTheme.error)`
  - Line 323: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 381: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`

- [x] **Step 3: Refactor Material List, Empty State & Chargeable Total**
  - Line 407: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 440: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 445: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 451: `style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: entry.isChargeable ? AppTheme.primary : Colors.grey.shade700)`
  - Line 481: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 485: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`

- [x] **Step 4: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/resolve_issue_materials_sheet.dart`
  Expected: No issues found!

---

### Task 3: Chuẩn Hóa Typography Hộp Thoại Lập Hóa Đơn Hàng Loạt (`bulk_invoice_dialog.dart`)

**Files:**
- Modify: `lib/features/management/widgets/bulk_invoice_dialog.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext`.
- Produces: 16 điểm `fontSize:` được loại bỏ.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor Wizard Step 1 & Dry-Run Result Header**
  - Line 211: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Line 305: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
  - Line 319: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 2: Refactor Estimated Total Summary & KPI Cards**
  - Line 383: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 387: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
  - Line 393: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 475: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color)`
  - Line 476: `style: context.labelSmall?.copyWith(color: color.withValues(alpha: 0.8))`

- [x] **Step 3: Refactor Valid Items List & Issues List**
  - Line 487: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 505: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)`
  - Line 507: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 510: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 520: `style: context.bodySmall?.copyWith(color: AppStatusColors.paid)`
  - Line 546: `style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: color)`
  - Line 554: `style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: color)`
  - Line 555: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 4: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/bulk_invoice_dialog.dart`
  Expected: No issues found!

---

### Task 4: Cập Nhật Guardrail Test Suite & Kiểm Thử Toàn Diện

**Files:**
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Thêm Module 26 vào danh sách `targetModulesWhitelist`**
  ```dart
  // Module 26: Cụm Nghiệp Vụ BQL Trọng Yếu (Resident 360 Detail, Resolve Issue Materials & Bulk Invoice Dialog)
  'lib/features/management/widgets/resident_360_detail_sheet.dart',
  'lib/features/management/widgets/resolve_issue_materials_sheet.dart',
  'lib/features/management/widgets/bulk_invoice_dialog.dart',
  ```

- [x] **Step 2: Chạy static analysis toàn diện**
  Run: `dart analyze lib/features/management/widgets/resident_360_detail_sheet.dart lib/features/management/widgets/resolve_issue_materials_sheet.dart lib/features/management/widgets/bulk_invoice_dialog.dart test/core/theme_and_color_guard_test.dart`
  Expected: No issues found!

- [x] **Step 3: Chạy test guardrail**
  Run: `flutter test test/core/theme_and_color_guard_test.dart`
  Expected: All guardrail tests pass!

---

### Task 5: Cập Nhật Tài Liệu CHANGELOG, Graphify & Commit

- [x] **Step 1: Cập nhật `CHANGELOG.md`**
  - Ghi nhận Gói 2.18: Giảm 54 điểm nợ typography (từ 169 xuống còn 115 điểm trong toàn dự án).
- [x] **Step 2: Cập nhật knowledge graph**
  Run: `graphify update .`
- [x] **Step 3: Commit và push vào `main`**
  Run: `git add . ; git commit -m "feat(ui): chuẩn hóa typography goi 2.18 cho resident 360, vat tu va lap hoa don bql" ; git push origin main`
