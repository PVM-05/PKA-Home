# Thiết Kế Kỹ Thuật: Hoàn Thiện Nền Tảng Giao Diện UI 2026 (Giai Đoạn 0 - Foundation Hardening)

- **Mã tài liệu**: `SPEC-2026-11-17-UI-2026-PHASE-0-FOUNDATION`
- **Ngày cập nhật**: 17/11/2026
- **Trạng thái**: Bản đặc tả kỹ thuật (Draft for Review)
- **Định hướng sản phẩm**: B2B SaaS PropTech Commercial Production (Vivona)
- **Phương pháp thực thi**: Phương án 1 — Cuốn chiếu dọc Module hóa (Vertical Slice Rollout)

---

## 1. Bối Cảnh & Thực Tế Flutter Năm 2026

### 1.1. Thực tế Material 3 Expressive
- Thư viện Material trong Flutter SDK đã chính thức đóng băng từ bản Flutter 3.44.
- Nhánh phát triển Expressive chuyển sang package độc lập `package:material_ui` (hiện ở bản v1.4.0 mới chỉ có cờ `StyleVariant`, chưa có sẵn các component Expressive hoàn chỉnh).
- Các gói cộng đồng (`expressive_ui_kit`, `material_3_expressive`) chưa được kiểm chứng, rủi ro breaking change cao và không đáp ứng tiêu chuẩn phần mềm doanh nghiệp B2B SaaS của Vivona.
- **Quyết định kiến trúc**: Áp dụng các nguyên tắc Expressive (hình khối bo góc đa dạng, phân tầng thị giác đậm nét, chuyển động lò xo) bằng **chính hệ thống Design Tokens & Component Themes nội tại** của Vivona.

### 1.2. Hiện trạng & Lỗ hổng kỹ thuật (Baseline Audit)
1. **Thiếu Tokens Chuẩn Hóa**: Chưa có class token chuyên biệt cho khoảng cách (`AppSpacing`) và bán kính bo góc (`AppRadius`). Hiện tại có hơn 230 vị trí padding viết tay và bán kính bo góc (8, 12, 16) rải rác.
2. **TextTheme Khiếm Khuyết**: `AppTheme` mới chỉ override 5/15 style (`headlineLarge`, `headlineMedium`, `titleLarge`, `bodyMedium`, `labelSmall`). 10 styles còn lại vẫn là giá trị mặc định của framework.
3. **Thiếu Component Themes Cốt Lõi**: Chưa cấu hình theme đồng bộ cho `FilledButton`, `Chip`, `Dialog`, `BottomSheet`, `Switch`, `FloatingActionButton`.
4. **Nợ Kỹ Thuật Mã Cứng**: Còn 1.206 vị trí `fontSize` và 59 mã màu cứng (`Color(0x...)`). Guard test (`theme_and_color_guard_test.dart`) mới chỉ bảo vệ 2 module (Hóa đơn và Sự cố). Màn hình Đăng nhập (Auth) và Trang chủ vẫn có mã màu cứng.
5. **Màn Hình Nguyên Khối Quá Lớn**: Có 7 màn hình vượt ngưỡng 1.500 dòng (lớn nhất là `management_home_screen` 2.002 dòng, `resident_management_screen` 1.994 dòng, `vehicle_management_screen` 1.914 dòng, `resident_meter_reading_screen` 1.805 dòng,...).

---

## 2. Kiến Trúc Design Tokens 2026 (Core System)

### 2.1. Token Khoảng Cách & Bố Cục (`AppSpacing`)
Tạo mới file: `lib/core/theme/app_spacing.dart`

```dart
class AppSpacing {
  const AppSpacing._();

  // Kích thước tỷ lệ 4-8-12-16-24-32
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  // EdgeInsets Tiện ích Toàn diện (Padding Helpers)
  static const EdgeInsets p4 = EdgeInsets.all(xs);
  static const EdgeInsets p8 = EdgeInsets.all(sm);
  static const EdgeInsets p12 = EdgeInsets.all(md);
  static const EdgeInsets p16 = EdgeInsets.all(lg);
  static const EdgeInsets p20 = EdgeInsets.all(xl);
  static const EdgeInsets p24 = EdgeInsets.all(xxl);
  static const EdgeInsets p32 = EdgeInsets.all(xxxl);

  static const EdgeInsets px8 = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets px16 = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets px24 = EdgeInsets.symmetric(horizontal: xxl);

  static const EdgeInsets py4 = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets py8 = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets py12 = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets py16 = EdgeInsets.symmetric(vertical: lg);

  // Khoảng đệm Widget (SizedBox Spacers)
  static const SizedBox h4 = SizedBox(height: xs);
  static const SizedBox h8 = SizedBox(height: sm);
  static const SizedBox h12 = SizedBox(height: md);
  static const SizedBox h16 = SizedBox(height: lg);
  static const SizedBox h20 = SizedBox(height: xl);
  static const SizedBox h24 = SizedBox(height: xxl);
  static const SizedBox h32 = SizedBox(height: xxxl);

  static const SizedBox w4 = SizedBox(width: xs);
  static const SizedBox w8 = SizedBox(width: sm);
  static const SizedBox w12 = SizedBox(width: md);
  static const SizedBox w16 = SizedBox(width: lg);
  static const SizedBox w20 = SizedBox(width: xl);
  static const SizedBox w24 = SizedBox(width: xxl);
  static const SizedBox w32 = SizedBox(width: xxxl);
}
```

