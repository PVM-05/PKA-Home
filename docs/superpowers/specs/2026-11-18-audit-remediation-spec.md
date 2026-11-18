# Đặc Tả Kỹ Thuật Khắc Phục Lỗ Hổng Kiểm Toán & Dữ Liệu UI Vivona (Audit Remediation Spec)

> **Mục tiêu:** Khắc phục triệt để 5 vấn đề cốt lõi đã được kiểm toán: Loại bỏ dữ liệu giả trong biểu đồ tiêu thụ điện nước, đưa `AppGlassCard` vào sử dụng thực tế, hiệu chỉnh tài liệu roadmap trung thực với điều kiện tiên quyết SDK, làm sạch whitelist guard test cùng refactor màn hình kích hoạt, và chuẩn hóa hệ thống cá nhân hóa không sót hóa đơn quá hạn ngoài trang 1.  
> **Ngày lập:** 18/11/2026  
> **Trạng thái:** Sẵn sàng triển khai  

---

## 1. Vấn Đề 1 (P0): Biểu đồ tiêu thụ điện nước — Thay thế số liệu giả bằng dữ liệu thật

### 1.1. Hiện trạng
- File `lib/features/resident/widgets/home/resident_utility_consumption_chart_card.dart` đang hardcode:
  `_electricityData = [210, 260, 290, 275, 230, 215]`, `_waterData = [16, 19, 22, 20, 18, 17]`, `_months = ['T6', 'T7', 'T8', 'T9', 'T10', 'T11']`.
- Mọi cư dân đều thấy cùng một dãy số và tính % tăng/giảm giả mạo.

### 1.2. Giải pháp kiến trúc
1. **Tầng Dữ Liệu (`MeterReadingRepository` & Provider):**
   - Bổ sung hàm `getUtilityConsumptionHistory(String apartmentId, {int limit = 6})` trong `MeterReadingRepository`.
   - Truy vấn `meter_reading_submissions` với điều kiện: `apartment_id = apartmentId`, `status = 'approved'`, sắp xếp theo `created_at ASC`, lấy tối đa 6 kỳ gần nhất.
   - Tạo `residentUtilityConsumptionHistoryProvider` (Riverpod `FutureProvider.autoDispose` hoặc `AsyncNotifierProvider`) nhận `apartmentId`.
2. **Tầng Giao Diện (`ResidentUtilityConsumptionChartCard`):**
   - Đọc dữ liệu từ `residentUtilityConsumptionHistoryProvider`.
   - **Quy tắc hiển thị trung thực (Production Truthfulness Gate):**
     - Nếu số lượng kỳ đã duyệt $< 2$: Widget trả về `SizedBox.shrink()` (ẩn thẻ hoàn toàn khỏi Trang chủ), tuyệt đối không hiển thị số giả hay thẻ rỗng gây hiểu lầm.
     - Nếu số lượng kỳ đã duyệt $\ge 2$: Vẽ biểu đồ bằng số kWh (`effectiveElectricConsumed`) và m³ (`effectiveWaterConsumed`) thật, nhãn tháng thật từ chu kỳ `period`, tính % chênh lệch giữa kỳ mới nhất và kỳ liền trước.

---

## 2. Vấn Đề 2: Biến `AppGlassCard` Thành Thành Phần Giao Diện Thực Tế

### 2.1. Hiện trạng
- `AppGlassCard` trong `lib/core/widgets/app_glass.dart` là dead code (chỉ có trong test, 0 chỗ nào trong `lib/features/` gọi tới).

### 2.2. Giải pháp kiến trúc
- Tích hợp `AppGlassCard` vào các bề mặt nổi thực tế trên giao diện cư dân:
  1. `ApartmentSwitcherChip` trên header trang chủ: Nằm trên nền gradient của `SliverAppBar`, tạo hiệu ứng kính mờ (BackdropFilter blur 12dp) tôn trọng triết lý hiển thị hiện đại.
  2. `StickyEmergencyBar` trên trang chủ: Nằm trên cùng nổi bật với viền kính mờ bán trong suốt.
- Đảm bảo `AppGlassCard` hoạt động mượt mà trong runtime production.

---

## 3. Vấn Đề 3: Hiệu Chỉnh Tài Liệu Lộ Trình `material_ui_expressive_roadmap.md`

