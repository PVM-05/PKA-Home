# Cổng Đăng Nhập & Kích Hoạt Onboarding Impeccable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Cổng Đăng Nhập & Kích Hoạt Onboarding (`OtpInputBoxes`, `ResidentActivationScreen`, `LoginScreen`, `ForgotPasswordScreen`) theo tiêu chuẩn thiết kế `pbakaus/impeccable`, cam đoan chống tràn bố cục 100% (**Anti-RenderFlex Guarantee**) trên cả Mobile hẹp (320dp x 600dp, Text zoom 1.3x) và Web Enterprise Desktop ($\ge 900$dp).

**Architecture:** Áp dụng Feature-First kiến trúc Flutter, bọc `LayoutBuilder` cho các widget co giãn linh hoạt (`OtpInputBoxes`), thiết kế Split-Screen responsive đa cột cho Web/Desktop với thẻ Hero Brand cao cấp, và cuộn an toàn (`SingleChildScrollView` + `IntrinsicHeight` / `FittedBox`) trên Mobile. Quản lý trạng thái qua Riverpod `residentActivationProvider` và `authProvider`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod, GoRouter, GoogleFonts / AppTheme, Flutter Test.

## Global Constraints

- **Toàn bộ commit trực tiếp vào nhánh `main`**: Tuyệt đối không tạo nhánh phụ hay worktree ngoài `main`.
- **Anti-RenderFlex Guarantee**: 0 lỗi `RenderFlex overflowed` trên mọi độ phân giải từ 320dp x 600dp (kèm text scale 1.3x) đến Desktop 1920dp x 1080dp.
- **Tiêu chuẩn B2B SaaS**: 100% tiếng Việt chuẩn mực, không hardcode mã màu, sử dụng `AppTheme` và `AppCard`.
- **Chất lượng mã nguồn**: 0 lỗi / 0 cảnh báo khi chạy `dart analyze lib test`.

---

### Task 1: Nâng cấp `OtpInputBoxes` Chống Tràn Bố Cục Bằng Tỷ Lệ Co Giãn Động

**Files:**
- Modify: `lib/features/auth/widgets/otp_input_boxes.dart`
- Test: `test/features/auth/widgets/otp_input_boxes_test.dart`
- Create: `test/features/auth/widgets/otp_input_boxes_responsive_test.dart`

**Interfaces:**
- Consumes: `OtpInputBoxes({Key? key, int length = 6, required ValueChanged<String> onCompleted, ValueChanged<String>? onChanged})`
- Produces: `OtpInputBoxes` tự động tính toán `boxWidth` thích ứng từ 32dp đến 48dp qua `LayoutBuilder`, không bị tràn khi card padding 24dp trên bề rộng 260dp-320dp.

- [ ] **Step 1: Viết test kiểm tra khả năng co giãn chống tràn của `OtpInputBoxes`**
  Tạo `test/features/auth/widgets/otp_input_boxes_responsive_test.dart` kiểm tra `OtpInputBoxes` trên container hẹp 260dp và 272dp (tương đương 320dp trừ padding), đảm bảo 6 ô hiển thị trọn vẹn và không ném ngoại lệ RenderFlex overflow.
- [ ] **Step 2: Chạy test để xác nhận test thất bại với mã nguồn hiện tại**
  Chạy `flutter test test/features/auth/widgets/otp_input_boxes_responsive_test.dart` (kết quả mong đợi: tràn 44px hoặc thất bại).
- [ ] **Step 3: Cập nhật `OtpInputBoxes` với `LayoutBuilder` và dynamic box size**
  Sửa `lib/features/auth/widgets/otp_input_boxes.dart`:
  - Dùng `LayoutBuilder` tính `availableWidth = constraints.maxWidth`.
  - Tính `spacing = (availableWidth < 300) ? 4.0 : 8.0`.
  - Tính `boxWidth = ((availableWidth - (widget.length - 1) * spacing) / widget.length).clamp(32.0, 48.0)`.
  - Tính `fontSize = (boxWidth * 0.46).clamp(16.0, 22.0)`.
- [ ] **Step 4: Chạy lại toàn bộ test widget OTP**
  Chạy `flutter test test/features/auth/widgets/` đảm bảo tất cả test (cả chức năng lẫn responsive) đều pass 100%.
- [ ] **Step 5: Commit thay đổi Task 1 vào `main`**
  `git commit -m "feat(auth): nang cap otp input boxes tu dong co gian chong tran bo cuc"`

---

### Task 2: Nâng cấp `ResidentActivationScreen` Responsive Đa Nền Tảng (Mobile 320dp & Desktop 2 Cột)

**Files:**
- Modify: `lib/features/auth/screens/resident_activation_screen.dart`
- Create: `test/features/auth/screens/resident_activation_responsive_test.dart`

**Interfaces:**
- Consumes: `residentActivationProvider`, `ResidentActivationState`, `AppTheme`, `AppCard`
- Produces: `ResidentActivationScreen` thích ứng:
  - Mobile (< 900dp): Padding thu gọn 16dp khi width < 360dp, thanh tiến trình bọc `FittedBox`/`Flexible` chống tràn nhãn text khi zoom 1.3x.
  - Desktop ($\ge 900$dp): Bố cục Split-Screen 2 cột với Hero Card đặc quyền cư dân số PKA-Home bên trái và Form 4 bước bên phải, giới hạn `maxWidth: 1100`.

