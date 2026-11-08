# Kế Hoạch Triển Khai: Nâng Cấp Toàn Diện UI/UX Toàn Hệ Thống (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Cải tiến toàn diện các màn hình cốt lõi của PKA-Home (Hóa đơn & Thanh toán VietQR, Quản lý Sự cố & SLA, Quản trị Web BQL) theo triết lý Impeccable Taste và chống tràn bố cục 100%.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tài liệu đặc tả:** `docs/superpowers/specs/2026-11-08-full-system-impeccable-ui-design.md`

---

## Danh Sách Nhiệm Vụ Chi Tiết

### Task 1: Nâng cấp `ResidentInvoiceScreen` (Danh Sách Hóa Đơn Cư Dân)
- **Tệp chỉnh sửa:** `lib/features/resident/screens/resident_invoice_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_invoice_responsive_test.dart`
- **Các bước thực hiện:**
  1. Viết test kiểm tra hiển thị responsive ở 1000dp (Web/Tablet), 320dp (Mobile hẹp), và font scale 1.3x.
  2. Thay thế `Card(color: Colors.white)` hardcode bằng `AppCard` với border mờ thích ứng dark mode (`Theme.of(context).colorScheme.surface`).
  3. Bọc danh sách trong `Center(ConstrainedBox(maxWidth: 1000))` chống kéo dãn toàn màn hình trên Web.
  4. Bọc các nhãn Text (Kỳ phí, hạn thanh toán, tổng tiền) trong `Flexible` và `FittedBox` chống lỗi RenderFlex.
  5. Chạy test xác nhận pass và commit: `feat(resident): cai tien resident invoice screen theo impeccable taste va chong tran bo cuc`.

---

### Task 2: Nâng cấp `ResidentInvoiceDetailScreen` (Chi Tiết Hóa Đơn & Thanh Toán VietQR)
- **Tệp chỉnh sửa:** `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_invoice_detail_responsive_test.dart`
- **Các bước thực hiện:**
  1. Viết test kiểm tra hiển thị hộp VietQR và chi tiết phí ở desktop (900dp) và mobile (320dp).
  2. Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 900))`.
  3. Tái cấu trúc khối thanh toán VietQR: mã QR viền mờ bo góc 16px, nút sao chép STK & nội dung thanh toán có phản hồi Haptic và SnackBar.
  4. Trình bày bảng chi tiết các khoản phí (Điện, Nước, Phí QL, Gửi xe) sắc nét, không dùng Card lồng Card.
  5. Chạy test xác nhận pass và commit: `feat(resident): nang cap chi tiet hoa don va hop thanh toan vietqr dong`.

---

### Task 3: Nâng cấp `InvoiceManagementScreen` (Đối Soát Hóa Đơn Phía BQL)
- **Tệp chỉnh sửa:** `lib/features/management/screens/invoice_management_screen.dart`
- **Tệp kiểm thử:** `test/features/management/invoice_management_responsive_test.dart`
- **Các bước thực hiện:**
  1. Viết test kiểm tra chế độ Enterprise Data Table trên Web ($\ge 900$dp) và danh sách thẻ trên Mobile (< 900dp).
  2. Xây dựng Data Table trên Desktop với các cột: Mã HĐ, Căn hộ, Kỳ phí, Số tiền, Trạng thái, Thao tác nhanh (Duyệt/Chi tiết).
  3. Cải tiến bộ lọc trạng thái và thanh tìm kiếm không tràn chữ.
  4. Chạy test xác nhận pass và commit: `feat(management): nang cap invoice management workstation responsive web va mobile`.

---

### Task 4: Nâng cấp `ResidentIssueScreen` & `CreateIssueScreen` (Phản Ánh Sự Cố Cư Dân)
- **Tệp chỉnh sửa:**
  - `lib/features/resident/screens/resident_issue_screen.dart`
  - `lib/features/resident/screens/create_issue_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_issue_responsive_test.dart`
- **Các bước thực hiện:**
  1. Viết test kiểm tra hiển thị form tạo sự cố và danh sách sự cố trên 320dp và 1000dp.
  2. `CreateIssueScreen`: Tạo selector danh mục dạng lưới icon viền mỏng mờ, khu vực xem trước ảnh chụp bo tròn 12px có nút xóa góc trên.
  3. `ResidentIssueScreen`: Thẻ sự cố phân cấp thông tin rõ ràng (mức độ ưu tiên, trạng thái SLA, thời gian xử lý).
  4. Chạy test xác nhận pass và commit: `feat(resident): nang cap giao dien bao cao va theo doi su co cu dan`.

---

### Task 5: Nâng cấp `IssueManagementScreen` (Điều Phối Sự Cố BQL)
- **Tệp chỉnh sửa:** `lib/features/management/screens/issue_management_screen.dart`
- **Tệp kiểm thử:** `test/features/management/issue_management_responsive_test.dart`
- **Các bước thực hiện:**
  1. Viết test kiểm tra bảng điều phối sự cố trên Web Desktop và Mobile.
  2. Thêm thẻ chỉ số SLA Realtime (Vi phạm hạn, Cần xử lý gấp, Đang xử lý).
  3. Tối ưu bộ lọc và danh sách điều phối kỹ thuật viên.
  4. Chạy test xác nhận pass và commit: `feat(management): nang cap issue management workstation bql`.

---

### Task 6: Kiểm Tra Toàn Bộ (Quality Gate & Full Verification)
- **Lệnh thực thi:**
  1. `dart analyze lib test` (yêu cầu: No issues found!).
  2. `flutter test` toàn bộ các file test responsive mới và các test hiện có.
- **Cam kết:** Báo cáo tổng thể kết quả cho người dùng kèm các cam đoan kỹ thuật.
