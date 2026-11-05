# Đặc Tả Thiết Kế: Bảo Mật Nền Tảng (Key Rotation, Private Storage Signed URLs, Rate-Limiting & MFA)

## 1. Tổng Quan & Mục Tiêu

Trong hệ thống SaaS Quản lý Tòa nhà Thương Mại PKA-Home, bảo mật nền tảng (Platform Security) là điều kiện tiên quyết để vận hành thực tế tại các chung cư và tuân thủ Luật Bảo vệ Dữ liệu Cá nhân (Luật 91/2025/QH15 & Nghị định 356/2025/NĐ-CP).

Tài liệu này đặc tả 4 thành phần bảo mật nền tảng cốt lõi (Giai đoạn A4):
1. **Quy Trình Xoay Key Supabase (Key Rotation):** Hướng dẫn vận hành xoay JWT Secret và Publishable/Anon Key 0-downtime khi có rủi ro lộ lọt.
2. **Private Storage Buckets & Temporary Signed URLs:** Bảo vệ 100% hình ảnh sự cố cá nhân và biên lai chuyển khoản ngân hàng bằng Private Buckets và Signed URLs có thời hạn (15–60 phút) kèm cơ chế đệm in-memory cache thông minh.
3. **Bộ Giới Hạn Tốc Độ Xác Thực (Auth Rate-Limiter):** Cơ chế chống dò mật khẩu (Brute-Force) và lạm dụng OTP tại client kết hợp Supabase Auth.
4. **Xác Thực 2 Yếu Tố (MFA / TOTP) cho Ban Quản Lý & Kế Toán:** Bắt buộc hoặc khuyến nghị bảo vệ tài khoản có quyền truy cập dữ liệu tài chính và quản trị tòa nhà bằng mã OTP 6 số qua Google Authenticator / Microsoft Authenticator.

---

## 2. Kiến Trúc & Cấu Trúc Thư Mục

```text
docs/
└── security/
    └── SUPABASE_KEY_ROTATION.md               # Quy trình xoay key 0-downtime cho DevOps/Admin
lib/
├── core/
│   ├── security/
│   │   ├── secure_storage_service.dart        # Quản lý Signed URLs có cache cho Private Buckets
│   │   ├── auth_rate_limiter.dart             # Bộ kiểm soát tốc độ đăng nhập và gửi OTP
│   │   └── mfa_service.dart                   # Dịch vụ quản lý xác thực 2 yếu tố (TOTP)
│   └── supabase_config.dart                   # Kiểm tra tính hợp lệ của cấu hình key
└── features/
    └── auth/
        └── widgets/
            ├── mfa_verification_dialog.dart   # Hộp thoại nhập mã TOTP khi đăng nhập
            └── mfa_setup_dialog.dart          # Hộp thoại quét QR / nhập mã bí mật để kích hoạt MFA
test/
└── core/
    └── security/
        ├── secure_storage_service_test.dart   # Kiểm thử tạo URL, cache và expiry
        ├── auth_rate_limiter_test.dart        # Kiểm thử lockout, đếm ngược và reset
        └── mfa_service_test.dart              # Kiểm thử luồng TOTP enrollment & verification
```

---

## 3. Đặc Tả Chi Tiết Từng Thành Phần

### 3.1. Hướng Dẫn Xoay Key 0-Downtime (`SUPABASE_KEY_ROTATION.md`)
- Trình bày quy trình 5 bước chuẩn quốc tế:
  1. Đánh giá phạm vi ảnh hưởng (Audit & Impact Analysis).
  2. Tạo khóa dự phòng hoặc cấu hình song song (Dual-Key Configuration).
  3. Cập nhật biến môi trường trên máy chủ / CI/CD (GitHub Secrets, Railway/Docker env).
  4. Triển khai bản cập nhật ứng dụng di động/web (Rolling Deployment).
  5. Vô hiệu hóa và thu hồi khóa cũ (Revoke Old Key).

### 3.2. Private Storage Service (`SecureStorageService`)
- **Bucket đích:** `issue-images`, `payment-proofs`, `contracts`.
- **Cơ chế tạo URL:**
  - Không sử dụng `getPublicUrl` đối với dữ liệu nhạy cảm.
  - Sử dụng `createSignedUrl(path, expiresInSeconds)`. Mặc định `expiresInSeconds = 1800` (30 phút).
