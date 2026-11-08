# Kế Hoạch Triển Khai: Cải Tiến Giao Diện Impeccable Taste & Chống Tràn Bố Cục (Anti-RenderFlex)

> **Dành cho Agentic Workers:** REQUIRED SUB-SKILL: Sử dụng `subagent-driven-development` hoặc `executing-plans` để thực thi kế hoạch này theo từng tác vụ. Các bước sử dụng cú pháp `- [ ]` để theo dõi tiến độ.

**Mục tiêu:** Nâng cấp toàn bộ hệ thống giao diện PKA-Home theo chuẩn thẩm mỹ **`pbakaus/impeccable`** (Slate & Sapphire, Layered Shadows, Micro-borders, loại bỏ khuôn mẫu AI slop) và giải quyết triệt để 100% lỗi `RenderFlex overflowed` trên Web Admin Dashboard và Mobile.

**Kiến trúc:** Triển khai theo phương pháp tiếp cận từ nền tảng (Design System First), nâng cấp các design tokens trong `AppTheme`, các component cơ sở `AppCard` và `StatCard`, sau đó chuẩn hóa responsive layout cho `LoginScreen` (Split-Screen Web), `ManagementHomeScreen` + `AdaptiveManagementScaffold` (Dynamic Responsive Grid), và `ResidentHomeScreen`.

**Công nghệ sử dụng:** Flutter 3.x, Flutter Riverpod, Google Fonts (Inter), Material 3, Flutter Test, Mocktail.

## Các Ràng Buộc Toàn Cục (Global Constraints)

- Tuân thủ nghiêm ngặt quy tắc dự án: 100% Tiếng Việt chuẩn mực ở tầng giao diện người dùng.
- Không phá vỡ bất kỳ test case nào hiện có (duy trì 500+ tests tự động pass 100%).
- `dart analyze lib test` phải đạt 0 errors, 0 warnings.
- Mọi thay đổi commit trực tiếp vào nhánh `main`.

---

### Nhiệm Vụ 1: Nâng Cấp Nền Tảng Design System (`AppTheme`, `AppCard`, `StatCard`)

**Tệp tin:**
- Sửa: `lib/core/theme/app_theme.dart`
- Sửa: `lib/core/widgets/app_card.dart`
- Sửa: `lib/features/management/widgets/stat_card.dart`
- Kiểm thử mới: `test/core/theme/app_theme_impeccable_test.dart`

**Giao diện:**
- Cung cấp: Bảng màu Slate & Sapphire Navy, hệ thống bóng đổ đa tầng `AppShadows`, gradient thương hiệu `AppGradients`, `AppCard` có viền mờ tinh tế và hover elevation, `StatCard` thích ứng Dark/Light Mode không hardcode `Colors.white`.

- [ ] **Bước 1: Viết test kiểm thử các tokens và hành vi mới**
  Tạo `test/core/theme/app_theme_impeccable_test.dart` kiểm tra tính hợp lệ của các màu sắc Modern Enterprise, `AppShadows`, và kiểm tra `StatCard` render đúng màu surface trong Dark Mode.

- [ ] **Bước 2: Chạy test để xác nhận test thất bại trước khi implement**
  `flutter test test/core/theme/app_theme_impeccable_test.dart`

- [ ] **Bước 3: Triển khai cập nhật `AppTheme`**
  - Bổ sung màu sắc Slate 50/900, Sapphire Blue (`#2563EB`).
  - Bổ sung `AppShadows.softSm`, `AppShadows.softMd`, `AppShadows.cardGlow`.
  - Cập nhật InputDecorationTheme, CardTheme mượt mà.

- [ ] **Bước 4: Triển khai nâng cấp `AppCard` và `StatCard`**
  - `AppCard`: viền mỏng mờ (`dividerColor.withOpacity(0.08)`), lớp bóng đổ mềm hai tầng.
  - `StatCard`: lấy màu từ `theme.colorScheme.surface`, viền từ theme, bảo vệ text bằng `Flexible` và `FittedBox`.

- [ ] **Bước 5: Chạy lại test và xác nhận pass**
  `flutter test test/core/theme/app_theme_impeccable_test.dart`

- [ ] **Bước 6: Commit**
  `git commit -m "feat(theme): nang cap design tokens impeccable taste va stat card dark mode"`

---

### Nhiệm Vụ 2: Tái Thiết Kế Màn Hình Đăng Nhập Split-Screen (`LoginScreen`)

**Tệp tin:**
- Sửa: `lib/features/auth/screens/login_screen.dart`
- Kiểm thử mới: `test/features/auth/login_screen_responsive_test.dart`

**Giao diện:**
- Cung cấp: Màn hình Login với bố cục Split-Screen 50/50 trên Web/Desktop ($\ge 900\text{dp}$): bên trái là Brand Showcase sang trọng, bên phải là Form đăng nhập thanh lịch; trên Mobile ($< 900\text{dp}$) là form nổi trung tâm an toàn chống tràn bàn phím.

- [ ] **Bước 1: Viết widget test kiểm thử bố cục responsive của LoginScreen**
  Tạo `test/features/auth/login_screen_responsive_test.dart`:
  - Test 1: Màn hình rộng 1200dp hiển thị đầy đủ Brand Showcase bên trái và Form đăng nhập bên phải.
  - Test 2: Màn hình hẹp 360dp hiển thị form gọn gàng, cuộn an toàn không phát sinh lỗi RenderFlex.

- [ ] **Bước 2: Chạy test xác nhận thất bại**
  `flutter test test/features/auth/login_screen_responsive_test.dart`