### 3.1. Hiện trạng
- Tài liệu lộ trình chứa các thông điệp nói quá (padding, fontSize, Bounceable, WCAG AA) không khớp với số liệu thực tế đo đạc trong repo.
- Thiếu điều kiện tiên quyết SDK: `material_ui` cần Flutter $\ge 3.47$, trong khi CI đang ghim `3.44.0`.

### 3.2. Giải pháp
- Cập nhật số liệu đo lường thực tế:
  - Padding/Radius: Ghi rõ tokens đã áp dụng cho Core Widgets và các module whitelist; khối lượng nợ tồn là 1.170 `EdgeInsets` và 649 `BorderRadius.circular`.
  - Typography: Ghi rõ tiến độ giảm từ 1.206 xuống 961 chỗ `fontSize` (~245 chỗ đã chuẩn hóa).
  - Bounceable: Ghi rõ 8 vị trí cốt lõi hiện hành.
  - Trợ năng: Ghi rõ 15 thẻ `Semantics` hiện có, đưa việc kiểm tra tương phản tự động vào kế hoạch.
- Bổ sung **Điều kiện tiên quyết 0 (Prerequisite 0 - SDK Readiness Gate)**: Phải nâng cấp Flutter SDK lên $\ge 3.47$ (khi bản stable chính thức phát hành) và mở khóa CI trước khi thêm `package:material_ui` vào `pubspec.yaml`.

---

## 4. Vấn Đề 4: Whitelist Guard Test & Refactor Màn Hình Kích Hoạt

### 4.1. Hiện trạng
- `test/core/theme_and_color_guard_test.dart` có entry chết: `lib/features/auth/screens/first_time_activation_screen.dart`.
- Màn hình thật `lib/features/auth/screens/resident_activation_screen.dart` còn 25 `fontSize:` cứng và không được whitelist bảo vệ.
- Guard test có lỗi logic: `if (!file.existsSync()) continue;` khiến các file không tồn tại âm thầm lọt qua CI.

### 4.2. Giải pháp
1. Sửa `theme_and_color_guard_test.dart`:
   - Thay `if (!file.existsSync()) continue;` bằng:
     ```dart
     if (!file.existsSync()) {
       fail('File nằm trong Whitelist nhưng không tồn tại trên đĩa: $filePath');
     }
     ```
   - Xóa bỏ hoàn toàn entry chết `first_time_activation_screen.dart`.
2. Refactor `resident_activation_screen.dart`:
   - Chuẩn hóa toàn bộ 25 vị trí `fontSize:` cứng sang `Theme.of(context).textTheme.*` (hoặc `AppTheme`).
   - Đưa `resident_activation_screen.dart` vào Whitelist chính thức của guard test.

---

## 5. Vấn Đề 5: Cá Nhân Hóa (Personalization) Không Sót Hóa Đơn Quá Hạn Ngoài Trang 1

### 5.1. Hiện trạng
- `mostUrgentInvoice`, `activeIssue`, `daysUntilDueDate` được tính nhưng không được sử dụng ở `ResidentHomeScreen`.
- `residentInvoiceProvider` chỉ lấy 20 hóa đơn (trang 1). Nếu cư dân có hóa đơn quá hạn cũ nằm ngoài 20 hóa đơn đầu tiên thì hệ thống không phát hiện ra.

### 5.2. Giải pháp
1. **Tầng Dữ Liệu:**
   - Thêm hàm `getUnpaidInvoices(String apartmentId)` trong `InvoiceRepository`:
     Truy vấn các hóa đơn có `status in ('unpaid', 'pending_confirmation')`, không bị giới hạn bởi trang 1 (`limit: 100` hoặc không giới hạn limit cho các hóa đơn chưa đóng của 1 căn hộ), sắp xếp theo `due_date ASC`.
   - Tạo provider `unpaidInvoicesProvider` cung cấp danh sách đầy đủ các khoản nợ của căn hộ.
2. **Cập nhật `HomePersonalizationProvider`:**
   - Sử dụng `unpaidInvoicesProvider` để tính `mostUrgentInvoice` và `daysUntilDueDate`. Đảm bảo mọi hóa đơn quá hạn (dù từ 6 tháng trước) đều được phát hiện chính xác 100%.
3. **Nối vào Giao Diện:**
   - `ResidentHomeUpcomingInvoiceCard`: Hiển thị cảnh báo quá hạn nổi bật kèm số ngày quá hạn khi `daysUntilDueDate < 0` dựa trên `mostUrgentInvoice`.
   - `ResidentHomeLatestIssueCard`: Hiển thị đúng sự cố `activeIssue` được ưu tiên bởi personalization.

