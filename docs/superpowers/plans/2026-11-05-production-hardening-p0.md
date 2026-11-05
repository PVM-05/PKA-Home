# Kế Hoạch Triển Khai: Chuẩn Hóa Production - Đợt 1 (P0: An Toàn & Tính Đúng Đắn Cốt Lõi)

> **Dành cho kỹ sư & agent:** Bắt buộc tuân thủ TDD, fail-closed mặc định, không để dữ liệu mock ngầm lọt vào luồng thật. Commit trực tiếp vào `main`.

**Mục tiêu:** Xử lý triệt để 6 lỗ hổng bảo mật và nghiệp vụ P0 nghiêm trọng: Luồng thanh toán chuyển tiền sai tài khoản, Mock ngầm trong repositories, Lộ bí mật/credential trong bundle client, Định danh do client tự khai, Lỗi logic quá hạn hóa đơn, OCR giả lập và nối luồng MFA.

**Kiến trúc:** Fail-Closed Architecture, Server-authoritative Identity (`auth.uid()`), Safe Multi-tenant Building Resolution, Zero Secrets in Client Bundle.

---

## Danh Sách Task Triển Khai

### Task 1.1: Chuẩn Hóa Luồng Thanh Toán & Tài Khoản Ngân Hàng
**Files:**
- Modify: `lib/data/models/building_model.dart`
- Modify: `lib/data/providers/resident_apartment_provider.dart`
- Modify: `lib/data/providers/building_provider.dart`
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Modify: `lib/data/models/invoice_model.dart`
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Test: `test/core/widgets/unified_payment_sheet_bank_resolution_test.dart`

- [ ] **Bước 1.1.1:** Xóa bỏ toàn bộ hardcoded fallback BIDV / 1234567890 / BQL PKA LANDMARK trong `BuildingModel`.
- [ ] **Bước 1.1.2:** Thêm `building_id` vào truy vấn `residentApartmentsProvider` và tạo `residentBuildingIdProvider`, `residentBuildingProvider`.
- [ ] **Bước 1.1.3:** Cập nhật `UnifiedPaymentSheet`:
  - Dùng `residentBuildingProvider` thay cho `activeBuildingProvider`.
  - Nếu tòa nhà chưa cấu hình tài khoản (hoặc thiếu STK/BIN): Ẩn QR, hiện cảnh báo *"Ban Quản Lý chưa cấu hình tài khoản nhận tiền cho tòa nhà này. Vui lòng liên hệ trực tiếp BQL để được hỗ trợ thanh toán."*
  - Bỏ `effectivePaymentCode` tự sinh nếu thiếu `payment_code`.
  - Chuẩn hóa memo thanh toán: Chỉ gồm ký tự chữ và số thuần túy (loại bỏ `#`, `-`).
- [ ] **Bước 1.1.4:** Viết test xác thực `test/core/widgets/unified_payment_sheet_bank_resolution_test.dart`.
- [ ] **Bước 1.1.5:** Commit: `fix(payment): chuan hoa tai khoan ngan hang theo toa va loai bo fallback mock p0`.

---

### Task 1.2: Loại Bỏ Mock Fallback Ngầm – Thiết Lập Cơ Chế Fail-Closed
**Files:**
- Create: `lib/core/utils/guard_helper.dart`
- Modify: `lib/data/repositories/parking_repository.dart`
- Modify: `lib/data/repositories/front_desk_repository.dart`
- Modify: `lib/data/repositories/community_repository.dart`
- Modify: `lib/data/repositories/material_repository.dart`
- Modify: `lib/data/repositories/debt_prediction_repository.dart`
- Modify: `lib/data/repositories/accounting_repository.dart`
- Modify: `lib/data/repositories/resident_lifecycle_repository.dart`
- Test: `test/data/repositories/fail_closed_repositories_test.dart`

- [ ] **Bước 1.2.1:** Tạo `lib/core/utils/guard_helper.dart` với hàm `guardRepositoryCall<T>()`, kiểm tra cờ `bool.fromEnvironment('USE_MOCK')`. Khi không bật cờ mock, mọi lỗi đều ném `AppException` rõ ràng, không nuốt lỗi.
- [ ] **Bước 1.2.2:** Rà soát và loại bỏ các khối `catch (_) { return _mock...; }` trong các repositories, thay thế bằng cơ chế fail-closed.
- [ ] **Bước 1.2.3:** Viết unit test xác thực cơ chế fail-closed khi không có cờ `USE_MOCK`.
- [ ] **Bước 1.2.4:** Commit: `fix(data): loai bo mock fallback ngam va bat buoc fail-closed trong repositories p0`.