### 2.2. Token Bán Kính Bo Góc & Hình Khối Expressive (`AppRadius`)
Tạo mới file: `lib/core/theme/app_radius.dart`

```dart
class AppRadius {
  const AppRadius._();

  static const double xsValue = 4.0;
  static const double smValue = 8.0;
  static const double mdValue = 12.0;
  static const double lgValue = 16.0;
  static const double xlValue = 24.0;
  static const double xxlValue = 32.0;
  static const double fullValue = 999.0;

  static const Radius radXs = Radius.circular(xsValue);
  static const Radius radSm = Radius.circular(smValue);
  static const Radius radMd = Radius.circular(mdValue);
  static const Radius radLg = Radius.circular(lgValue);
  static const Radius radXl = Radius.circular(xlValue);
  static const Radius radFull = Radius.circular(fullValue);

  static final BorderRadius rXs = BorderRadius.circular(xsValue);
  static final BorderRadius rSm = BorderRadius.circular(smValue);
  static final BorderRadius rMd = BorderRadius.circular(mdValue);
  static final BorderRadius rLg = BorderRadius.circular(lgValue);
  static final BorderRadius rXl = BorderRadius.circular(xlValue);
  static final BorderRadius rXxl = BorderRadius.circular(xxlValue);
  static final BorderRadius rFull = BorderRadius.circular(fullValue);

  // Bo góc Modal BottomSheet (chỉ bo góc trên)
  static const BorderRadius bottomSheet = BorderRadius.vertical(top: radXl);

  // Shapes cho Buttons và Cards
  static final RoundedRectangleBorder shapeSm = RoundedRectangleBorder(borderRadius: rSm);
  static final RoundedRectangleBorder shapeMd = RoundedRectangleBorder(borderRadius: rMd);
  static final RoundedRectangleBorder shapeLg = RoundedRectangleBorder(borderRadius: rLg);
  static final RoundedRectangleBorder shapeXl = RoundedRectangleBorder(borderRadius: rXl);
  static final RoundedRectangleBorder shapeFull = RoundedRectangleBorder(borderRadius: rFull);
}
```

### 2.3. Hoàn Thiện 15/15 Kiểu Chữ (`TextTheme`)
Bổ sung đầy đủ 15 style theo tiêu chuẩn Material 3 kết hợp Google Fonts Inter:
- `displayLarge`: 57pt, w400
- `displayMedium`: 45pt, w400
- `displaySmall`: 36pt, w400
- `headlineLarge`: 32pt, w600
- `headlineMedium`: 28pt, w600
- `headlineSmall`: 24pt, w600
- `titleLarge`: 22pt, w600
- `titleMedium`: 16pt, w600
- `titleSmall`: 14pt, w600
- `bodyLarge`: 16pt, w400
- `bodyMedium`: 14pt, w400
- `bodySmall`: 12pt, w400
- `labelLarge`: 14pt, w500
- `labelMedium`: 12pt, w500
- `labelSmall`: 11pt, w500

Đồng bộ nhất quán trên cả `lightTheme` và `darkTheme`, tương ứng với bộ tiện ích mở rộng `context.titleLarge`, `context.bodyMedium`,... trong `AppTypographyExtension`.

### 2.4. Bổ Sung Component Themes Còn Thiếu Vào `AppTheme`
1. `filledButtonTheme`: Khối bo góc `AppRadius.rMd`, padding `AppSpacing.px24 + AppSpacing.py16`, font `labelLarge`.
2. `chipTheme`: Hình khối `AppRadius.rSm`, padding chuẩn, màu nền trung tính, viền Slate nhạt `border`.
3. `dialogTheme`: Surface card, bo góc `AppRadius.rLg`, không viền gắt, shadow mịn `AppShadows.softMd`.
4. `bottomSheetTheme`: Bo góc trên `AppRadius.bottomSheet`, modal nền trong suốt kèm `showDragHandle: true`.
5. `switchTheme`: Màu thumb/track đồng bộ bảng màu Sapphire `AppTheme.primary`.
6. `floatingActionButtonTheme`: Khối bo góc `AppRadius.rLg`, màu sapphire rực rỡ, icon trắng.
7. `navigationBarTheme`: Đồng bộ màu nền, độ cao 65dp và `indicatorColor` trên cả `lightTheme` và `darkTheme`.

---

## 3. Lộ Trình Cuốn Chiếu Theo Module Dọc (Vertical Slice Rollout)

