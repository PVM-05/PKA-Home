# Master Implementation Plan: Triệt Tiêu 100% Nợ Kỹ Thuật Typography Toàn Bộ Codebase Vivona (Gói 2.19, 2.20, 2.21)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task without stopping until 100% Zero Debt is achieved. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xóa sạch toàn bộ 115 điểm nợ kỹ thuật hardcoded `fontSize:` còn lại trên 21 widget BQL cuối cùng trong `lib/features/management/widgets/`, đưa toàn bộ dự án Vivona đạt mốc lịch sử **100% Zero Debt Typography** (936/936 điểm nợ được thanh toán triệt để).

**Architecture:** Chuẩn hóa toàn bộ về `AppTypography` token extensions (`context.titleLarge`, `context.titleMedium`, `context.titleSmall`, `context.bodyMedium`, `context.bodySmall`, `context.labelSmall`), tích hợp toàn bộ vào CI/CD Guardrail test suite Module 27, 28, 29.

**Tech Stack:** Flutter, Dart, Riverpod, Google Fonts (Segoe UI), Flutter Test.

## Global Constraints

- Không còn bất kỳ điểm `fontSize:` cứng nào trong `lib/features/management/widgets/`.
- Sử dụng `import '../../../core/theme/app_typography.dart';` trên tất cả 21 file.
- Không làm thay đổi logic nghiệp vụ, tính toán tiền tệ, state hay luồng sự kiện.
- Cập nhật CI Guardrail `test/core/theme_and_color_guard_test.dart` bảo vệ toàn bộ 21 file.
- Xác minh bằng `dart analyze` và `flutter test`.
- Cập nhật `CHANGELOG.md`, `graphify update .`, commit trực tiếp vào `main`.

---

### Batch A (Gói 2.19): Cụm Công Cụ Tài Chính, Đôn Đốc & Khảo Sát BQL (52 điểm)
- [x] Task A1: `quick_fee_calculator_sheet.dart` (15 điểm)
- [x] Task A2: `execute_dunning_dialog.dart` (15 điểm)
- [x] Task A3: `resident_activation_management_sheet.dart` (11 điểm)
- [x] Task A4: `poll_result_dialog.dart` (11 điểm)
- [x] Task A5: Verify static analysis & guardrail test Module 27

---

### Batch B (Gói 2.20): Hợp Đồng Căn Hộ, Lời Mời, Biểu Quyết & Nhiệm Vụ Kỹ Thuật (36 điểm)
- [x] Task B1: `apartment_contract_sheet.dart` (10 điểm)
- [x] Task B2: `create_poll_sheet.dart` (8 điểm)
- [x] Task B3: `create_apartment_invitation_sheet.dart` (7 điểm)
- [x] Task B4: `role_onboarding_dialog.dart` (6 điểm)
- [x] Task B5: `maintenance_task_form_dialog.dart` (5 điểm)
- [x] Task B6: Verify static analysis & guardrail test Module 28

---

### Batch C (Gói 2.21): Nghiệp Vụ Tiện Ích, Trạm Lễ Tân & Phím Tắt Nhanh - Cán Mốc 100% Zero Debt (27 điểm)
- [x] Task C1: `amenity_management_receipt_sheet.dart` (4 điểm)
- [x] Task C2: `respond_petition_dialog.dart` (3 điểm)
- [x] Task C3: `stat_card.dart` (3 điểm)
- [x] Task C4: `all_quick_actions_sheet.dart` (3 điểm)
- [x] Task C5: `handover_parcel_dialog.dart` (3 điểm)
- [x] Task C6: `amenity_deposit_dialog.dart` (2 điểm)
- [x] Task C7: `amenity_inspection_dialog.dart` (2 điểm)
- [x] Task C8: `management_theme_mode_sheet.dart` (2 điểm)
- [x] Task C9: `amenity_confirm_payment_dialog.dart` (1 điểm)
- [x] Task C10: `close_period_dialog.dart` (1 điểm)
- [x] Task C11: `receive_parcel_sheet.dart` (1 điểm)
- [x] Task C12: `amenity_quick_check_in_dialog.dart` (1 điểm)
- [x] Task C13: Verify static analysis & guardrail test Module 29

---

### Batch D: Đóng Gói Toàn Diện, CHANGELOG, Knowledge Graph & Push Main
- [x] Task D1: Kiểm tra tổng số `fontSize:` trong toàn bộ codebase bằng 0
- [x] Task D2: Cập nhật `CHANGELOG.md` ghi nhận cán mốc 100% Zero Debt
- [x] Task D3: Cập nhật knowledge graph `graphify update .`
- [x] Task D4: Commit và push vào `main`
