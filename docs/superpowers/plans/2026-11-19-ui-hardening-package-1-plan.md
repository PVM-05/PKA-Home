# Kế Hoạch Triển Khai Gói 1: Nợ UI & Tối Ưu Trải Nghiệm (Production Hardening)

> **Mục tiêu:** Giải quyết dứt điểm các nợ kỹ thuật UI và trải nghiệm cốt lõi theo ưu tiên audit: cấu hình động môi trường thanh toán VNPay (Zero-Hardcode), bộ đệm hình ảnh và placeholder shimmer, thay thế spinner bằng skeleton trên các danh sách chính, và hoàn thiện hướng dẫn cư dân mới (Onboarding).
> **Tiêu chuẩn:** Tuân thủ `AGENTS.md`, `coding-rules.md`, `design-rules.md`, 100% tiếng Việt chuẩn mực, không suy giảm độ phủ test (Zero-Regression).

---

## Danh Mục Công Việc Chi Tiết

### Task 1: Dynamic Sandbox Configuration Cho VNPay
- **Vấn đề:** `lib/core/widgets/unified_payment_sheet.dart:216` đang hardcode `isSandbox: true`, khiến môi trường Production vẫn gọi cổng Sandbox VNPay.
- **Giải pháp:**
  - Chuyển thành `isSandbox: !AppEnvironment.current.isProduction`.
  - Hỗ trợ tham số tùy chọn `isSandboxOverride` (nếu cần ép sandbox trong test).
- **Kiểm thử:**
  - Bổ sung test case trong `test/core/widgets/unified_payment_sheet_vnpay_test.dart` kiểm tra `isSandbox` là `false` khi `AppEnvironment.setForTesting(AppEnvironment(type: AppEnvironmentType.prod))` và `true` khi ở dev/staging.

### Task 2: Tối Ưu Bộ Đệm Hình Ảnh & Shimmer Placeholder (`AppStorageImage`)
- **Vấn đề:** `lib/core/widgets/app_storage_image.dart` dùng `Image.network` tải lại liên tục, placeholder là `CircularProgressIndicator` gây giật khung hình và tăng tải mạng.
- **Giải pháp:**
  - Tích hợp `cached_network_image` với bộ nhớ đệm tự động.
  - Thay placeholder mặc định bằng `AppSkeletonShimmer.box(width: width, height: height, borderRadius: borderRadius)`.
  - Thêm `memCacheWidth` / `memCacheHeight` tối ưu RAM khi hiển thị thumbnail danh sách.
- **Kiểm thử:**
  - Kiểm thử `AppStorageImage` render shimmer placeholder khi loading, hiển thị ảnh khi có url, và hiển thị icon lỗi chuẩn khi URL hỏng.

### Task 3: Phủ `AppSkeletonShimmer` Thay Thế Spinner Ở Các Danh Sách Chính
- **Vấn đề:** Audit ghi nhận còn nhiều màn hình dùng `CircularProgressIndicator` toàn màn hình khi tải danh sách thay vì Skeleton loader.
- **Màn hình mục tiêu:**
  1. `lib/features/resident/screens/resident_meter_reading_screen.dart` (Lịch sử chỉ số điện nước).
  2. `lib/features/resident/screens/resident_vehicle_screen.dart` (Danh sách phương tiện cư dân).
  3. `lib/features/management/screens/vehicle_management_screen.dart` (Quản lý phương tiện BQL).
  4. `lib/features/management/screens/resident_management_screen.dart` (Quản lý cư dân BQL).
  5. `lib/features/management/screens/apartment_management_screen.dart` (Quản lý căn hộ BQL).
  6. `lib/features/management/screens/announcement_management_screen.dart` (Quản lý thông báo BQL).
- **Giải pháp:**
  - Thay `Center(child: CircularProgressIndicator())` thành `AppSkeletonShimmer.cardList(count: 4, itemHeight: ...)` tương ứng với layout thẻ của từng màn hình.
- **Kiểm thử:**
  - Chạy toàn bộ test suites của các màn hình trên để xác minh không bị vỡ giao diện.

### Task 4: Hướng Dẫn Cư Dân Lần Đầu (`ResidentOnboardingDialog`)
- **Vấn đề:** Hiện chỉ có BQL sở hữu `role_onboarding_dialog.dart`, cư dân mới đăng nhập lần đầu chưa có cẩm nang làm quen các tính năng quan trọng.
- **Giải pháp:**
  - Xây dựng `ResidentOnboardingDialog` trực quan, hiện đại, trình bày 4 trụ cột tiện ích cư dân:
    1. **Hóa Đơn & VietQR Tức Thì**: Tra cứu chi tiết và thanh toán một chạm.
    2. **Phản Ánh Sự Cố 24/7**: Đính kèm ảnh, theo dõi tiến độ xử lý trực tiếp.
    3. **Chỉ Số Điện Nước Thông Minh**: Tự động nhận diện OCR và cảnh báo bất thường.
    4. **Cẩm Nang & Tiện Ích Tòa Nhà**: Danh bạ khẩn cấp, nội quy và đăng ký dịch vụ.
  - Lưu cờ `has_seen_resident_onboarding_v1` vào `SharedPreferences`.
  - Tích hợp tự động kích hoạt một lần duy nhất trên `ResidentHomeScreen` khi cư dân đăng nhập lần đầu.
- **Kiểm thử:**
  - Viết widget test cho `ResidentOnboardingDialog` xác minh hiển thị đầy đủ thông tin và lưu trạng thái khi bấm nút "Bắt đầu trải nghiệm".