- [ ] **Bước 3: Triển khai Split-Screen trong `LoginScreen`**
  - Sử dụng `LayoutBuilder` kiểm tra `constraints.maxWidth >= 900`.
  - Xây dựng widget `_buildBrandHeroSide()` với gradient Deep Slate, logo phát sáng, slogan và 3 thẻ bảo chứng (Nghị định 13/2023, VietQR 2s, Sổ cái Append-Only).
  - Tinh chỉnh `_buildLoginFormSide()` trong card nổi tinh tế với viền Sapphire glow khi focus.
  - Bọc toàn bộ trong `SafeArea` và `SingleChildScrollView` chống tràn khi mở bàn phím ảo.

- [ ] **Bước 4: Chạy lại test và xác nhận pass**
  `flutter test test/features/auth/login_screen_responsive_test.dart`

- [ ] **Bước 5: Commit**
  `git commit -m "feat(auth): tai thiet ke login screen split screen tren web va responsive mobile"`

---

### Nhiệm Vụ 3: Khắc Phục Triệt Để RenderFlex & Nâng Cấp Web Admin Dashboard (`ManagementHomeScreen` & `AdaptiveManagementScaffold`)

**Tệp tin:**
- Sửa: `lib/core/widgets/adaptive_management_scaffold.dart`
- Sửa: `lib/features/management/screens/management_home_screen.dart`
- Kiểm thử mới: `test/features/management/management_home_responsive_test.dart`

**Giao diện:**
- Cung cấp:
  - `AdaptiveManagementScaffold`: Thẻ nhận diện tòa nhà Landmark Tower trên Sidebar, vạch indicator Sapphire Blue, khung nội dung giới hạn `maxWidth: 1600` chống dãn 4K.
  - `ManagementHomeScreen`: Thay thế toàn bộ `GridView.count` cứng bằng dynamic grid responsive theo `LayoutBuilder` (3 cột trên mobile hẹp, 4 cột trên tablet, 6–8 cột trên desktop), chống tràn 100% khi font chữ phóng to.

- [ ] **Bước 1: Viết test kiểm thử responsive cho Dashboard BQL**
  Tạo `test/features/management/management_home_responsive_test.dart` kiểm tra render thành công tại 320px (tiny mobile), 768px (tablet), 1440px (desktop) không ném ngoại lệ RenderFlex overflowed.

- [ ] **Bước 2: Chạy test xác nhận lỗi**
  `flutter test test/features/management/management_home_responsive_test.dart`

- [ ] **Bước 3: Nâng cấp `AdaptiveManagementScaffold`**
  - Thêm thẻ Tòa nhà hiện tại trên đỉnh Sidebar kèm chip "Đang hoạt động".
  - Bọc phần `body` trong `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1600), child: body))` chống dãn vô tận trên màn hình siêu rộng.

- [ ] **Bước 4: Nâng cấp `ManagementHomeScreen` chống RenderFlex**
  - Thay `GridView.count(crossAxisCount: 3, childAspectRatio: 1.05)` bằng `LayoutBuilder` tính toán số cột thông minh và `childAspectRatio` linh hoạt.
  - Tinh chỉnh `_buildQuickAction`: bọc label text trong `Flexible(child: Text(..., maxLines: 2, overflow: TextOverflow.ellipsis))`.
  - Thay thế `GridView.count(crossAxisCount: 2)` của StatCard bằng dynamic columns (2 cột mobile, 4 cột desktop).

- [ ] **Bước 5: Chạy lại test và xác nhận pass**
  `flutter test test/features/management/management_home_responsive_test.dart`

- [ ] **Bước 6: Commit**
  `git commit -m "feat(management): nang cap dashboard web responsive va chong tran bo cuc renderflex"`

---

### Nhiệm Vụ 4: Tinh Chỉnh Giao Diện Cư Dân Hiện Đại & An Toàn Bố Cục (`ResidentHomeScreen`)

**Tệp tin:**
- Sửa: `lib/features/resident/screens/resident_home_screen.dart`
- Kiểm thử: `test/features/resident/resident_home_responsive_test.dart`

- [ ] **Bước 1: Viết test kiểm tra an toàn bố cục màn hình Cư dân**
  Tạo `test/features/resident/resident_home_responsive_test.dart` kiểm tra không tràn khi font chữ phóng to 1.3x.

- [ ] **Bước 2: Chạy test xác nhận**
  `flutter test test/features/resident/resident_home_responsive_test.dart`

- [ ] **Bước 3: Tinh chỉnh `ResidentHomeScreen`**
  - Hero Card hóa đơn với gradient Sapphire, nút "Quét VietQR 1 chạm" nổi bật.
  - Ma trận tiện ích 4 nút thao tác nhanh bo tròn 16dp, text bảo vệ `Flexible` chống tràn.

- [ ] **Bước 4: Chạy test xác nhận pass**
  `flutter test test/features/resident/resident_home_responsive_test.dart`

- [ ] **Bước 5: Commit**
  `git commit -m "feat(resident): tinh chinh resident home card hoa don vietqr va chong tran chu"`

---

### Nhiệm Vụ 5: Nghiệm Thu Toàn Diện & Quality Gate

- [ ] **Bước 1: Chạy toàn bộ test suite dự án**
  `flutter test` (Đảm bảo 500+ tests pass 100%).

- [ ] **Bước 2: Chạy phân tích tĩnh**
  `dart analyze lib test` (Đảm bảo 0 issues, 0 warnings).

- [ ] **Bước 3: Commit hoàn tất**
  `git commit -m "chore(release): hoan tat cai tien UI impeccable taste va chong tran bo cuc renderflex"`

