# Kế Hoạch Triển Khai: Hoàn Thiện Nền Tảng Giao Diện UI 2026 (Giai Đoạn 0 - Foundation Hardening)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện 100% nền tảng Design System của Vivona theo xu hướng Expressive 2026 (bằng tokens và theme nội tại), xóa bỏ nợ kỹ thuật mã cứng (1.206 fontSize + 59 màu) và phân rã các màn hình nguyên khối >1.500 dòng theo phương pháp cuốn chiếu dọc bảo đảm `dart analyze` 0 lỗi và 100% tests passed.

**Architecture:** Áp dụng phương án cuốn chiếu dọc (Vertical Slice): tạo tokens nền tảng (`AppSpacing`, `AppRadius`) và hoàn thiện `TextTheme` 15 styles + Component Themes trước, sau đó cuốn chiếu từng module (Auth $\rightarrow$ Trang chủ & Hồ sơ $\rightarrow$ Xe & Đồng hồ $\rightarrow$ Màn hình BQL). Mỗi module hoàn thành đều được đưa ngay vào whitelist của `theme_and_color_guard_test.dart` và khóa bằng unit/widget test.

**Tech Stack:** Flutter 3.44+ / SDK ^3.12.0, Google Fonts Inter, Flutter Riverpod 2.6.1, Flutter Test / Mocktail.

## Global Constraints
- Không sử dụng package M3 Expressive trôi nổi của cộng đồng; áp dụng Expressive bằng theme & tokens nội tại.
- Giữ nguyên 100% mã màu Light của `AppStatusColors` để đảm bảo zero-regression.
- Mọi file sau khi refactor phải tuân thủ nghiêm ngặt: không chứa `Color(0x...)` và không chứa `fontSize:` cứng.
- Commit trực tiếp trên nhánh `main` theo quy định dự án; mỗi task kết thúc bằng một commit hoàn chỉnh.

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Xây Dựng Bộ Token `AppSpacing` & `AppRadius`
**Files:**
- Create: `lib/core/theme/app_spacing.dart`
- Create: `lib/core/theme/app_radius.dart`
- Test: `test/core/theme/app_tokens_test.dart`

**Interfaces:**
- Consumes: Flutter `material.dart`
- Produces: `AppSpacing.xs` .. `AppSpacing.huge`, `AppSpacing.p4` .. `AppSpacing.p32`, `AppSpacing.h4` .. `AppSpacing.h32`, `AppRadius.xsValue` .. `AppRadius.fullValue`, `AppRadius.rSm` .. `AppRadius.rFull`, `AppRadius.shapeSm` .. `AppRadius.shapeLg`, `AppRadius.bottomSheet`.

- [x] **Step 1: Viết test kiểm tra tính toàn vẹn của Tokens**
  - Tạo `test/core/theme/app_tokens_test.dart`: kiểm tra các giá trị kích thước, tính bất biến, tỷ lệ khoảng cách 4-8-12-16-24-32, và các hình khối `RoundedRectangleBorder`.
- [x] **Step 2: Chạy test để xác nhận test fail**
  - Chạy `flutter test test/core/theme/app_tokens_test.dart`.
- [x] **Step 3: Triển khai `AppSpacing`**
  - Viết `lib/core/theme/app_spacing.dart` với đầy đủ hằng số khoảng cách, `EdgeInsets` helpers (`p*`, `px*`, `py*`), và `SizedBox` spacers (`h*`, `w*`).
- [x] **Step 4: Triển khai `AppRadius`**
  - Viết `lib/core/theme/app_radius.dart` với đầy đủ giá trị double, `Radius`, `BorderRadius`, `RoundedRectangleBorder`, và bo góc chuyên dụng cho `bottomSheet`.
- [x] **Step 5: Chạy lại test xác nhận pass**
  - Chạy `flutter test test/core/theme/app_tokens_test.dart`.
- [x] **Step 6: Commit code**
  - Commit message: `feat(design-system): khoi tao he thong tokens app_spacing va app_radius`

---

### Task 2: Hoàn Thiện 15/15 Kiểu Chữ (`TextTheme`) & Cấu Hình Component Themes
**Files:**
- Modify: `lib/core/theme/app_theme.dart:130-350`
- Test: `test/core/theme/app_theme_tokens_and_components_test.dart`

**Interfaces:**
- Consumes: `AppSpacing`, `AppRadius`, `GoogleFonts.inter`
- Produces: `AppTheme.lightTheme`, `AppTheme.darkTheme` với đầy đủ 15 `TextTheme` styles và 6 component themes mới.