### Module 1: Định Danh & Xác Thực (Auth Module)
- **Mục tiêu**: Làm sạch màn hình đầu tiên người dùng nhìn thấy, xóa sổ 6 màu cứng.
- **Phạm vi file**:
  - `lib/features/auth/screens/login_screen.dart`
  - `lib/features/auth/screens/register_screen.dart`
  - `lib/features/auth/screens/first_time_activation_screen.dart`
  - `lib/features/auth/screens/forgot_password_screen.dart`
- **Hành động**:
  - Thay thế toàn bộ `fontSize:` cứng bằng `context.textTheme` / `AppTypography`.
  - Thay thế toàn bộ `Color(0x...)` bằng `AppTheme.primary`, `AppTheme.border`, `AppTheme.textSecondary`.
  - Thay thế padding và radius bằng `AppSpacing` và `AppRadius`.
  - Thêm cả 4 file vào whitelist của `test/core/theme_and_color_guard_test.dart`.

### Module 2: Trang Chủ Cư Dân & Hồ Sơ (Resident Home & Profile)
- **Mục tiêu**: Chuẩn hóa màn hình trung tâm, phân rã `resident_home_screen.dart` (1.247 dòng) và `resident_profile_screen.dart` (1.078 dòng).
- **Phân rã Component Độc Lập**:
  - `ResidentHomeHeaderWidget`: Hiển thị lời chào, căn hộ đang chọn và chuông thông báo.
  - `ResidentHomeQuickActionsGrid`: Lưới 6-8 nút thao tác nhanh (Hóa đơn, Dịch vụ, Xe, Báo hỏng, Biểu quyết,...).
  - `ResidentHomeUpcomingInvoiceCard`: Thẻ nổi bật hóa đơn đến hạn chuẩn Design System.
  - `ResidentHomeUrgentAnnouncementCard`: Banner thông báo khẩn cấp (nếu có).
  - `ResidentHomeRecentIssuesWidget`: Danh sách tiến độ sự cố đang mở.
- **Hành động**:
  - Quét sạch `fontSize:` và `Color(0x...)`.
  - Thay thế spinner `CircularProgressIndicator` thô bằng `AppSkeletonShimmer`.
  - Thêm `resident_home_screen.dart` và `resident_profile_screen.dart` vào guard whitelist.

### Module 3: Công Tơ Điện Nước & Quản Lý Phương Tiện (Meter & Vehicle)
- **Mục tiêu**: Phân rã 2 màn hình lớn nhất phía cư dân (>1.800 dòng).
  - `vehicle_management_screen.dart` (1.914 dòng): Phân rã thành Thẻ xe chính chủ, Modal đăng ký xe mới, Danh sách thẻ vé vãng lai.
  - `resident_meter_reading_screen.dart` (1.805 dòng): Phân rã thành Form quét OCR, Thẻ lịch sử chỉ số, Biểu đồ tiêu thụ.
- **Hành động**: Đưa cả 2 màn hình vào guard whitelist sau khi làm sạch tokens.

### Module 4: Phân Hệ Quản Trị BQL (Management Screens)
- **Mục tiêu**: Phân rã các màn hình BQL nguyên khối (>1.600 - 2.000 dòng):
  - `management_home_screen.dart` (2.002 dòng)
  - `resident_management_screen.dart` (1.994 dòng)
  - `apartment_management_screen.dart` (1.789 dòng)
  - `management_meter_reading_screen.dart` (1.636 dòng)
- **Hành động**: Tách thành các widget con độc lập tại `lib/features/management/widgets/` và cập nhật whitelist kiểm thử.

---

## 4. Chốt Chặn Kiểm Thử & Chống Hồi Quy (Quality Gates)

1. **Guardrail Tests**:
   - Mở rộng whitelist trong `test/core/theme_and_color_guard_test.dart` sau mỗi module hoàn tất.
   - Thử nghiệm quét thêm `BorderRadius.circular` và `EdgeInsets.all` cứng để kiểm soát nợ kỹ thuật.
2. **Design System Widget Tests**:
   - Viết test kiểm tra tính đầy đủ của 15 styles trong `TextTheme`.
   - Viết test kiểm tra các Component Themes của `AppTheme` (đảm bảo không bị null hoặc thiếu cấu hình ở cả Light và Dark mode).
3. **Static Analysis Zero-Issue**:
   - `dart analyze lib test` phải đạt tuyệt đối `No issues found!`.
4. **100% Tests Pass**:
   - Toàn bộ test suites hiện tại phải vượt qua kiểm tra mà không có bất kỳ regression nào.

---

## 5. Kế Hoạch Chuyển Tiếp

Sau khi tài liệu đặc tả này được rà soát và xác nhận:
1. Tạo Kế hoạch Triển khai Chi tiết (`docs/superpowers/plans/2026-11-17-ui-2026-phase-0-foundation-plan.md`).
2. Triển khai từng task theo mô hình TDD và kiểm tra chốt chặn CI.
