# Kế Hoạch Triển Khai: Gói 2.2 - Chuẩn Hóa Typography & Design Tokens Cụm Tiện Ích Đặt Chỗ (Amenity Module)

> **Mục tiêu:** Xóa bỏ hoàn toàn 52+ điểm `fontSize:` cứng trong 2 màn hình chính của phân hệ Đặt chỗ & Quản lý Tiện ích (`amenity_management_screen.dart` và `amenity_booking_screen.dart`) cùng các widget đồng hành (`resident_amenity_bookings_tab.dart`), chuẩn hóa về Design Tokens (`context.titleLarge`, `context.bodyMedium`, `context.labelSmall`...), thay thế các lệnh gọi SnackBar thủ công bằng `AppSnackBar`, và mở rộng CI Guardrail Whitelist bảo vệ module vĩnh viễn.

---

## 1. Hiện Trạng & Phân Rã Công Việc

### Phân rã nợ Typography (`fontSize:`):
1. **`lib/features/management/screens/amenity_management_screen.dart`**: 26 điểm cứng.
2. **`lib/features/resident/screens/amenity_booking_screen.dart`**: 26 điểm cứng.
3. **`lib/features/resident/widgets/resident_amenity_bookings_tab.dart`**: 13 điểm cứng.
4. **Các hộp thoại và BottomSheet liên quan**:
   - `lib/features/resident/widgets/amenity_qr_code_dialog.dart`: 6 điểm.
   - `lib/features/management/widgets/amenity_deposit_dialog.dart`: 2 điểm.
   - `lib/features/management/widgets/amenity_inspection_dialog.dart`: 2 điểm.
   - `lib/features/management/widgets/amenity_confirm_payment_dialog.dart`: 1 điểm.
   - `lib/features/management/widgets/amenity_quick_check_in_dialog.dart`: 1 điểm.
   - `lib/features/management/widgets/amenity_management_receipt_sheet.dart`: 4 điểm.
   - `lib/features/resident/widgets/amenity_receipt_bottom_sheet.dart`: 4 điểm.

---

## 2. Các Bước Thực Hiện Chi Tiết

### Task 1: Chuẩn hóa `amenity_management_screen.dart` (26 điểm)
- Thêm `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
- Thay thế các `fontSize:` cứng:
  - Header & empty text: `fontSize: 15` $\rightarrow$ `context.bodyMedium` / `context.titleMedium`.
  - Amenity card titles: `fontSize: 16` $\rightarrow$ `context.titleMedium?.copyWith(fontWeight: FontWeight.bold)`.
  - Badges & metadata: `fontSize: 12`, `13`, `11` $\rightarrow$ `context.labelSmall` / `context.bodySmall`.
  - Dialog titles & form text: `fontSize: 16`, `13` $\rightarrow$ `context.titleMedium`, `context.bodyMedium`.
- Thay thế các khối `ScaffoldMessenger.of(context).showSnackBar` bằng `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
- Kiểm tra lại bằng `git grep -n "fontSize:" lib/features/management/screens/amenity_management_screen.dart`.

### Task 2: Chuẩn hóa `amenity_booking_screen.dart` (26 điểm)
- Thêm `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
- Thay thế các `fontSize:` cứng:
  - Time slots & slot status labels: `fontSize: 12`, `11` $\rightarrow$ `context.labelSmall`.
  - Amenity detail title & price: `fontSize: 18`, `15` $\rightarrow$ `context.titleLarge`, `context.titleMedium`.
  - Description & notes: `fontSize: 13`, `14` $\rightarrow$ `context.bodyMedium`, `context.bodySmall`.
  - Confirmation sheet: `fontSize: 18`, `16`, `15` $\rightarrow$ `context.titleLarge`, `context.titleMedium`.
- Thay thế các khối `ScaffoldMessenger.of(context).showSnackBar` bằng `AppSnackBar`.
- Kiểm tra lại bằng `git grep -n "fontSize:" lib/features/resident/screens/amenity_booking_screen.dart`.

### Task 3: Chuẩn hóa `resident_amenity_bookings_tab.dart` (13 điểm)
- Thêm `import '../../../core/theme/app_typography.dart';` và `import '../../../core/widgets/app_snack_bar.dart';`.
- Thay thế 13 điểm `fontSize:` cứng sang token ngữ cảnh chuẩn.

### Task 4: Mở Rộng CI Guardrail Whitelist & Kiểm Thử
- Thêm vào whitelist trong `test/core/theme_and_color_guard_test.dart`:
  - `'lib/features/management/screens/amenity_management_screen.dart',`
  - `'lib/features/resident/screens/amenity_booking_screen.dart',`
  - `'lib/features/resident/widgets/resident_amenity_bookings_tab.dart',`
- Chạy `test/core/theme_and_color_guard_test.dart` (yêu cầu 4/4 pass).
- Chạy các test tiện ích hiện có:
  - `test/contracts/rpc_contracts_test.dart`
  - `test/features/management/`
- Chạy `dart analyze lib test` (0 issues).
- Chạy `flutter test` (100% pass).

### Task 5: Cập Nhật Tài Liệu & Git Push
- Chạy `graphify update .`.
- Cập nhật `CHANGELOG.md` ghi nhận hoàn thành Gói 2.2.
- Commit vào `main` và push lên `origin/main`.

