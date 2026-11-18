# Kế Hoạch Triển Khai Khắc Phục Lỗ Hổng Kiểm Toán & Dữ Liệu UI Vivona (Audit Remediation Plan)

> **Mục tiêu:** Khắc phục triệt để 5 vấn đề cốt lõi đã được kiểm toán theo tiêu chuẩn sản xuất B2B SaaS Vivona: Biểu đồ tiêu thụ điện nước nối dữ liệu thật (ẩn khi < 2 kỳ), tích hợp `AppGlassCard` vào UI, hiệu chỉnh roadmap trung thực với SDK prerequisite, làm sạch guard test whitelist & refactor màn kích hoạt, và tối ưu cá nhân hóa hóa đơn không sót nợ ngoài trang 1.  
> **Nguyên tắc:** Commit trực tiếp vào nhánh `main`, TDD (viết test trước, code sau), 0 lỗi phân tích tĩnh (`dart analyze`), 100% tests pass.  

---

### Task 1: Khắc Phục Whitelist Guard Test & Refactor Màn Hình Kích Hoạt (Vấn Đề 4)
- [x] **Step 1: Cập nhật `test/core/theme_and_color_guard_test.dart`**
  - Đổi logic bỏ qua `continue` thành `fail('File nằm trong Whitelist không tồn tại...')`.
  - Xóa `'lib/features/auth/screens/first_time_activation_screen.dart'`.
  - Thêm `'lib/features/auth/screens/resident_activation_screen.dart'`.
  - Chạy test để xác nhận test phát hiện lỗi font/color trong màn hình kích hoạt thật.
- [x] **Step 2: Refactor `lib/features/auth/screens/resident_activation_screen.dart`**
  - Thay thế 25 `fontSize:` cứng bằng `Theme.of(context).textTheme.*`.
  - Thay thế các mã màu cứng bằng `colorScheme` hoặc `AppTheme`.
- [x] **Step 3: Chạy lại guard test và widget tests của màn kích hoạt**
  - Chạy `flutter test test/core/theme_and_color_guard_test.dart` (4/4 passed).
  - Chạy `flutter test test/features/auth/screens/resident_activation_screen_test.dart` (2/2 passed).
- [x] **Step 4: Commit thay đổi Task 1**
  - Commit: `fbe4660 fix(guardrail): don dep whitelist guard test va chuan hoa typography man kich hoat`

---

### Task 2: Hiệu Chỉnh Tài Liệu Lộ Trình `material_ui_expressive_roadmap.md` (Vấn Đề 3)
- [x] **Step 1: Cập nhật tài liệu với số liệu đo đạc thực tế**
  - Ghi rõ số lượng padding/radius token đã áp dụng vs nợ tồn (1.170 EdgeInsets + 649 BorderRadius).
  - Ghi rõ tiến độ typography (giảm từ 1.206 xuống 936, còn tồn 936 fontSize).
  - Ghi rõ 8 nút `Bounceable` hiện có và 15 nhãn `Semantics`.
- [x] **Step 2: Bổ sung Prerequisite 0 (SDK Flutter $\ge 3.47$)**
  - Làm rõ điều kiện nâng Flutter SDK trong CI trước khi có thể tích hợp `package:material_ui`.
- [x] **Step 3: Commit thay đổi Task 2**
  - Commit: `35e0b78 docs(architecture): cap nhat so lieu thuc te va dieu kien sdk cho material ui expressive roadmap`

---

### Task 3: Tích Hợp `AppGlassCard` Vào Thành Phần Giao Diện Thực Tế (Vấn Đề 2)
- [x] **Step 1: Tích hợp `AppGlassCard` vào `StickyEmergencyBar` và `ApartmentSwitcherChip`**
  - File `lib/features/resident/widgets/sticky_emergency_bar.dart`: bọc bề mặt bằng `AppGlassCard` (nền bán trong suốt, blur 10dp).
  - File `lib/features/resident/widgets/apartment_switcher_chip.dart`: bọc bề mặt chip trên header bằng `AppGlassCard` (blur 8dp).