- [x] **Step 1: Viết test kiểm tra cấu hình theme**
  - Tạo `test/core/theme/app_theme_tokens_and_components_test.dart`:
    - Kiểm tra `lightTheme.textTheme` và `darkTheme.textTheme` có đủ 15 styles non-null (`display*`, `headline*`, `title*`, `body*`, `label*`).
    - Kiểm tra các component themes: `filledButtonTheme`, `chipTheme`, `dialogTheme`, `bottomSheetTheme`, `switchTheme`, `floatingActionButtonTheme`, `navigationBarTheme` có cấu hình hợp lệ trên cả 2 theme mode.
- [x] **Step 2: Chạy test để xác nhận test fail**
  - Chạy `flutter test test/core/theme/app_theme_tokens_and_components_test.dart`.
- [x] **Step 3: Cập nhật `AppTheme.lightTheme` & `AppTheme.darkTheme`**
  - Bổ sung 10 kiểu chữ còn thiếu vào `baseTextTheme.copyWith(...)` cho cả Light và Dark.
  - Thêm cấu hình `filledButtonTheme`, `chipTheme`, `dialogTheme`, `bottomSheetTheme`, `switchTheme`, `floatingActionButtonTheme` ứng dụng `AppRadius` và `AppSpacing`.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/theme/app_theme_tokens_and_components_test.dart`.
- [x] **Step 5: Chạy toàn bộ test theme hiện có**
  - Chạy `flutter test test/core/theme/`.
- [x] **Step 6: Commit code**
  - Commit message: `feat(design-system): hoan thien textTheme 15 styles va 6 component themes`

---

### Task 3: Cuốn Chiếu Module Xác Thực (Auth Module) & Mở Rộng Guard Whitelist
**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `lib/features/auth/screens/register_screen.dart`
- Modify: `lib/features/auth/screens/first_time_activation_screen.dart`
- Modify: `lib/features/auth/screens/forgot_password_screen.dart`
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Thêm 4 file Auth vào whitelist của `theme_and_color_guard_test.dart`**
  - Thêm các đường dẫn file Auth vào danh sách `targetModulesWhitelist`.
- [x] **Step 2: Chạy guard test để xác nhận phát hiện vi phạm màu & fontSize cứng**
  - Chạy `flutter test test/core/theme_and_color_guard_test.dart`.
- [x] **Step 3: Refactor `login_screen.dart`**
  - Xóa 6 màu cứng `Color(0x...)`, thay thế bằng `AppTheme.primary`, `AppTheme.border`, `AppTheme.textSecondary`.
  - Thay thế `fontSize:` bằng `context.titleLarge`, `context.bodyMedium`,...
  - Thay thế padding và radius bằng `AppSpacing` và `AppRadius`.
- [x] **Step 4: Refactor `register_screen.dart`, `first_time_activation_screen.dart`, `forgot_password_screen.dart`**
  - Chuẩn hóa tokens cho toàn bộ các màn hình Auth còn lại.
- [x] **Step 5: Chạy guard test và auth tests xác nhận 100% pass**
  - Chạy `flutter test test/core/theme_and_color_guard_test.dart test/features/auth/`.
- [x] **Step 6: Commit code**
  - Commit message: `refactor(auth): chuan hoa design tokens loai bo mau cung va mo rong guard whitelist`

---

### Task 4: Phân Rã & Chuẩn Hóa Trang Chủ Cư Dân (`ResidentHomeScreen`) & Hồ Sơ (`ResidentProfileScreen`)
**Files:**
- Create: `lib/features/resident/widgets/home/resident_home_header_widget.dart`
- Create: `lib/features/resident/widgets/home/resident_home_quick_actions_grid.dart`
- Create: `lib/features/resident/widgets/home/resident_home_upcoming_invoice_card.dart`
- Create: `lib/features/resident/widgets/home/resident_home_recent_issues_card.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Tách các widget con độc lập từ `resident_home_screen.dart`**
  - Trích xuất Header, Quick Actions, Upcoming Invoice Card, Recent Issues Card sang thư mục `lib/features/resident/widgets/home/`.
  - Giảm dung lượng file `resident_home_screen.dart` từ 1.247 dòng xuống < 400 dòng.
- [x] **Step 2: Chuẩn hóa Tokens & Thay thế Spinner**
  - Sử dụng `AppSpacing`, `AppRadius`, `AppSkeletonShimmer`, `AppEmptyState`.
  - Loại bỏ toàn bộ `fontSize:` và `Color(0x...)` cứng.
