# Kế Hoạch Triển Khai: Chuẩn Hóa Sản Xuất B2B SaaS, Dọn Dẹp Mock & Tài Liệu SOP Vận Hành

- **Mục tiêu:**
  1. Loại bỏ triệt để tàn dư demo/simulation trên màn hình Cư dân (`resident_meter_reading_screen.dart`), bắt buộc ảnh công tơ thật.
  2. Sửa lỗi P0 Fail-Closed trong `InvoiceModel.effectivePaymentCode` (không bịa mã thanh toán ngầm).
  3. Chuẩn hóa `MaterialRepository` & `CommunityRepository` với cờ `_isMockMode` an toàn, đồng bộ hóa 100% test suite xanh.
  4. Biên soạn Quy Trình Vận Hành Chuẩn (SOP) cho Ban Quản Lý (`docs/QUY_TRINH_VAN_HANH_BQL_SOP.md`) theo mục 4 của `document-plan.md`.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tiêu chuẩn chất lượng:** Anti-RenderFlex, 100% tiếng Việt chuẩn mực SaaS B2B, 0 warning/error trên `dart analyze`.

---

## Danh Sách Nhiệm Vụ Chi Tiết

### Task 1: Dọn Dẹp Tàn Dư Demo Trên `ResidentMeterReadingScreen`
**Tệp:**
- Chỉnh sửa: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Kiểm thử: `test/features/resident/resident_meter_reading_responsive_test.dart`

- [x] **Step 1:** Gỡ bỏ các nút bấm `OutlinedButton.icon` nhãn "Mô phỏng nhận diện" ở cả 2 phần điện và nước.
- [x] **Step 2:** Gỡ bỏ import `meter_ocr_simulator.dart` và hàm `_scanMeter`.
- [x] **Step 3:** Giữ lại các nút chụp ảnh camera và chọn ảnh thư viện (`_pickMeterImage`), chuẩn hóa nhãn tiếng Việt và tooltips.
- [x] **Step 4:** Chạy test kiểm tra giao diện không lỗi: `flutter test test/features/resident/resident_meter_reading_responsive_test.dart`.
- [x] **Step 5:** Commit thay đổi vào `main`: `fix(resident): go bo mo phong nhan dien bat buoc anh cong to that`.

---

### Task 2: Khôi Phục P0 Fail-Closed Cho `InvoiceModel.effectivePaymentCode`
**Tệp:**
- Chỉnh sửa: `lib/data/models/invoice_model.dart`
- Kiểm thử: `test/data/models/invoice_model_payment_code_test.dart`

- [x] **Step 1:** Khôi phục `String get effectivePaymentCode => paymentCode ?? '';` chặn client tự sinh mã thanh toán khi DB chưa cấp.
- [x] **Step 2:** Chạy test xác nhận: `flutter test test/data/models/invoice_model_payment_code_test.dart`.
- [x] **Step 3:** Commit thay đổi vào `main`: `fix(finance): khoi phuc fail-closed chan bia payment_code client`.

---

### Task 3: Chuẩn Hóa `isMockMode` Cho Các Repositories & Đồng Bộ Test Suite
**Tệp:**
- Chỉnh sửa: `lib/data/repositories/material_repository.dart`
- Chỉnh sửa: `lib/data/repositories/community_repository.dart`
- Chỉnh sửa các tệp test tương ứng trong `test/data/repositories/`

- [x] **Step 1:** Thêm cờ `_isMockMode = false` vào constructor của `MaterialRepository`. Nếu `_isMockMode == true`, trực tiếp phục vụ bộ dữ liệu mẫu in-memory fallback mà không gọi Supabase client uninitialized.
- [x] **Step 2:** Cập nhật `test/data/repositories/material_repository_test.dart` để khởi tạo `MaterialRepository(null, true)`.
- [x] **Step 3:** Thêm cờ `_isMockMode = false` vào `CommunityRepository` và cập nhật `test/data/repositories/community_repository_test.dart`.
- [x] **Step 4:** Chạy kiểm thử xác nhận cả 2 repository test pass 100%.
- [x] **Step 5:** Commit thay đổi vào `main`: `fix(data): dong bo isMockMode explicit cho repository offline fallback tests`.

---

### Task 4: Khắc Phục Các Test Còn Lại Trong `test/data/`
**Tệp:**
- Rà soát các bài test bị fail còn lại trong `test/data/` (issue_rating, document, front_desk...)
- Đồng bộ hóa logic test theo chuẩn kiến trúc mới.
- Chạy `flutter test test/data/` đảm bảo toàn bộ pass 100%.
- Commit thay đổi vào `main`: `test(data): sua va dong bo toan bo unit tests repo sang chuan san xuat`.

---

### Task 5: Soạn Thảo Quy Trình Vận Hành Chuẩn BQL (SOP B2B SaaS)
**Tệp:**
- Tạo mới: `docs/QUY_TRINH_VAN_HANH_BQL_SOP.md` (theo mục 4 của `document-plan.md`)
- Nội dung gồm:
  1. Quy trình Thu phí Dịch vụ & Đối soát Tự động VietQR Napas 247.
  2. Quy trình Cấp quyền Phương tiện & Điều phối Ô đỗ Bãi xe Hầm B1/B2.
  3. Quy trình Kiểm kê & Bàn giao Căn hộ Số (Digital Asset Handover).
  4. Quy trình Tiếp nhận & Xử lý Sự cố Kỹ thuật theo Cam kết SLA 4 Cấp Độ.
  5. Quy trình Quản lý Quỹ Bảo Trì 2% & Báo cáo Minh bạch Ban Quản Trị.
- Commit vào `main`: `docs: bien soan quy trinh van hanh chuan bql sop b2b saas`.

---

### Task 6: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức
- [x] Chạy `dart analyze lib test` (đảm bảo 0 issues).
- [x] Cập nhật các test UI resident & payment đồng bộ với fail-closed policy.
- [x] Chạy `graphify update .`.
- [x] Hoàn tất kế hoạch chuẩn hóa sản xuất thương mại B2B SaaS.