---

### Task 1.3: Dọn Dẹp Credential & Bảo Vệ Bí Mật Nền Tảng
**Files:**
- Modify: `pubspec.yaml` (loại bỏ `.env` và `.env.*` khỏi assets)
- Modify: `lib/core/services/operational_alert_service.dart` (vô hiệu hóa gọi webhook trực tiếp từ client khi ở production)
- Modify: `lib/data/repositories/management_repository.dart` (xóa mật khẩu mặc định `PkaHome@2026`)
- Modify: `lib/core/utils/document_pdf_builder.dart` (xóa STK hardcode MB 888888888888)
- Modify: `docs/BAN_GIAO_VAN_HANH.md` (xóa tài khoản/mật khẩu mẫu)

- [ ] **Bước 1.3.1:** Gỡ bỏ `.env` khỏi `assets:` trong `pubspec.yaml`.
- [ ] **Bước 1.3.2:** Xóa mật khẩu hardcode `PkaHome@2026` trong `ManagementRepository.createUser`.
- [ ] **Bước 1.3.3:** Xóa STK MB `888888888888` trong `DocumentPdfBuilder`.
- [ ] **Bước 1.3.4:** Chuyển `OperationalAlertService` client sang chế độ ghi log/an toàn, không phát tán token.
- [ ] **Bước 1.3.5:** Commit: `fix(security): go bo env asset mat khau mac dinh va credentials hardcode p0`.

---

### Task 1.4: Khắc Phục Lỗi Logic Quá Hạn Hóa Đơn & Biểu Giá Bậc Thang
**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Modify: `lib/features/resident/widgets/tiered_breakdown_dialog.dart` (hoặc nơi định nghĩa)

- [ ] **Bước 1.4.1:** Sửa logic so sánh quá hạn: So sánh với cuối ngày (`dueDate.add(const Duration(days: 1))`), hóa đơn đến hạn hôm nay hiển thị đúng "Đến hạn hôm nay".
- [ ] **Bước 1.4.2:** Hiển thị chi tiết bậc thang từ `breakdown` của hóa đơn, không tự tính lại ở client với biểu giá hardcode.
- [ ] **Bước 1.4.3:** Commit: `fix(invoice): sua logic qua han hoa don va hien thi breakdown chuan p0`.

---

### Task 1.5: Gỡ Bỏ OCR Giả Lập & Chuẩn Hóa Nhãn Nhận Diện
**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `lib/core/utils/meter_ocr_simulator.dart`

- [ ] **Bước 1.5.1:** Gỡ bỏ nút "Mô phỏng nhận diện" sinh số ngẫu nhiên.
- [ ] **Bước 1.5.2:** Bắt buộc chụp/chọn ảnh công tơ thật, người dùng nhập số liệu đọc được từ ảnh.
- [ ] **Bước 1.5.3:** Đổi nhãn "Trợ lý AI (95%)" thành "Gợi ý phân loại tự động".
- [ ] **Bước 1.5.4:** Commit: `fix(meter): go bo ocr gia lap va bat buoc anh cong to thuc te p0`.

---

### Task 1.6: Kết Nối Luồng MFA Trực Tiếp Vào Màn Hình Đăng Nhập
**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `lib/data/repositories/auth_repository.dart`
- Test: `test/features/auth/login_mfa_flow_test.dart`

- [ ] **Bước 1.6.1:** Sau khi `login` bằng email/password thành công, kiểm tra xem người dùng có factor MFA nào không qua `MfaService.listFactors()`.
- [ ] **Bước 1.6.2:** Nếu có factor active, chặn điều hướng vào app và bật `MfaVerificationDialog`. Chỉ khi verify TOTP thành công mới hoàn tất đăng nhập.
- [ ] **Bước 1.6.3:** Viết widget test kiểm tra luồng chặn MFA tại LoginScreen.
- [ ] **Bước 1.6.4:** Commit: `feat(auth): ket noi xac thuc 2 buoc mfa vao luong dang nhap thuc te p0`.

---

### Task 1.7: Cập Nhật Lại Trạng Thái Minh Bạch Trên Roadmap & Đẩy Lên GitHub
**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`

- [ ] **Bước 1.7.1:** Chạy toàn bộ test suites và `dart analyze lib test`.
- [ ] **Bước 1.7.2:** Cập nhật `docs/COMMERCIAL_PRODUCT_ROADMAP.md`: Điều chỉnh các mục có mock data hoặc unwired sang trạng thái đang hoàn thiện Production.
- [ ] **Bước 1.7.3:** Push toàn bộ commits lên `origin/main`.

