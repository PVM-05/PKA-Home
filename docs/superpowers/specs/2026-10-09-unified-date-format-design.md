# Thiết Kế: Chuẩn Hóa Toàn Diện Định Dạng Ngày Tháng (AppDateFormatter)

## 1. Bối cảnh & Mục tiêu
- **Bối cảnh:** Hiện tại ứng dụng PKA-Home sử dụng các lệnh gọi `DateFormat` phân tán ở nhiều màn hình (cư dân và ban quản lý), dẫn đến định dạng ngày tháng chưa hoàn toàn nhất quán (chỗ dùng `dd/MM/yyyy`, chỗ dùng `dd/MM HH:mm` thiếu năm, chỗ dùng `HH:mm dd/MM`, chỗ ghép chuỗi `padLeft(2, '0')` thủ công, và chỗ dùng `dd/MM/yyyy - HH:mm`).
- **Mục tiêu:**
  - Chuẩn hóa toàn bộ ngày tháng trên giao diện hiển thị sang chuẩn Việt Nam: Ngày/Tháng/Năm (`dd/MM/yyyy`) và Ngày/Tháng/Năm Giờ:Phút (`dd/MM/yyyy HH:mm`).
  - Xây dựng lớp tiện ích dùng chung `AppDateFormatter` tại `lib/core/utils/app_date_formatter.dart` theo đúng quy tắc `coding-rules.md`.
  - Khử trùng lặp mã (DRY), an toàn với giá trị `null` và tự động chuyển đổi sang múi giờ địa phương (`toLocal()`).
  - Bảo toàn toàn bộ các định dạng kỹ thuật backend (`yyyy-MM-dd` gửi lên API/Supabase và `yyyyMMdd_HHmmss` cho tên file export).

## 2. Kiến Trúc Lớp Tiện Ích `AppDateFormatter`
File: `lib/core/utils/app_date_formatter.dart`

### Các phương thức chính:
1. `formatDate(DateTime? date, {String fallback = '-'})`:
   - Định dạng: `dd/MM/yyyy` (Ví dụ: `09/10/2026`).
   - Xử lý: Nếu `date == null` trả về `fallback`. Gọi `date.toLocal()` trước khi format.
2. `formatDateTime(DateTime? dateTime, {String fallback = '-'})`:
   - Định dạng: `dd/MM/yyyy HH:mm` (Ví dụ: `09/10/2026 14:30`).
   - Xử lý: Nếu `dateTime == null` trả về `fallback`. Gọi `dateTime.toLocal()`.
3. `formatDateTimeWithSeconds(DateTime? dateTime, {String fallback = '-'})`:
   - Định dạng: `dd/MM/yyyy HH:mm:ss` (Ví dụ: `09/10/2026 14:30:15`).
   - Dùng cho các màn hình chi tiết giao dịch tài chính, log hệ thống.
4. `formatPeriod(DateTime? date, {String fallback = '-'})`:
   - Định dạng: `MM/yyyy` (Ví dụ: `10/2026`).
5. `formatDayMonth(DateTime? date, {String fallback = '-'})`:
   - Định dạng: `dd/MM` (dành riêng cho các thành phần UI kích thước nhỏ như chip chọn ngày).
6. `formatTime(DateTime? date, {String fallback = '-'})`:
   - Định dạng: `HH:mm`.

## 3. Danh Sách Các Màn Hình & Thành Phần Cần Thay Thế

### 3.1. Phân Hệ Cư Dân (`lib/features/resident/`)
1. `screens/resident_invoice_screen.dart`:
   - Hạn thanh toán hóa đơn: Thay `formatDate.format(invoice.dueDate)` bằng `AppDateFormatter.formatDate(invoice.dueDate)`.
2. `screens/resident_invoice_detail_screen.dart`:
   - Hạn thanh toán: `AppDateFormatter.formatDate(_invoice.dueDate)`.
   - Thời gian thanh toán: `AppDateFormatter.formatDateTime(_invoice.updatedAt ?? _invoice.createdAt)`.
3. `screens/resident_issue_screen.dart`:
   - Ngày tạo phản ánh: `AppDateFormatter.formatDateTime(issue.createdAt)`.
4. `screens/issue_detail_screen.dart`:
   - Ngày tạo: `AppDateFormatter.formatDateTime(issue.createdAt)`.
   - Mốc tiến độ: `AppDateFormatter.formatDateTime(step.date)`.
5. `screens/resident_home_screen.dart`:
   - Thẻ thông báo: Thay chuỗi thủ công `padLeft(2, '0')` bằng `AppDateFormatter.formatDate(announcement.createdAt)`.
6. `screens/resident_announcement_detail_screen.dart`:
   - Ngày đăng thông báo: `AppDateFormatter.formatDateTime(announcement.createdAt)`.
7. `screens/resident_meter_reading_screen.dart`:
   - Thời gian gửi chỉ số: `AppDateFormatter.formatDateTime(item.createdAt)`.
8. `screens/vehicle_management_screen.dart`:
   - Ngày đăng ký xe: `AppDateFormatter.formatDateTime(vehicle.createdAt)`.
