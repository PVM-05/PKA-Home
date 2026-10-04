# Đặc Tả Thiết Kế: Tự Cấp Lại Mật Khẩu Qua Email OTP (Self-Service Password Reset via Email OTP)

**Mã tài liệu:** `SPEC-2026-10-04-AUTH-RESET-OTP`  
**Ngày lập:** 04/10/2026  
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
       │ (Thành công -> Chuyển sang Bước 2 kèm email)
       ▼
[2. VerifyOtpScreen (/verify-otp)]
  - 6 ô số nhập OTP riêng biệt, tự động chuyển con trỏ, tự động dán từ clipboard
  - Đếm ngược 60 giây gửi lại mã
  - Xác thực qua Supabase verifyOTP (type: OtpType.recovery)
       │ (Hợp lệ -> Supabase cấp Recovery Session)
       ▼
[3. ResetPasswordScreen (/reset-password)]
  - Nhập Mật khẩu mới & Xác nhận mật khẩu mới
  - Cập nhật mật khẩu qua updateUser(password: newPassword)
       │ (Thành công)
       ▼
[Điều hướng về Màn hình Đăng nhập / Trang chủ với thông báo thành công]
```

---

## 3. Chi Tiết Kỹ Thuật

### 3.1. Nâng cấp `AuthRepository`
Bổ sung các phương thức giao tiếp với Supabase Auth:
```dart
/// Gửi mã OTP 6 số đến email của người dùng để phục hồi mật khẩu
Future<void> sendPasswordResetOtp(String email) async {
  await _client.auth.resetPasswordForEmail(email);
}

/// Xác thực mã OTP 6 số do người dùng nhập vào
Future<AuthResponse> verifyPasswordResetOtp({
  required String email,
  required String token,
}) async {
  return await _client.auth.verifyOTP(
    email: email,
    token: token,
    type: OtpType.recovery,
  );
}

/// Đổi mật khẩu mới (áp dụng cho cả khi đã đăng nhập và sau khi verify recovery OTP)
Future<UserResponse> updatePassword(String newPassword) async {
  return await _client.auth.updateUser(UserAttributes(password: newPassword));
}
```

### 3.2. Cấu Hình GoRouter & Bypass Redirect Auth Guard
Trong `lib/core/router/app_router.dart`, danh sách các route công khai (chưa đăng nhập được phép truy cập) cần bổ sung:
```dart
final isAuthRoute = state.matchedLocation == AppRoutes.login ||
    state.matchedLocation == AppRoutes.register ||
    state.matchedLocation == AppRoutes.forgotPassword ||
    state.matchedLocation == AppRoutes.verifyOtp ||
    state.matchedLocation == AppRoutes.resetPassword;
```
Điều này đảm bảo người dùng chưa đăng nhập không bị tự động đá về `/login` khi đang ở màn hình nhập OTP hoặc đặt lại mật khẩu.

### 3.3. Các Màn Hình Giao Diện Người Dùng (UI Screens)

#### 1. `ForgotPasswordScreen` (`lib/features/auth/screens/forgot_password_screen.dart`)
- **UI:** Icon ổ khóa bảo mật, tiêu đề "Quên Mật Khẩu", đoạn mô tả ngắn "Nhập địa chỉ thư điện tử đã đăng ký của bạn. Chúng tôi sẽ gửi mã xác thực 6 chữ số để đặt lại mật khẩu.".
- **Ô nhập liệu:** Email với regex validate định dạng email chuẩn.
- **Nút bấm:** "Gửi mã xác thực" (có loading indicator khi đang gọi API).
- **Hành động:** Khi gửi thành công, `context.push(AppRoutes.verifyOtp, extra: email)`.

#### 2. `VerifyOtpScreen` (`lib/features/auth/screens/verify_otp_screen.dart`)
- **UI:** 6 ô nhập số riêng biệt (`OtpInputBoxes`), font số to, rõ ràng, bo góc 12px theo `AppTheme`.
- **UX & Clipboard:** Khi người dùng sao chép mã 6 số từ email và dán (Paste) vào ô bất kỳ, hệ thống tự động bóc tách từng ký tự điền đủ vào 6 ô và tự động kích hoạt nút xác thực.
- **Đếm ngược:** Bộ đếm 60 giây. Khi đếm về 0, nút "Gửi lại mã" sáng lên cho phép gọi lại `sendPasswordResetOtp`.
- **Hành động:** Khi xác thực thành công, `context.push(AppRoutes.resetPassword, extra: email)`.

#### 3. `ResetPasswordScreen` (`lib/features/auth/screens/reset_password_screen.dart`)
- **UI:** 2 ô nhập mật khẩu: "Mật khẩu mới" và "Xác nhận mật khẩu mới", có nút ẩn/hiện mật khẩu (Con mắt).
- **Kiểm tra độ mạnh:** Mật khẩu tối thiểu 6 ký tự, 2 trường phải khớp nhau.
- **Nút bấm:** "Cập nhật mật khẩu".
- **Hành động:** Gọi `updatePassword(newPassword)`. Hiển thị thông báo màu xanh `AppTheme.success` "Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.", sau đó chuyển về `AppRoutes.login`.

#### 4. Cập nhật `LoginScreen` (`lib/features/auth/screens/login_screen.dart`)
- Thay thế nút mở dialog thông báo liên hệ BQL cũ bằng:
```dart
Center(
  child: TextButton(
    onPressed: () => context.push(AppRoutes.forgotPassword),
    child: const Text(
      'Quên mật khẩu?',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.primary,
      ),
    ),
  ),
),
```

---

## 4. Kế Hoạch Kiểm Thử (Testing Matrix)

1. **Unit Test `AuthRepository`:**
   - Test `sendPasswordResetOtp` gọi đúng phương thức `resetPasswordForEmail`.
   - Test `verifyPasswordResetOtp` gọi đúng `verifyOTP` với `type: OtpType.recovery`.
   - Test `updatePassword` gọi đúng `updateUser`.
2. **Logic & Validation Test:**
   - Test kiểm tra email không hợp lệ.
   - Test kiểm tra mã OTP chưa đủ 6 ký tự.
   - Test kiểm tra mật khẩu xác nhận không khớp.
3. **Widget Test:**
   - Kiểm tra hiển thị nút "Quên mật khẩu?" trên LoginScreen và điều hướng sang `/forgot-password`.
