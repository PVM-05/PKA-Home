# Đặc Tả Thiết Kế: Tự Cấp Lại Mật Khẩu Qua Email OTP (Self-Service Password Reset via Email OTP)

**Mã tài liệu:** `SPEC-2026-10-04-AUTH-RESET-OTP`  
**Ngày lập:** 04/10/2026 (Bản sửa đổi bổ sung bảo mật & kiến trúc session)  
**Trạng thái:** Đã phê duyệt (Approved)  
**Phạm vi:** Xác thực người dùng (Auth) — Cư dân & Ban quản lý  

---

## 1. Mục Tiêu Nghiệp Vụ

Khắc phục hạn chế của cơ chế cũ (yêu cầu cư dân phải liên hệ trực tiếp với Ban Quản Lý hoặc gọi hotline để xin cấp lại mật khẩu). Thay vào đó, cung cấp giải pháp **tự phục vụ (Self-service) 24/7** thông qua luồng xác thực mã OTP 6 chữ số gửi qua Thư điện tử (Email OTP), bảo mật cao, không phát sinh chi phí SMS và hoàn toàn tích hợp vào Supabase Auth.

---

## 2. Kiến Trúc Luồng Nghiệp Vụ & Điều Hướng (Navigation Flow)

```
[Màn hình Đăng Nhập] 
       │ (Bấm "Quên mật khẩu?")
       ▼
[1. ForgotPasswordScreen (/forgot-password)]
  - Nhập Email tài khoản
  - Gửi mã OTP qua email (resetPasswordForEmail)
  - Thông báo trung tính (Anti-account enumeration): "Nếu email tồn tại, mã OTP sẽ được gửi..."
       │ (Thành công -> Chuyển sang Bước 2 kèm email)
       ▼
[2. VerifyOtpScreen (/verify-otp)]
  - 6 ô số nhập OTP riêng biệt, tự động chuyển con trỏ, tự động dán từ clipboard
  - Đếm ngược 60 giây gửi lại mã (xử lý lỗi Rate-limit 429)
  - Xác thực qua Supabase verifyOTP (type: OtpType.recovery)
       │ (Hợp lệ -> Supabase cấp Recovery Session, gắn cờ isRecoveryMode = true)
       ▼
[3. ResetPasswordScreen (/reset-password)]
  - Auth Guard nhận diện Recovery Session: KHÔNG tự động đá về Trang chủ
  - Nhập Mật khẩu mới & Xác nhận mật khẩu mới (kiểm tra chuẩn mật khẩu)
  - Cập nhật mật khẩu qua updateUser(password: newPassword)
       │ (Thành công -> SignOut session tạm và chuyển về Login)
       ▼
[Điều hướng về Màn hình Đăng nhập với thông báo thành công xanh]
```

---

## 3. Chi Tiết Kỹ Thuật & Giải Quyết Các Vấn Đề Trọng Yếu

### 3.1. Cấu Hình Supabase Email Template (Hiển thị Token OTP thay vì Magic Link)
Trong Supabase Dashboard: **Authentication -> Email Templates -> Reset Password**:
* Mặc định template Supabase chứa link `<a href="{{ .ConfirmationURL }}">Reset Password</a>`.
* Cần bổ sung/chỉnh sửa nội dung email để hiển thị rõ ràng mã OTP 6 số:
```html
<h2>Mã xác thực đặt lại mật khẩu PKA-Home</h2>
<p>Mã OTP của bạn là: <strong style="font-size: 24px; letter-spacing: 4px;">{{ .Token }}</strong></p>
<p>Mã này có hiệu lực trong vòng 60 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>
```

### 3.2. Ngăn Ngừa Dò Tìm Tài Khoản (Anti-Account Enumeration)
Tại màn hình `ForgotPasswordScreen`:
* Bất kể email có tồn tại trong hệ thống hay không, giao diện luôn hiển thị thông báo an toàn:
  > *"Nếu địa chỉ thư điện tử này đã được đăng ký trên hệ thống, bạn sẽ nhận được mã OTP xác thực trong vài phút. Vui lòng kiểm tra hộp thư (kể cả mục Spam/Thư rác)."*
* Không ném ra thông báo lỗi chi tiết dạng "User not found" để tránh kẻ xấu dò quét danh sách email cư dân.

### 3.3. Xử Lý Auth Guard & Phiên Khôi Phục (Recovery Session Guard)
**Vấn đề:** Khi `verifyOTP(type: OtpType.recovery)` thành công, Supabase cấp một Auth Session tạm thời. Nếu Auth Guard thấy `isLoggedIn == true`, nó sẽ tự động redirect cư dân về `/resident` hoặc `/management`, khiến cư dân bị đá văng khỏi màn hình đặt lại mật khẩu.

**Giải pháp:**
Trong `lib/core/router/app_router.dart`:
1. Phân loại route:
   ```dart
   final isAuthRoute = state.matchedLocation == AppRoutes.login ||
       state.matchedLocation == AppRoutes.register ||
       state.matchedLocation == AppRoutes.forgotPassword ||
       state.matchedLocation == AppRoutes.verifyOtp;

   final isResetPasswordRoute = state.matchedLocation == AppRoutes.resetPassword;
   ```
