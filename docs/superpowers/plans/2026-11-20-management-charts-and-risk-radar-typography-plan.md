# Gói 2.17: Quản Trị BQL Charts, Radar Rủi Ro Công Nợ & Hiệu Suất Nhân Sự Typography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triệt tiêu hoàn toàn 49 điểm nợ kỹ thuật hardcoded `fontSize:` trên cụm 3 widget biểu đồ, radar rủi ro và đánh giá kỹ thuật viên BQL (`debt_risk_radar_tab.dart`, `revenue_trend_chart.dart`, `technician_performance_card.dart`), chuẩn hóa về hệ thống typography `AppTypography` token extensions (`context.titleLarge`, `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`), tích hợp Module 25 vào CI/CD Guardrail test.

**Architecture:** Áp dụng `AppTypography` extensions theo `BuildContext` (`context.title*`, `context.body*`, `context.label*`), kế thừa màu sắc qua `AppTheme.*` và trạng thái `AppStatusColors.*`, loại bỏ các mã màu Material `Colors.orange`, đảm bảo 100% tiếng Việt chuẩn mực cho phần mềm thương mại SaaS PropTech Vivona.

**Tech Stack:** Flutter, Dart, Riverpod, Google Fonts (Segoe UI), Flutter Test.

## Global Constraints

- Không hardcode `fontSize:` trong bất kỳ `TextStyle` nào của 3 widget mục tiêu.
- Sử dụng `import '../../../core/theme/app_typography.dart';` để gọi trực tiếp các text token extension trên `BuildContext`.
- Giữ nguyên toàn bộ logic dữ liệu, state Stream/FutureProvider, animation, và hành vi UI.
- Thêm Module 25 vào `targetModulesWhitelist` trong `test/core/theme_and_color_guard_test.dart`.
- Chạy kiểm thử tự động xác minh: `dart analyze` và `flutter test test/core/theme_and_color_guard_test.dart`.
- Commit trực tiếp vào nhánh `main` theo quy tắc dự án.

---

### Task 1: Chuẩn Hóa Typography Radar Rủi Ro Công Nợ (`debt_risk_radar_tab.dart`)

**Files:**
- Modify: `lib/features/management/widgets/debt_risk_radar_tab.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext` (`context.titleLarge`, `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`, `context.labelLarge`).
- Produces: 25 điểm `fontSize:` được loại bỏ, sử dụng semantic text styles.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor `_buildKpiCard`**
  - Line 179: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 188: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)`
  - Line 193: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 2: Refactor `_buildFilterBar` & `_buildFilterChip`**
  - Line 211: `hintStyle: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Line 228: `style: context.bodyMedium`
  - Line 259: `labelStyle: context.bodySmall?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppTheme.textPrimary)`

- [x] **Step 3: Refactor `_buildApartmentList` & `_buildApartmentCard`**
  - Line 284: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 289: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 306: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 311: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 342: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`
  - Line 353: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 358: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 384: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: apt.riskLevel.color)`
  - Line 392: `style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: apt.riskLevel.color)`
  - Line 414: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 418: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.error)`
  - Line 427: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 431: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)`
  - Line 440: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 444: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)`
  - Line 474: `style: context.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500)`
  - Line 496: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 501: `style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: apt.recommendedTier.color)`
  - Line 511: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 4: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/debt_risk_radar_tab.dart`
  Expected: No issues found!

---

### Task 2: Chuẩn Hóa Typography Biểu Đồ Doanh Thu 6 Kỳ (`revenue_trend_chart.dart`)

**Files:**
- Modify: `lib/features/management/widgets/revenue_trend_chart.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext` (`context.titleLarge`, `context.titleMedium`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`).
- Produces: 17 điểm `fontSize:` được loại bỏ.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor Header & Empty State**
  - Line 35: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 57: `style: context.bodySmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 69: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`

- [x] **Step 2: Refactor Trục Hoành Đồ Thị & Tóm Tắt 6 Kỳ**
  - Line 142: `style: context.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)`
  - Line 150: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 171: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 178: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppStatusColors.paid)`
  - Line 190: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 197: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppStatusColors.unpaid)`
  - Line 209: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 214: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)`

- [x] **Step 3: Refactor Error State, Legend Item, Modal Chi Tiết & Row Detail**
  - Line 242: `style: context.bodyMedium?.copyWith(color: AppTheme.error)`
  - Line 255: `style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold)`
  - Line 282: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)`
  - Line 307: `style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold)`
  - Line 342: `style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary)`
  - Line 345: `style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: valueColor)`

- [x] **Step 4: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/revenue_trend_chart.dart`
  Expected: No issues found!

---

### Task 3: Chuẩn Hóa Typography Đánh Giá Hiệu Suất Kỹ Thuật Viên (`technician_performance_card.dart`)

**Files:**
- Modify: `lib/features/management/widgets/technician_performance_card.dart`

**Interfaces:**
- Consumes: `AppTypography` extension tokens on `BuildContext`.
- Produces: 7 điểm `fontSize:` được loại bỏ, chuẩn hóa `Colors.orange` thành `AppTheme.warning`.

- [x] **Step 1: Thêm import `app_typography.dart` và refactor Title, Staff Name, Rating Badge & Metrics**
  - Line 123: `style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 163: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)`
  - Line 183: `style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)`
  - Line 200: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 203: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.success)`
  - Line 210: `style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)`
  - Line 215: `style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.warning)`

- [x] **Step 2: Verify static analysis**
  Run: `dart analyze lib/features/management/widgets/technician_performance_card.dart`
  Expected: No issues found!

---

### Task 4: Cập Nhật Guardrail Test Suite & Kiểm Thử Toàn Diện

**Files:**
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Thêm Module 25 vào danh sách `targetModulesWhitelist`**
  ```dart
  // Module 25: Cụm BQL Charts, Risk Radar & Hiệu suất Nhân sự (Debt Risk Radar, Revenue Trend Chart & Technician Performance Card)
  'lib/features/management/widgets/debt_risk_radar_tab.dart',
  'lib/features/management/widgets/revenue_trend_chart.dart',
  'lib/features/management/widgets/technician_performance_card.dart',
  ```

- [x] **Step 2: Chạy static analysis toàn diện**
  Run: `dart analyze lib/features/management/widgets/debt_risk_radar_tab.dart lib/features/management/widgets/revenue_trend_chart.dart lib/features/management/widgets/technician_performance_card.dart test/core/theme_and_color_guard_test.dart`
  Expected: No issues found!

- [x] **Step 3: Chạy test guardrail**
  Run: `flutter test test/core/theme_and_color_guard_test.dart`
  Expected: All guardrail tests pass!

---

### Task 5: Cập Nhật Tài Liệu CHANGELOG, Graphify & Commit

- [x] **Step 1: Cập nhật `CHANGELOG.md`**
  - Ghi nhận Gói 2.17: Giảm 49 điểm nợ typography (từ 218 xuống còn 169 điểm trong toàn dự án).
- [x] **Step 2: Cập nhật knowledge graph**
  Run: `graphify update .`
- [x] **Step 3: Commit và push vào `main`**
  Run: `git add . && git commit -m "feat(ui): chuẩn hóa typography goi 2.17 cho bql charts va radar rui ro" && git push origin main`