- **Bộ nhớ đệm (Cache):**
  - Lưu trữ URL kèm thời điểm hết hạn `(signedUrl, expiresAt)`.
  - Nếu URL còn hạn trên 60 giây, tái sử dụng URL từ cache thay vì gọi lại Supabase API, giảm tải mạng và tăng tốc độ hiển thị hình ảnh.

### 3.3. Bộ Giới Hạn Tốc Độ (`AuthRateLimiter`)
- **Quy tắc đăng nhập (Login Brute-Force Protection):**
  - Cho phép tối đa 5 lần thử đăng nhập sai liên tiếp trong cửa sổ 5 phút.
  - Sau lần thứ 5 sai: Khóa tài khoản tạm thời 15 phút. Hiển thị thông báo tiếng Việt kèm thời gian đếm ngược còn lại.
  - Khi đăng nhập thành công: Tự động reset bộ đếm về 0.
- **Quy tắc gửi OTP (OTP Cooldown):**
  - Yêu cầu giãn cách tối thiểu 60 giây giữa 2 lần gửi mã OTP liên tiếp.
  - Tối đa 3 lần xác thực mã sai -> Khóa chức năng xác thực OTP trong 10 phút.

### 3.4. Dịch Vụ Xác Thực 2 Yếu Tố (`MfaService`) & Giao Diện
- **MfaService:**
  - Kiểm tra tài khoản hiện tại đã kích hoạt MFA chưa: `client.auth.mfa.listFactors()`.
  - Đăng ký yếu tố mới: `client.auth.mfa.enroll({factorType: FactorType.totp})`.
  - Thách thức và xác thực: `client.auth.mfa.challengeAndVerify({factorId, code})`.
  - Hủy đăng ký: `client.auth.mfa.unenroll({factorId})`.
- **Giao diện người dùng:**
  - `MfaVerificationDialog`: Hiển thị khi người dùng có vai trò BQL/Kế toán đăng nhập và tài khoản đã bật MFA. Nhập 6 chữ số, nút "Xác nhận", nút "Hủy".
  - `MfaSetupDialog`: Hiển thị mã bí mật (Secret Key) để người dùng thêm vào app Google/Microsoft Authenticator, kèm ô nhập mã kiểm tra kích hoạt.

---

## 4. Kế Hoạch Kiểm Thử Tự Động (Testing Strategy)

- **`secure_storage_service_test.dart`:**
  - Kiểm thử tạo signed URL thành công với thời hạn hợp lệ.
  - Kiểm thử cache: Gọi liên tiếp 2 lần cùng 1 path chỉ gọi API Supabase 1 lần.
  - Kiểm thử cache invalidate: Khi URL hết hạn, tự động gọi API sinh URL mới.
- **`auth_rate_limiter_test.dart`:**
  - Kiểm thử ghi nhận lần thử sai và cảnh báo số lần còn lại.
  - Kiểm thử kích hoạt trạng thái khóa sau 5 lần sai.
  - Kiểm thử mở khóa sau khi hết thời gian chờ hoặc gọi reset.
  - Kiểm thử cooldown 60s của OTP.
- **`mfa_service_test.dart`:**
  - Kiểm thử luồng kiểm tra trạng thái MFA, khởi tạo challenge và xác minh mã TOTP.

---

## 5. Tiêu Chí Hoàn Thành (Definition of Done)

- [ ] File tài liệu `docs/security/SUPABASE_KEY_ROTATION.md` được viết đầy đủ, chi tiết.
- [ ] `SecureStorageService` triển khai hoàn chỉnh với Signed URLs và In-Memory Cache.
- [ ] `AuthRateLimiter` hoạt động độc lập và bảo vệ chống Brute-force / Spam OTP.
- [ ] `MfaService` và các Dialogs `MfaVerificationDialog`, `MfaSetupDialog` được xây dựng bằng 100% tiếng Việt chuẩn mực.
- [ ] Toàn bộ unit và widget tests tự động đạt 100% PASS.
- [ ] `dart analyze lib test` đạt 0 issues (No issues found!).
- [ ] Cập nhật Roadmap `COMMERCIAL_PRODUCT_ROADMAP.md` (mục A4) và đồ thị tri thức `graphify`.
- [ ] Commit trực tiếp trên `main` và push lên GitHub remote.