- [ ] **Step 1: Viết test kịch bản Responsive cho `ResidentActivationScreen`**
  Tạo `test/features/auth/screens/resident_activation_responsive_test.dart`:
  - Test 1: Render trên Mobile cực hẹp (320dp x 600dp, Text Scale 1.3x) không gặp lỗi RenderFlex overflow ở cả 4 bước.
  - Test 2: Render trên Desktop Web (1200dp x 800dp) hiển thị đầy đủ Hero Card và Form 2 cột.
- [ ] **Step 2: Chạy test để xác nhận trạng thái hiện tại**
  Chạy `flutter test test/features/auth/screens/resident_activation_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `ResidentActivationScreen` với kiến trúc Responsive Impeccable**
  - Sửa `_buildStepIndicator`: bọc nhãn text mỗi bước trong `FittedBox(fit: BoxFit.scaleDown, child: Text(...))` và bọc cấu trúc trong `Expanded` hoặc tỷ lệ co giãn an toàn.
  - Sửa hàm `build`:
    - Dùng `LayoutBuilder` phân biệt `isDesktop = constraints.maxWidth >= 900`.
    - Mobile: Padding 16dp nếu width < 360dp, 24dp nếu width $\ge 360$dp.
    - Desktop: Split layout 2 cột với Hero Showcase (giới thiệu lợi ích số hóa, bảo mật Napas VietQR, SLA sửa chữa) và Form xử lý 4 bước.
- [ ] **Step 4: Chạy kiểm thử toàn bộ activation screen**
  Chạy `flutter test test/features/auth/screens/` để đảm bảo luồng nghiệp vụ 4 bước và responsive đều pass 100%.
- [ ] **Step 5: Commit thay đổi Task 2 vào `main`**
  `git commit -m "feat(auth): nang cap resident activation screen responsive da cot va chong tran 4 buoc"`

---

### Task 3: Nâng cấp `LoginScreen` & `ForgotPasswordScreen` Chống Tràn Chiều Dọc Desktop & Nút Mobile

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `lib/features/auth/screens/forgot_password_screen.dart`
- Test: `test/features/auth/login_screen_responsive_test.dart`
- Create: `test/features/auth/screens/forgot_password_responsive_test.dart`

**Interfaces:**
- Consumes: `authProvider`, `mfaServiceProvider`, `AppTheme`, `AppCard`
- Produces:
  - `LoginScreen`: Cột Hero Desktop được bọc `SingleChildScrollView` + `IntrinsicHeight` chống tràn khi chiều cao màn hình hạn chế (< 768px). Nút "Kích hoạt tài khoản lần đầu" bọc nhãn trong `FittedBox` chống tràn khi text zoom 1.3x trên 320dp.
  - `ForgotPasswordScreen`: Responsive padding (16dp trên < 360dp) và `ConstrainedBox(maxWidth: 440)`.

- [ ] **Step 1: Viết test bổ sung cho `LoginScreen` & `ForgotPasswordScreen`**
  - Cập nhật `test/features/auth/login_screen_responsive_test.dart` bổ sung case: Desktop chiều cao thấp (1024dp x 600dp) không tràn dọc; Mobile 320dp text scale 1.3x không tràn ngang nút bấm.
  - Tạo `test/features/auth/screens/forgot_password_responsive_test.dart` kiểm tra kích thước 320dp text scale 1.3x.
- [ ] **Step 2: Chạy test để kiểm tra các điểm có thể tràn**
  Chạy `flutter test test/features/auth/login_screen_responsive_test.dart`.
- [ ] **Step 3: Cập nhật `LoginScreen` và `ForgotPasswordScreen`**
  - `login_screen.dart`: Bọc Hero Column trong `SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: IntrinsicHeight(child: Column(...))))`. Nút "Kích hoạt tài khoản lần đầu" bọc text trong `Flexible(child: FittedBox(child: Text(...)))`.
  - `forgot_password_screen.dart`: Responsive padding 16dp khi width < 360dp, căn giữa trong `ConstrainedBox(maxWidth: 440)`.
- [ ] **Step 4: Chạy kiểm thử toàn bộ test auth**
  Chạy `flutter test test/features/auth/` xác nhận toàn bộ test pass.
- [ ] **Step 5: Commit thay đổi Task 3 vào `main`**
  `git commit -m "feat(auth): nang cap login va forgot password screen chong tran doc va ngang"`

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống

**Files:**
- Verify: Toàn bộ codebase `lib/` và `test/`
- Update: Knowledge Graph qua `graphify update .`

- [ ] **Step 1: Chạy toàn bộ test suite của phân hệ Auth**
  Chạy `flutter test test/features/auth/` đảm bảo 100% test pass.
- [ ] **Step 2: Chạy static analysis toàn dự án**
  Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- [ ] **Step 3: Cập nhật Knowledge Graph**
  Chạy `graphify update .` đồng bộ kiến trúc dự án.
- [ ] **Step 4: Commit tài liệu hoàn thành và tri thức hệ thống vào `main`**
  `git commit -m "docs: hoan thanh cai tien giao dien auth va onboarding theo chuan impeccable"`
