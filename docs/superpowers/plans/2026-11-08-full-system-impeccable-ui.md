# Kế Hoạch Triển Khai: Nâng Cấp Toàn Diện UI/UX Toàn Hệ Thống (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Cải tiến toàn diện các màn hình cốt lõi của PKA-Home (Hóa đơn & Thanh toán VietQR, Quản lý Sự cố & SLA, Quản trị Căn hộ & Cư dân Web BQL) theo triết lý Impeccable Taste và chống tràn bố cục 100%.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tài liệu đặc tả:** `docs/superpowers/specs/2026-11-08-full-system-impeccable-ui-design.md`
- **Trạng thái:** [x] HOÀN TẤT 100% (7/7 Tasks Đã Nghiệm Thu, 0 Warning, 0 RenderFlex Error).

---

## Danh Sách Nhiệm Vụ Chi Tiết

### [x] Task 1: Nâng cấp `ResidentInvoiceScreen` (Danh Sách Hóa Đơn Cư Dân)
- **Tệp chỉnh sửa:** `lib/features/resident/screens/resident_invoice_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_invoice_responsive_test.dart`
- **Kết quả:**
  1. Responsive hoàn hảo ở 1000dp (Web/Tablet), 320dp (Mobile hẹp), và font zoom 1.3x.
  2. Dùng `AppCard` viền siêu mỏng mờ, không đè bóng thô kệch.
  3. Bọc danh sách trong `Center(ConstrainedBox(maxWidth: 1000))` chống kéo dãn toàn màn hình trên Web.
  4. Bọc các nhãn Text trong `Flexible` và `FittedBox` chống tràn bố cục 100%.
  5. Đã commit: `ed6fd35` `feat(resident): cai tien resident invoice screen theo impeccable taste va chong tran bo cuc`.

---

### [x] Task 2: Nâng cấp `ResidentInvoiceDetailScreen` (Chi Tiết Hóa Đơn & Thanh Toán VietQR)
- **Tệp chỉnh sửa:** `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_invoice_detail_responsive_test.dart`
- **Kết quả:**
  1. Hiển thị hộp VietQR động và chi tiết bảng phí ở desktop (900dp) và mobile (320dp).
  2. Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 900))`.
  3. Tái cấu trúc khối thanh toán VietQR: mã QR viền mờ bo góc 16px, nút sao chép STK & nội dung thanh toán có phản hồi Haptic và SnackBar.
  4. Bảng chi tiết các khoản phí sắc nét, thanh toán cố định ở đáy màn hình không bị che lấp.
  5. Đã commit: `7f1449b` `feat(resident): nang cap chi tiet hoa don va hop thanh toan vietqr dong`.

---

### [x] Task 3: Nâng cấp `InvoiceManagementScreen` (Đối Soát Hóa Đơn Phía BQL)
- **Tệp chỉnh sửa:** `lib/features/management/screens/invoice_management_screen.dart`
- **Tệp kiểm thử:** `test/features/management/invoice_management_responsive_test.dart`
- **Kết quả:**
  1. Chế độ Enterprise Data Table đối soát chuyên nghiệp trên Web ($\ge 900$dp) và danh sách thẻ `AppCard` trên Mobile (< 900dp).
  2. Data Table trên Desktop với các cột: Mã HĐ, Căn hộ, Kỳ phí, Số tiền, Trạng thái, Thao tác nhanh (Duyệt/Chi tiết).
  3. Cải tiến bộ lọc trạng thái và thanh tìm kiếm không tràn chữ, hỗ trợ giới hạn `maxWidth: 1400`.
  4. Đã commit: `8422286` `feat(management): nang cap invoice management workstation responsive web va mobile`.

---

### [x] Task 4: Nâng cấp `ResidentIssueScreen` & `CreateIssueScreen` (Phản Ánh Sự Cố Cư Dân)
- **Tệp chỉnh sửa:**
  - `lib/features/resident/screens/resident_issue_screen.dart`
  - `lib/features/resident/screens/create_issue_screen.dart`
- **Tệp kiểm thử:** `test/features/resident/resident_issue_responsive_test.dart`
- **Kết quả:**
  1. Form tạo sự cố và danh sách sự cố responsive hoàn hảo trên 320dp và 1000dp.
  2. `CreateIssueScreen`: Selector danh mục dạng lưới icon viền mỏng mờ, khu vực xem trước ảnh chụp bo tròn 12px có nút xóa góc trên.
  3. `ResidentIssueScreen`: Thẻ sự cố phân cấp thông tin rõ ràng (mức độ ưu tiên, trạng thái SLA, thời gian xử lý), bọc `Expanded(FittedBox)` chống tràn.
  4. Đã commit: `73ab916` `feat(resident): nang cap giao dien bao cao va theo doi su co cu dan`.

---

### [x] Task 5: Nâng cấp `IssueManagementScreen` (Điều Phối Sự Cố BQL)
- **Tệp chỉnh sửa:** `lib/features/management/screens/issue_management_screen.dart`
- **Tệp kiểm thử:** `test/features/management/issue_management_responsive_test.dart`
- **Kết quả:**
  1. Bảng điều phối sự cố chuyên nghiệp Material 3 Data Table trên Web Desktop ($\ge 900$dp) và Mobile cards.
  2. Thẻ chỉ số SLA Realtime cuộn ngang mượt mà trên mobile hẹp, không tràn bố cục.
  3. Nút phân công tự động thích ứng chuyển sang cột khi chiều rộng thẻ $< 340$dp.
  4. Đã commit: `270e9fd` `feat(management): nang cap issue management workstation bql`.

---

### [x] Task 6: Nâng cấp `ResidentManagementScreen` & `ApartmentManagementScreen` (Quản Lý Căn Hộ & Cư Dân)
- **Tệp chỉnh sửa:**
  - `lib/features/management/screens/resident_management_screen.dart`
  - `lib/features/management/screens/apartment_management_screen.dart`
- **Tệp kiểm thử:** `test/features/management/resident_directory_responsive_test.dart`
- **Kết quả:**
  1. Desktop Workstation Data Table cho danh bạ cư dân và sơ đồ căn hộ ($\ge 900$dp, `maxWidth: 1400`).
  2. Mobile thẻ `AppCard` với thông tin liên lạc (điện thoại, email) bọc trong `Expanded` chống tràn.
  3. GridView căn hộ trên mobile có `childAspectRatio: 0.95`, dải chip chọn tầng/tòa cuộn ngang chống tràn khi text zoom 1.3x.
  4. Đã commit: `e0fed59` `feat(management): nang cap resident va apartment management workstation responsive web va mobile`.

---

### [x] Task 7: Kiểm Tra Toàn Bộ (Quality Gate & Full Verification)
- **Lệnh thực thi:**
  1. `dart analyze lib test` -> **No issues found!** (0 error, 0 warning, 0 hint).
  2. Toàn bộ test suite responsive và business logic pass 100%.
- **Cam kết:** Không còn bất kỳ lỗi RenderFlex overflow nào trên toàn hệ thống ở cả mobile 320dp (font zoom 1.3x) và desktop enterprise.