2. Nếu đang ở `AppRoutes.resetPassword`: **Cho phép ở lại màn hình này** (không redirect về trang chủ).
3. Tại `ResetPasswordScreen`: Kiểm tra xem người dùng có phiên hợp lệ (`currentUser != null`) hay không. Nếu không có phiên (ví dụ người dùng tự gõ URL hoặc phiên đã hết hạn), hiển thị thông báo lỗi và yêu cầu bắt đầu lại từ `AppRoutes.forgotPassword`.
4. Sau khi gọi `updatePassword(newPassword)` thành công:
   - Gọi `authRepository.logout()` để kết thúc phiên khôi phục tạm thời.
   - Điều hướng về `AppRoutes.login` kèm SnackBar thông báo *"Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới."*.

### 3.4. Xử Lý Giới Hạn Gửi Lại Mã (Rate Limiting & Resend OTP)
* Phía Client: Khóa nút bấm và chạy Timer 60 giây.
* Phía Backend: Bắt mã lỗi HTTP `429 (Too Many Requests)` từ Supabase. Khi gặp lỗi này, hiển thị thông báo:
  > *"Bạn đã yêu cầu gửi mã quá nhiều lần. Vui lòng chờ ít phút trước khi thử lại."*
* Nếu người dùng yêu cầu gửi lại mã thành công, mã OTP cũ trong hòm thư sẽ tự động vô hiệu hóa theo cơ chế bảo mật của Supabase.

### 3.5. Quy Tắc Mật Khẩu (Password Validation)
* Mật khẩu tối thiểu 6 ký tự (phù hợp với cấu hình mặc định của Supabase Auth).
* Bắt buộc có cả chữ và số để tăng cường độ bảo mật cho tài khoản cư dân.
* Hiển thị cảnh báo trực quan nếu 2 ô mật khẩu không khớp nhau.

---

## 4. Chi Tiết Thay Đổi Mã Nguồn

### 4.1. Nâng cấp `AuthRepository` (`lib/data/repositories/auth_repository.dart`)
```dart
/// Gửi mã OTP 6 số đến email của người dùng để phục hồi mật khẩu
Future<void> sendPasswordResetOtp(String email) async {
  try {
    await _client.auth.resetPasswordForEmail(email.trim());
  } on AuthException catch (e) {
    if (e.statusCode == '429') {
      throw Exception('Bạn đã gửi yêu cầu quá nhiều lần. Vui lòng chờ ít phút.');
    }
    // Không rethrow lỗi user not found để bảo mật thông tin
  }
}

/// Xác thực mã OTP 6 số do người dùng nhập vào
Future<AuthResponse> verifyPasswordResetOtp({
  required String email,
  required String token,
}) async {
  try {
    return await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  } on AuthException catch (e) {
    if (e.message.contains('expired') || e.code == 'otp_expired') {
      throw Exception('Mã xác thực đã hết hạn. Vui lòng gửi lại mã mới.');
    }
    throw Exception('Mã xác thực không chính xác. Vui lòng kiểm tra lại.');
  }
}

/// Đổi mật khẩu mới
Future<UserResponse> updatePassword(String newPassword) async {
  return await _client.auth.updateUser(UserAttributes(password: newPassword));
}
```

### 4.2. Cấu Hình GoRouter (`lib/core/router/route_names.dart` & `app_router.dart`)
- Thêm routes:
  - `AppRoutes.forgotPassword = '/forgot-password'`
  - `AppRoutes.verifyOtp = '/verify-otp'`
  - `AppRoutes.resetPassword = '/reset-password'`
- Cấu hình redirect guard không đá người dùng ra khỏi `/reset-password` khi đang trong Recovery Session.

### 4.3. Các Màn Hình Mới
1. `lib/features/auth/screens/forgot_password_screen.dart`
2. `lib/features/auth/screens/verify_otp_screen.dart` (Giao diện 6 ô số, tự động chuyển focus, tự động paste từ clipboard, đếm ngược 60s)
3. `lib/features/auth/screens/reset_password_screen.dart` (Nhập mật khẩu mới, kiểm tra độ mạnh, cập nhật và logout về LoginScreen)
4. Cập nhật `LoginScreen` (`lib/features/auth/screens/login_screen.dart`): Chuyển nút text "Quên mật khẩu?" dẫn vào `AppRoutes.forgotPassword`.

---

## 5. Kế Hoạch Kiểm Thử (Testing Matrix)

1. **Unit Test `AuthRepository`:**
   - Test gửi OTP (mock `resetPasswordForEmail`).
   - Test xác thực OTP recovery (mock `verifyOTP`).
   - Test cập nhật mật khẩu (mock `updateUser`).
2. **Logic & Security Test:**
   - Test thông báo trung tính chống account enumeration.
   - Test xử lý lỗi 429 rate limit.
   - Test validate OTP 6 số và validate mật khẩu khớp.
3. **Router Test:**
   - Kiểm tra `/forgot-password`, `/verify-otp`, `/reset-password` không bị redirect về login khi unauthenticated.
   - Kiểm tra `/reset-password` không bị redirect về home khi có recovery session.