- [x] **Step 2: Kiểm tra tương thích giao diện và chạy tests**
  - Chạy `flutter test test/features/resident/resident_home_hierarchy_test.dart` (passed).
  - Chạy `flutter test test/goldens/design_system_goldens_test.dart` (5/5 golden tests passed).
- [x] **Step 3: Commit thay đổi Task 3**
  - Commit: `5748a28 feat(ui): tich hop app glass card vao thanh khẩn cấp va chip chuyen can ho`

---

### Task 4: Nối Dữ Liệu Thật Cho Biểu Đồ Tiêu Thụ Điện Nước (Vấn Đề 1 - P0)
- [x] **Step 1: Viết test cho `residentUtilityConsumptionHistoryProvider` và hiển thị trung thực**
  - Viết `test/features/resident/widgets/resident_utility_consumption_chart_card_test.dart` theo TDD.
  - Test trường hợp $< 2$ kỳ đã duyệt -> Tự động ẩn thẻ (`SizedBox.shrink`).
  - Test trường hợp $\ge 2$ kỳ -> Vẽ biểu đồ điện nước và nhãn tháng thật (`T9`, `T10`, 150 kWh, 12 m³).
- [x] **Step 2: Triển khai repository & provider**
  - Bổ sung `getApprovedConsumptionHistory(String apartmentId, {int limit = 6})` trong `MeterReadingRepository`.
  - Tạo `residentUtilityConsumptionHistoryProvider` trong `lib/data/providers/meter_reading_provider.dart`.
- [x] **Step 3: Cập nhật `ResidentUtilityConsumptionChartCard`**
  - Xóa bỏ hoàn toàn `_electricityData`, `_waterData`, `_months` hardcode.
  - Đọc từ `residentUtilityConsumptionHistoryProvider`.
  - Nếu số kỳ $< 2$: trả về `SizedBox.shrink()` (ẩn hoàn toàn).
  - Nếu số kỳ $\ge 2$: vẽ biểu đồ cột/đường với số liệu và tháng chu kỳ thật.
- [x] **Step 4: Chạy kiểm thử xác minh**
  - Chạy `flutter test test/features/resident/widgets/resident_utility_consumption_chart_card_test.dart` (3/3 passed).
- [x] **Step 5: Commit thay đổi Task 4**
  - Commit: `c8b18d7 feat(resident): noi du lieu that cho bieu do tieu thu dien nuoc va an the khi chua du du lieu`

---

### Task 5: Tối Ưu Hệ Thống Cá Nhân Hóa Không Sót Hóa Đơn Quá Hạn Ngoài Trang 1 (Vấn Đề 5)
- [x] **Step 1: Viết test cho tìm hóa đơn quá hạn ngoài trang 1**
  - Bổ sung test case trong `home_personalization_provider_test.dart`: Hóa đơn quá hạn nằm ngoài trang 1 vẫn được nhận diện chính xác là `mostUrgentInvoice`.
  - Viết widget test `resident_home_upcoming_invoice_card_test.dart`: Hiển thị badge `'Quá hạn X ngày'` khi `daysUntilDueDate < 0`.
- [x] **Step 2: Triển khai `residentUnpaidInvoicesProvider`**
  - Thêm `residentUnpaidInvoicesProvider` trong `resident_invoice_provider.dart` truy vấn toàn bộ hóa đơn nợ không bị giới hạn trang 1 (limit 20).
  - Cập nhật `homePersonalizationProvider` sử dụng danh sách này.
- [x] **Step 3: Nối `mostUrgentInvoice` & `activeIssue` vào UI Trang Chủ**
  - Hiển thị badge / cảnh báo số ngày quá hạn rõ ràng trên `ResidentHomeUpcomingInvoiceCard` khi có nợ quá hạn.
  - Nối `activeIssue` vào `ResidentHomeLatestIssueCard`.
- [x] **Step 4: Chạy toàn bộ test suites và kiểm tra phân tích tĩnh**
  - `dart analyze lib test`: `No issues found!` (0 errors, 0 warnings).
  - `flutter test`: 100% test suites passed.
- [x] **Step 5: Commit thay đổi Task 5**
  - Commit: `e448362 fix(personalization): toi uu tim hoa don qua han toan dien va ket noi du lieu khan cap vao ui`
