# Kế Hoạch Triển Khai: Tự Cấp Lại Mật Khẩu Qua Email OTP (Self-Service Password Reset via Email OTP)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai tính năng tự cấp lại mật khẩu qua mã OTP 6 chữ số gửi qua Thư điện tử (Email OTP), bảo mật chống account enumeration, kiểm soát Auth Guard và xử lý phiên recovery an toàn.

**Architecture:** Mở rộng `AuthRepository` gọi các API native của Supabase Auth (`resetPasswordForEmail`, `verifyOTP` với `OtpType.recovery`, `updateUser`). Tách biệt 3 màn hình độc lập trong `GoRouter` (`/forgot-password`, `/verify-otp`, `/reset-password`), tạo widget `OtpInputBoxes` 6 ô số tự động nhảy con trỏ và tự động nhận diện clipboard paste.

**Tech Stack:** Flutter (Dart 3.x), Riverpod, GoRouter, Supabase Auth.

## Global Constraints

- **Language:** 100% Tiếng Việt chuẩn mực trên mọi màn hình, nhãn dán, và thông báo lỗi.
- **Security:** Anti-account enumeration (thông báo trung tính khi nhập email), xử lý lỗi 429 Rate Limiting, không để rò rỉ session recovery ra trang chủ.
- **UI/UX Consistency:** Sử dụng `AppCard`, `AppTheme` bo góc 12px, font Inter, hỗ trợ cả Light/Dark theme.
- **TDD:** Mọi task đều viết test trước hoặc đi kèm unit/widget test độc lập.

---

### Task 1: Nâng Cấp `AuthRepository` (Send OTP, Verify OTP Recovery, Update Password) & Unit Tests

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `test/data/repositories/auth_repository_test.dart`

**Interfaces:**
- `sendPasswordResetOtp(String email) -> Future<void>`
- `verifyPasswordResetOtp({required String email, required String token}) -> Future<AuthResponse>`
- `updatePassword(String newPassword) -> Future<UserResponse>`

- [x] **Step 1: Viết failing test trong `test/data/repositories/auth_repository_test.dart`**
- [x] **Step 2: Chạy test xác nhận FAIL**
- [x] **Step 3: Hiện thực các phương thức trong `lib/data/repositories/auth_repository.dart`**
- [x] **Step 4: Chạy test xác nhận PASS**
- [x] **Step 5: Commit vào git**

```bash
git add lib/data/repositories/auth_repository.dart test/data/repositories/auth_repository_test.dart
git commit -m "feat: bổ sung sendPasswordResetOtp và verifyPasswordResetOtp vào AuthRepository"
```

---

### Task 2: Cấu Hình Route & Auth Guard trong GoRouter

**Files:**
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**
- `AppRoutes.forgotPassword = '/forgot-password'`
- `AppRoutes.verifyOtp = '/verify-otp'`
- `AppRoutes.resetPassword = '/reset-password'`

- [x] **Step 1: Khai báo 3 hằng số route mới trong `AppRoutes`**
- [x] **Step 2: Cập nhật hàm `redirect` trong `app_router.dart`:**
  - Cho phép truy cập công khai vào `/forgot-password`, `/verify-otp`.
  - Không tự động chuyển hướng người dùng ra khỏi `/reset-password` khi đang có Recovery Session.
- [x] **Step 3: Đăng ký 3 GoRoute mới với hiệu ứng chuyển trang `slideFromRight`**
- [x] **Step 4: Kiểm tra phân tích `dart analyze`**
- [x] **Step 5: Commit vào git**

```bash
git add lib/core/router/route_names.dart lib/core/router/app_router.dart
git commit -m "feat: cấu hình route và bypass Auth Guard cho luồng OTP quên mật khẩu"
```

---

### Task 3: Widget Nhập 6 Ô Số OTP (`OtpInputBoxes`) & Widget Test

**Files:**
- Create: `lib/features/auth/widgets/otp_input_boxes.dart`
- Create: `test/features/auth/widgets/otp_input_boxes_test.dart`

**Interfaces:**
- `OtpInputBoxes`:
  - `length`: 6
  - `onCompleted`: `ValueChanged<String>`
  - `onChanged`: `ValueChanged<String>`
  - Hỗ trợ tự động nhảy con trỏ khi gõ số, tự động lùi về ô trước khi bấm Backspace, và tự động tách chuỗi khi dán từ Clipboard.

- [x] **Step 1: Viết failing widget test cho `OtpInputBoxes`**
- [x] **Step 2: Chạy test xác nhận FAIL**
- [x] **Step 3: Hiện thực widget `OtpInputBoxes`**
- [x] **Step 4: Chạy test xác nhận PASS**
- [x] **Step 5: Commit vào git**

```bash
git add lib/features/auth/widgets/otp_input_boxes.dart test/features/auth/widgets/otp_input_boxes_test.dart
git commit -m "feat: tạo component OtpInputBoxes 6 ô số tự động chuyển con trỏ và dán clipboard"
```

---

### Task 4: Xây Dựng Các Màn Hình Giao Diện (`ForgotPasswordScreen`, `VerifyOtpScreen`, `ResetPasswordScreen`, `LoginScreen`)

**Files:**
- Create: `lib/features/auth/screens/forgot_password_screen.dart`
- Create: `lib/features/auth/screens/verify_otp_screen.dart`
- Create: `lib/features/auth/screens/reset_password_screen.dart`
- Modify: `lib/features/auth/screens/login_screen.dart`

- [x] **Step 1: Tạo `ForgotPasswordScreen`:**
  - Ô nhập email chuẩn, validate regex.
  - Thông báo an toàn chống rò rỉ tài khoản (Anti-account enumeration).
  - Nút "Gửi mã xác thực" gọi `sendPasswordResetOtp(email)` và chuyển sang `AppRoutes.verifyOtp`.
- [x] **Step 2: Tạo `VerifyOtpScreen`:**
  - Tích hợp `OtpInputBoxes`.
  - Bộ đếm 60 giây gửi lại mã (Timer countdown).
  - Bắt lỗi 429 và mã OTP hết hạn.
  - Xác thực qua `verifyPasswordResetOtp` và chuyển sang `AppRoutes.resetPassword`.
- [x] **Step 3: Tạo `ResetPasswordScreen`:**
  - Kiểm tra có session hợp lệ hay không; nếu không có session thì yêu cầu quay lại từ bước 1.
  - Ô nhập mật khẩu mới và xác nhận mật khẩu (tối thiểu 6 ký tự, có nút ẩn/hiện mắt).
  - Gọi `updatePassword(newPassword)`.
  - Đăng xuất phiên tạm và chuyển về `AppRoutes.login` kèm SnackBar xanh thành công.
- [x] **Step 4: Cập nhật `LoginScreen`:**
  - Đổi nút Text "Quên mật khẩu?" dẫn thẳng tới `context.push(AppRoutes.forgotPassword)`.
- [x] **Step 5: Commit vào git**

```bash
git add lib/features/auth/screens/
git commit -m "feat: hoàn thiện giao diện 3 màn hình khôi phục mật khẩu qua Email OTP"
```

---

### Task 5: Rà Soát Toàn Diện, Phân Tích & Xác Minh (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [x] **Step 1: Chạy `dart analyze` đảm bảo không có cảnh báo nào**
- [x] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [x] **Step 3: Báo cáo kết quả và tích hợp nhánh hoàn tất**
