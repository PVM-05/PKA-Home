# Gói 2.9: Chuẩn Hóa Typography & Hệ Thống Phản Hồi - Trạm Kế Toán B2B Web, Sổ Cái Căn Hộ, Quỹ Bảo Trì 2% & Điều Chỉnh Hóa Đơn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loại bỏ triệt để 100% (50 điểm) `fontSize:` cứng và chuẩn hóa các lệnh thông báo `AppSnackBar` trên 4 màn hình kế toán & tài chính chuyên sâu của Ban Quản Lý (`accounting_web_workstation_screen.dart`, `apartment_ledger_screen.dart`, `maintenance_fund_ledger_screen.dart`, `edit_invoice_screen.dart`), đồng thời đưa cả 4 màn hình vào CI Guardrail Whitelist Module 17 (`theme_and_color_guard_test.dart`).

**Architecture:** Áp dụng Design Tokens ngữ nghĩa (`AppTypography` extension on `BuildContext`, `AppTheme` semantic palette, `AppSnackBar` floating notifications). Đảm bảo giao diện 100% tiếng Việt chuẩn mực, hỗ trợ hoàn hảo cho kế toán thao tác trên Web/Desktop và Tablet.

**Tech Stack:** Flutter 3.38.x, Dart 3.10.x, Flutter Riverpod, Material Design 3, Design System Tokens (`AppTypography`, `AppTheme`, `AppSnackBar`).

## Global Constraints

- 100% tiếng Việt chuẩn mực trên toàn bộ giao diện, nhãn nút và thông báo.
- Toàn bộ commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- Giữ nguyên toàn bộ logic nghiệp vụ (Tính toán công nợ, đối soát sổ cái căn hộ, ghi nhận xuất nhập quỹ bảo trì 2%, và cơ chế chỉnh sửa hạng mục hóa đơn pro-rata).
- Tuyệt đối không hardcode mã màu rời rạc hoặc `fontSize` số học.
- Đảm bảo `dart analyze lib test` đạt 0 issues và toàn bộ test suites liên quan đều PASS 100%.

---

### Task 1: Chuẩn Hóa Typography & SnackBar Màn Hình Trạm Kế Toán B2B Web (`accounting_web_workstation_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/accounting_web_workstation_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`
- Reference: `lib/core/widgets/app_snack_bar.dart`

**Interfaces:**
- Consumes: `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelMedium`, `context.labelSmall`, `AppSnackBar.showSuccess()`, `AppSnackBar.showError()`.
- Produces: Màn hình `AccountingWebWorkstationScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/14) và thông báo SnackBar chuẩn hóa.

- [ ] **Step 1: Khảo sát chi tiết 14 điểm fontSize và 1 điểm SnackBar trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` và `app_snack_bar.dart`**
- [ ] **Step 3: Thay thế các điểm fontSize cứng sang AppTypography ngữ nghĩa**
- [ ] **Step 4: Thay thế lệnh ScaffoldMessenger.of(context).showSnackBar sang AppSnackBar.showSuccess**
- [ ] **Step 5: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/accounting_web_workstation_screen.dart`**

---

### Task 2: Chuẩn Hóa Typography Màn Hình Sổ Cái Căn Hộ (`apartment_ledger_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/apartment_ledger_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`

**Interfaces:**
- Consumes: `context.headlineSmall`, `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`.
- Produces: Màn hình `ApartmentLedgerScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/13).

- [ ] **Step 1: Khảo sát chi tiết 13 điểm fontSize trong file**
- [ ] **Step 2: Thêm import `app_typography.dart`**
- [ ] **Step 3: Thay thế các điểm fontSize cứng (thẻ công nợ tổng hợp, bảng lịch sử phát sinh, thẻ trạng thái) sang AppTypography**
- [ ] **Step 4: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/apartment_ledger_screen.dart`**

---

### Task 3: Chuẩn Hóa Typography & SnackBar Màn Hình Quỹ Bảo Trì 2% Tòa Nhà (`maintenance_fund_ledger_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/maintenance_fund_ledger_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`
- Reference: `lib/core/widgets/app_snack_bar.dart`

**Interfaces:**
- Consumes: `context.headlineMedium`, `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`, `AppSnackBar.showSuccess()`, `AppSnackBar.showError()`.
- Produces: Màn hình `MaintenanceFundLedgerScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/12) và chuẩn hóa toàn bộ các thông báo giải ngân/nhập quỹ.

- [ ] **Step 1: Khảo sát chi tiết 12 điểm fontSize và 5 điểm SnackBar trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` và `app_snack_bar.dart`**
- [ ] **Step 3: Thay thế các điểm fontSize cứng sang AppTypography**
- [ ] **Step 4: Thay thế 5 điểm ScaffoldMessenger.of(context).showSnackBar sang AppSnackBar**
- [ ] **Step 5: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/maintenance_fund_ledger_screen.dart`**

---

### Task 4: Chuẩn Hóa Typography & SnackBar Màn Hình Điều Chỉnh Hóa Đơn (`edit_invoice_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/edit_invoice_screen.dart`
- Reference: `lib/core/theme/app_typography.dart`
- Reference: `lib/core/widgets/app_snack_bar.dart`

**Interfaces:**
- Consumes: `context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelMedium`, `context.labelSmall`, `AppSnackBar.showSuccess()`, `AppSnackBar.showError()`, `AppSnackBar.showWarning()`.
- Produces: Màn hình `EditInvoiceScreen` chuẩn Design Tokens không còn `fontSize:` cứng (0/11) và chuẩn hóa toàn bộ các thông báo thêm/sửa/xóa hạng mục.

- [ ] **Step 1: Khảo sát chi tiết 11 điểm fontSize và 6 điểm SnackBar trong file**
- [ ] **Step 2: Thêm import `app_typography.dart` và `app_snack_bar.dart`**
- [ ] **Step 3: Thay thế các điểm fontSize cứng sang AppTypography**
- [ ] **Step 4: Thay thế 6 điểm ScaffoldMessenger.of(context).showSnackBar sang AppSnackBar**
- [ ] **Step 5: Kiểm tra phân tích tĩnh `dart analyze lib/features/management/screens/edit_invoice_screen.dart`**

---

### Task 5: Mở Rộng Whitelist Guardrail CI & Kiểm Thử Toàn Diện

**Files:**
- Modify: `test/core/theme_and_color_guard_test.dart`

**Interfaces:**
- Module 17: Thêm 4 màn hình vào `targetModulesWhitelist`.
- Passes: 4 guardrail tests và các widget tests liên quan trong `test/features/management/`.

- [ ] **Step 1: Bổ sung Module 17 vào `targetModulesWhitelist` trong `test/core/theme_and_color_guard_test.dart`**
- [ ] **Step 2: Chạy kiểm thử guardrail `flutter test test/core/theme_and_color_guard_test.dart`**
- [ ] **Step 3: Chạy các widget tests liên quan đến ledger, invoice và accounting**
- [ ] **Step 4: Chạy toàn bộ phân tích tĩnh `dart analyze lib test`**

---

### Task 6: Cập Nhật Tài Liệu, Tri Thức Kiến Trúc & Git Commit

**Files:**
- Modify: `CHANGELOG.md`
- Graphify Update: `graphify update .`
- Git Commit: commit trực tiếp vào `main` & push lên `origin/main`

- [ ] **Step 1: Cập nhật `CHANGELOG.md` ghi nhận hoàn tất Gói 2.9**
- [ ] **Step 2: Cập nhật tri thức `graphify update .`**
- [ ] **Step 3: Git add, commit và push lên `origin/main`**