9. `screens/payment_history_screen.dart`:
   - Thời gian giao dịch: `AppDateFormatter.formatDateTime(tx.createdAt)`.
10. `screens/amenity_booking_screen.dart`:
    - Ngày sử dụng: `AppDateFormatter.formatDate(bookingDate)`.
    - Thẻ chọn ngày: `AppDateFormatter.formatDayMonth(date)`.
11. `widgets/equipment_interruption_banner.dart`:
    - Khoảng thời gian bảo trì: `${AppDateFormatter.formatDateTime(task.scheduledStart)} - ${AppDateFormatter.formatDateTime(task.scheduledEnd)}`.

### 3.2. Phân Hệ Ban Quản Lý (`lib/features/management/`)
1. `screens/management_home_screen.dart`:
   - Thời gian giao dịch gần nhất: Thay `dd/MM HH:mm` bằng `AppDateFormatter.formatDateTime(tx.createdAt)`.
2. `screens/equipment_management_screen.dart`:
   - Ngày bảo trì: Thay `HH:mm dd/MM` bằng `AppDateFormatter.formatDateTime(task.scheduledStart)`.
3. `screens/equipment_detail_screen.dart`:
   - Ngày bảo trì gần nhất/kế tiếp: `AppDateFormatter.formatDate(...)`.
   - Lịch sử bảo trì: `AppDateFormatter.formatDate(task.scheduledStart)`.
4. `screens/management_payment_transactions_screen.dart`:
   - Danh sách giao dịch: `AppDateFormatter.formatDateTime(tx.createdAt)`.
   - Chi tiết giao dịch: `AppDateFormatter.formatDateTimeWithSeconds(tx.createdAt)`.
5. `screens/management_meter_reading_screen.dart`:
   - Thời gian gửi chỉ số: `AppDateFormatter.formatDateTime(item.createdAt)`.
6. `screens/management_invoice_detail_screen.dart`:
   - Hạn thanh toán: `AppDateFormatter.formatDate(invoice.dueDate)`.
7. `screens/create_invoice_screen.dart` & `screens/edit_invoice_screen.dart`:
   - Hạn thanh toán: `AppDateFormatter.formatDate(_dueDate)`.
8. `screens/vehicle_approval_screen.dart`:
   - Ngày đăng ký xe: `AppDateFormatter.formatDateTime(v.createdAt)`.
9. `screens/service_rating_overview_screen.dart`:
   - Ngày đánh giá: `AppDateFormatter.formatDateTime(rating.createdAt)`.
10. `screens/issue_management_screen.dart`:
    - Ngày gửi phản ánh: `AppDateFormatter.formatDateTime(issue.createdAt)`.
11. `screens/announcement_management_screen.dart`:
    - Ngày đăng thông báo: `AppDateFormatter.formatDateTime(announcement.createdAt)`.
12. `screens/amenity_management_screen.dart`:
    - Ngày đặt lịch: `AppDateFormatter.formatDate(...)`.
13. `screens/role_delegation_screen.dart`:
    - Khoảng thời gian: `AppDateFormatter.formatDate(...)` và `AppDateFormatter.formatDateTime(...)`.
14. `widgets/maintenance_task_form_dialog.dart`:
    - Thời gian bắt đầu/kết thúc: Thay `HH:mm dd/MM/yyyy` bằng `AppDateFormatter.formatDateTime(...)`.
15. `widgets/bulk_invoice_dialog.dart`:
    - Hạn thanh toán: `AppDateFormatter.formatDate(_selectedDueDate)`.

### 3.3. Các Thành Phần Dùng Chung (`lib/core/`)
1. `widgets/unified_payment_sheet.dart`:
   - Thời gian giao dịch: `AppDateFormatter.formatDateTime(...)`.
2. `utils/excel_export_helper.dart`:
   - Cột ngày trong file Excel: `AppDateFormatter.formatDate(...)` và `AppDateFormatter.formatDateTime(...)`.
   - Giữ nguyên timestamp kỹ thuật `yyyyMMdd_HHmmss` cho tên file xuất.

## 4. Kiểm Thử & Đảm Bảo Chất Lượng
1. **Unit Test Tiện Ích (`test/core/utils/app_date_formatter_test.dart`)**:
   - Kiểm tra `formatDate` trả về đúng định dạng `dd/MM/yyyy`.
   - Kiểm tra `formatDateTime` trả về đúng định dạng `dd/MM/yyyy HH:mm`.
   - Kiểm tra `formatDateTimeWithSeconds` trả về `dd/MM/yyyy HH:mm:ss`.
   - Kiểm tra xử lý `null` an toàn với fallback tùy biến.
   - Kiểm tra chuyển đổi múi giờ UTC sang local time chính xác.
2. **Regression Testing**:
   - Chạy `flutter test` toàn bộ suite kiểm thử (269+ tests) đảm bảo không có bất kỳ regression nào.
   - Chạy `flutter analyze` đảm bảo 0 lỗi và 0 cảnh báo.
