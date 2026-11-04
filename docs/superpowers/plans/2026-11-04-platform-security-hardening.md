# Kế Hoạch Triển Khai: Bảo Mật Nền Tảng (Key Rotation, Private Storage Signed URLs, Rate-Limiting & MFA)

> **Dành cho kỹ sư & agent:** Bắt buộc tuân thủ TDD, viết kiểm thử trước, code sau. Từng bước sử dụng cú pháp checkbox (`- [ ]`). Toàn bộ commit trực tiếp vào `main`.

**Mục tiêu:** Xây dựng hệ thống bảo mật nền tảng toàn diện: Hướng dẫn xoay key 0-downtime, Private Storage Signed URLs có cache, Auth Rate-Limiter chống brute-force/spam OTP, và MFA/TOTP cho Ban Quản Lý & Kế Toán.

**Kiến trúc:** Layered Security (Data Layer & Core Services), tách biệt trách nhiệm rõ ràng (`SecureStorageService`, `AuthRateLimiter`, `MfaService`), UI Dialogs 100% tiếng Việt chuẩn mực.

**Tech Stack:** Dart 3.x, Flutter, Supabase Flutter (Auth MFA & Storage), Riverpod, flutter_test.

## Ràng Buộc Chung
- Tuân thủ 100% tiếng Việt chuẩn mực trong thông điệp và giao diện. Không sử dụng emoji.
- Commit trực tiếp trên `main`.
- Duy trì 0 warning, 0 error với `dart analyze lib test`.

---

## Danh Sách Task Triển Khai

### Task 1: Hướng Dẫn Xoay Key & Nâng Cấp SupabaseConfig
- [ ] Tạo `docs/security/SUPABASE_KEY_ROTATION.md` với quy trình 5 bước xoay JWT secret và publishable/anon key không gián đoạn dịch vụ.
- [ ] Cập nhật `lib/core/supabase_config.dart` bổ sung kiểm tra định dạng key và thông báo bảo mật rõ ràng.

### Task 2: Private Storage Buckets & Temporary Signed URLs (`SecureStorageService`)
- [ ] Viết test `test/core/security/secure_storage_service_test.dart` xác thực tạo Signed URL, cơ chế in-memory cache và tự làm mới khi hết hạn.
- [ ] Tạo `lib/core/security/secure_storage_service.dart` với lớp `SignedUrlCacheEntry`, `SecureStorageService` và các helper method.
- [ ] Tạo Riverpod Provider cho `SecureStorageService`.

### Task 3: Bộ Giới Hạn Tốc Độ Xác Thực (`AuthRateLimiter`)
- [ ] Viết test `test/core/security/auth_rate_limiter_test.dart` kiểm tra số lần đăng nhập sai, thời gian khóa cooldown, đếm ngược và kiểm soát giãn cách gửi OTP.
- [ ] Tạo `lib/core/security/auth_rate_limiter.dart` với lớp `RateLimitResult`, `AuthRateLimiter`.
- [ ] Tích hợp `AuthRateLimiter` vào `AuthRepository`.

### Task 4: Dịch Vụ MFA & Giao Diện Hộp Thoại Xác Thực 2 Bước
- [ ] Viết test `test/core/security/mfa_service_test.dart` và `test/features/auth/mfa_dialog_test.dart`.
- [ ] Tạo `lib/core/security/mfa_service.dart` đóng gói các API MFA của Supabase (`listFactors`, `enroll`, `verify`, `unenroll`).
- [ ] Tạo `lib/features/auth/widgets/mfa_verification_dialog.dart` (hộp thoại nhập mã TOTP 6 số khi đăng nhập).
- [ ] Tạo `lib/features/auth/widgets/mfa_setup_dialog.dart` (hộp thoại quét mã QR/nhập key bí mật để kích hoạt MFA).

### Task 5: Nghiệm Thu, Cập Nhật Roadmap & Tri Thức, Push Lên GitHub
- [ ] Chạy toàn bộ unit và widget tests của Task 1 - Task 4.
- [ ] Chạy `dart analyze lib test` (yêu cầu 0 issues).
- [ ] Cập nhật mục A4 trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md` sang trạng thái `[x]`.
- [ ] Cập nhật đồ thị tri thức `python -m graphify update .`.
- [ ] Commit trực tiếp trên `main` và push lên `origin/main`.