- [x] **Step 3: Chuẩn hóa `resident_profile_screen.dart`**
  - Thay thế tokens, loại bỏ màu và cỡ chữ cứng.
- [x] **Step 4: Thêm cả 2 file vào whitelist của `theme_and_color_guard_test.dart`**
  - Thêm `resident_home_screen.dart` và `resident_profile_screen.dart`.
- [x] **Step 5: Chạy tests màn hình Trang chủ và Hồ sơ**
  - Chạy `flutter test test/core/theme_and_color_guard_test.dart test/features/resident/resident_home* test/features/resident/resident_profile*`.
- [x] **Step 6: Commit code**
  - Commit message: `refactor(resident): phan ra trang chu cu dan thanh 4 widgets va chuan hoa tokens`

---

### Task 5: Phân Rã & Chuẩn Hóa Màn Hình Xe (`VehicleManagementScreen`) & Đồng Hồ (`ResidentMeterReadingScreen`)
**Files:**
- Create: `lib/features/resident/widgets/vehicle/resident_vehicle_card.dart`
- Create: `lib/features/resident/widgets/vehicle/register_vehicle_bottom_sheet.dart`
- Create: `lib/features/resident/widgets/meter/resident_meter_card.dart`
- Create: `lib/features/resident/widgets/meter/meter_reading_history_sheet.dart`
- Modify: `lib/features/resident/screens/vehicle_management_screen.dart`
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Phân rã `vehicle_management_screen.dart` (1.914 dòng)**
  - Tách thẻ phương tiện và modal đăng ký thành widget độc lập.
- [x] **Step 2: Phân rã `resident_meter_reading_screen.dart` (1.805 dòng)**
  - Tách form chỉ số công tơ và lịch sử thành widget độc lập.
- [x] **Step 3: Chuẩn hóa Design Tokens & Mở rộng Guard Whitelist**
  - Loại bỏ hoàn toàn `fontSize` và `Color(0x...)` cứng.
  - Thêm 2 file vào `theme_and_color_guard_test.dart`.
- [x] **Step 4: Chạy tests kiểm thử**
  - Chạy `flutter test test/features/resident/vehicle* test/features/resident/resident_meter* test/core/theme_and_color_guard_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `refactor(resident): phan ra man hinh xe va dong ho thanh cac widgets doc lap`

---

### Task 6: Phân Rã & Chuẩn Hóa Các Màn Hình Ban Quản Lý (>1.600 - 2.000 dòng)
**Files:**
- Create: `lib/features/management/widgets/home/management_kpi_overview_card.dart`
- Create: `lib/features/management/widgets/home/management_quick_dispatch_grid.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart` (2.002 dòng $\rightarrow$ < 500 dòng)
- Modify: `lib/features/management/screens/resident_management_screen.dart` (1.994 dòng)
- Modify: `lib/features/management/screens/apartment_management_screen.dart` (1.789 dòng)
- Modify: `lib/features/management/screens/management_meter_reading_screen.dart` (1.636 dòng)
- Modify: `test/core/theme_and_color_guard_test.dart`

- [x] **Step 1: Phân rã `management_home_screen.dart`**
  - Tách các khối KPI, Biểu đồ và Lưới tác vụ nhanh.
- [x] **Step 2: Phân rã các màn hình BQL còn lại**
  - Trích xuất component con sang `lib/features/management/widgets/`.
- [x] **Step 3: Chuẩn hóa Tokens & Mở rộng Guard Whitelist**
  - Loại bỏ màu và fontSize cứng, cập nhật whitelist guard test.
- [x] **Step 4: Chạy tests quản trị BQL**
  - Chạy `flutter test test/features/management/ test/core/theme_and_color_guard_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `refactor(management): phan ra 4 man hinh bql lon thanh modular widgets va chuan hoa tokens`

---

### Task 7: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức
- [x] **Step 1: Chạy kiểm tra tĩnh toàn bộ dự án**
  - Chạy `dart analyze lib test`. Đảm bảo `No issues found!`.
- [x] **Step 2: Chạy toàn bộ test suites**
  - Chạy `flutter test`. Đảm bảo 100% tests passed.
- [x] **Step 3: Cập nhật tài liệu & tri thức AST**
  - Chạy `graphify update .` để đồng bộ đồ thị kiến trúc codebase mới.
- [x] **Step 4: Báo cáo kết quả hoàn thành Giai đoạn 0**

