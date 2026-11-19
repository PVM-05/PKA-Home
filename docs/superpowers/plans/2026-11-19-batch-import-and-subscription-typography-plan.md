# Gói 2.8: Chuẩn Hóa Typography & Hệ Thống Phản Hồi - Nhập Liệu Hàng Loạt, Gói Thuê Bao B2B SaaS & Đánh Giá Dịch Vụ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loại bỏ triệt để 100% (51 điểm) `fontSize:` cứng, chuẩn hóa thông báo `AppSnackBar` cho 3 màn hình nghiệp vụ trọng yếu của Ban Quản Lý (Nhập liệu hàng loạt, Gói thuê bao B2B SaaS, Tổng quan đánh giá dịch vụ), và đưa cả 3 màn hình vào CI Guardrail Whitelist (`theme_and_color_guard_test.dart`).

**Architecture:** Sử dụng Clean Architecture & Design Tokens ngữ nghĩa (`AppTypography` extension on `BuildContext`, `AppTheme` semantic colors, `AppSnackBar` modern animated snackbar). Toàn bộ giao diện tuân thủ 100% tiếng Việt chuẩn mực, hỗ trợ co giãn responsive cho B2B Web/Tablet/Desktop theo quy chuẩn thương mại SaaS.

**Tech Stack:** Flutter 3.38.x, Dart 3.10.x, Flutter Riverpod, Material Design 3, Design System Tokens (`AppTypography`, `AppTheme`, `AppSnackBar`).

## Global Constraints

- 100% tiếng Việt chuẩn mực trên toàn bộ nhãn, thông báo và nút bấm.
- Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- Giữ nguyên toàn bộ logic nghiệp vụ (Excel parsing, Subscription tier calculation, CSAT breakdown & rating filters).
- Tuyệt đối không hardcode mã màu rời rạc hoặc `fontSize` số học.
- Đảm bảo `dart analyze lib test` đạt 0 issues và các test suites liên quan đều PASS 100%.

---

### Task 1: Chuẩn Hóa Typography & SnackBar Màn Hình Nhập Liệu Hàng Loạt (`batch_import_center_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/batch_import_center_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`
- Reference: `lib/core/widgets/app_snack_bar.dart`

**Interfaces:**
- Consumes: `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelMedium`, `context.labelSmall`, `AppSnackBar.showSuccess()`, `AppSnackBar.showError()`.
- Produces: Màn hình `BatchImportCenterScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/19) và chuẩn hóa thông báo phản hồi.

- [ ] **Step 1: Khảo sát chi tiết 19 điểm fontSize và 6 điểm SnackBar trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` và `app_snack_bar.dart` nếu thiếu**
- [ ] **Step 3: Thay thế các điểm fontSize cứng sang AppTypography ngữ nghĩa**
- [ ] **Step 4: Thay thế 6 điểm ScaffoldMessenger.of(context).showSnackBar sang AppSnackBar**
- [ ] **Step 5: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/batch_import_center_screen.dart`**

---

### Task 2: Chuẩn Hóa Typography & SnackBar Màn Hình Gói Thuê Bao B2B SaaS (`subscription_management_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/subscription_management_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`
- Reference: `lib/core/widgets/app_snack_bar.dart`

**Interfaces:**
- Consumes: `context.headlineMedium`, `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelMedium`, `context.labelSmall`, `AppSnackBar.showSuccess()`, `AppSnackBar.showError()`.
- Produces: Màn hình `SubscriptionManagementScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/18) và chuẩn hóa thông báo gia hạn/đổi gói.

- [ ] **Step 1: Khảo sát chi tiết 18 điểm fontSize và 2 điểm SnackBar trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` và `app_snack_bar.dart` nếu thiếu**
- [ ] **Step 3: Thay thế các điểm fontSize cứng (thẻ gói cước, KPI, tính năng) sang AppTypography**
- [ ] **Step 4: Thay thế 2 điểm ScaffoldMessenger.of(context).showSnackBar sang AppSnackBar**
- [ ] **Step 5: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/subscription_management_screen.dart`**

---

### Task 3: Chuẩn Hóa Typography Màn Hình Đánh Giá Dịch Vụ CSAT (`service_rating_overview_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/service_rating_overview_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`

**Interfaces:**
- Consumes: `context.headlineMedium`, `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelMedium`, `context.labelSmall`.
- Produces: Màn hình `ServiceRatingOverviewScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/14).

- [ ] **Step 1: Khảo sát chi tiết 14 điểm fontSize trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` nếu thiếu**
- [ ] **Step 3: Thay thế các điểm fontSize cứng (điểm số CSAT 4.8, phân bổ sao 1-5, danh sách phản hồi) sang AppTypography**
- [ ] **Step 4: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/service_rating_overview_screen.dart`**

---

### Task 4: Cập Nhật Whitelist CI Guardrail & Chạy Test Suite

**Files:**
- Modify: `test/core/theme_and_color_guard_test.dart`

**Interfaces:**
- Module 16: Thêm 3 màn hình vào `targetModulesWhitelist`.
- Passes: `Guardrail: Mọi file trong whitelist đều phải tồn tại trên đĩa`, `Guardrail: Các màn hình trong whitelist không được chứa mã màu cứng Color(0x...)`, `Guardrail: Các màn hình trong whitelist không được chứa fontSize cứng`.

- [ ] **Step 1: Bổ sung Module 16 vào `targetModulesWhitelist` trong `test/core/theme_and_color_guard_test.dart`**
- [ ] **Step 2: Chạy kiểm thử guardrail `flutter test test/core/theme_and_color_guard_test.dart`**
- [ ] **Step 3: Chạy các test suites liên quan trong `test/features/management/`**
- [ ] **Step 4: Chạy toàn bộ phân tích tĩnh `dart analyze lib test`**

---

### Task 5: Cập Nhật Tài Liệu, Tri Thức Kiến Trúc & Git Commit

**Files:**
- Modify: `CHANGELOG.md`
- Graphify Update: `graphify update .`
- Git Commit: commit vào `main` & push lên `origin/main`

- [ ] **Step 1: Cập nhật `CHANGELOG.md` ghi nhận hoàn tất Gói 2.8**
- [ ] **Step 2: Cập nhật tri thức `graphify update .`**
- [ ] **Step 3: Git add, commit và push lên `origin/main`**
