# Đặc Tả Thiết Kế: Cải Tiến Toàn Diện UI/UX Toàn Hệ Thống (Full-System Impeccable & Anti-RenderFlex)

- **Ngày ban hành:** 2026-11-08
- **Tác giả:** Đội ngũ Kỹ sư PKA-Home (Commercial PropTech SaaS)
- **Tiêu chuẩn tham chiếu:** `pbakaus/impeccable` & Nguyên tắc thiết kế B2B Enterprise Web/Mobile chống tràn bố cục.

---

## 1. Mục Tiêu & Triết Lý Cốt Lõi

1. **Loại bỏ triệt để AI Slop:**
   - Không sử dụng các khối màu gradient hào nhoáng vô nghĩa, không lồng card trong card (`card-in-card nesting`).
   - Loại bỏ màu xám trên nền màu (low contrast text) và màu sắc hardcode (`Colors.white`, `Colors.grey.shade200`). Toàn bộ sử dụng Design Tokens từ `AppTheme` và `Theme.of(context).colorScheme`.
   - Giữ giao diện sắc sảo, tối giản, thanh lịch, mang phong cách của các nền tảng PropTech hàng đầu thế giới (Linear, Stripe, Airbnb Pro).

2. **Chống tràn bố cục 100% (Anti-RenderFlex Guarantee):**
   - Mọi chuỗi văn bản động (số tiền, mã căn hộ, tên cư dân, tiêu đề sự cố) bắt buộc có giới hạn `maxLines`, `overflow: TextOverflow.ellipsis` và bọc trong `Flexible` / `Expanded` hoặc `FittedBox`.
   - Tương thích hoàn toàn trên thiết bị màn hình siêu hẹp (chiều rộng 320dp), màn hình gập, tablet, và chế độ phóng to chữ hệ thống `textScaler` từ 1.0x đến 1.3x.

3. **Responsive Màn Hình Lớn (Enterprise Desktop Web):**
   - Không dãn bẹt nội dung trên màn hình 1080p, 2K, 4K: Giới hạn chiều rộng nội dung tối đa với `ConstrainedBox(maxWidth: 1000 - 1200)` và căn giữa `Center()`.
   - Màn hình BQL hỗ trợ Enterprise Data Grid trên Web Desktop ($\ge 900$dp) và danh sách thẻ cuộn tối ưu cảm ứng trên Mobile.

---

## 2. Chi Tiết Kiến Trúc 3 Phân Hệ (Phased Architecture)

### Phân Hệ 1: Tài Chính & Thanh Toán VietQR (Finance & Billing Hub)

#### 1.1 `ResidentInvoiceScreen` (Màn hình Danh sách Hóa đơn Cư dân)
- **Cấu trúc TabBar:** TabBar với 2 trạng thái rõ ràng "Cần thanh toán" và "Lịch sử đã đóng", chỉ số lượng hóa đơn chưa đóng được hiển thị bằng Badge màu cam/đỏ.
- **Thẻ Hóa đơn (`InvoiceCard`):**
  - Chuyển sang sử dụng `AppCard` với viền mỏng mờ thích ứng Dark Mode.
  - Hóa đơn quá hạn (`isOverdue`): Viền phát quang cảnh báo màu đỏ tinh tế (`AppTheme.error.withValues(alpha: 0.5)`), chip số ngày quá hạn rõ ràng.
  - Bố cục 2 cột (Kỳ phí + Hạn đóng bên trái, Tổng tiền + Nút chi tiết bên phải) bọc trong `Flexible` chống tràn.
- **Responsive:** Toàn bộ danh sách bọc trong `Center(ConstrainedBox(maxWidth: 1000))`.

#### 1.2 `ResidentInvoiceDetailScreen` (Chi tiết Hóa đơn & Thanh toán VietQR)
- **Khối Tổng tiền & Hạn thanh toán:** Hiển thị nổi bật theo phân cấp trực quan, số tiền bọc trong `FittedBox(fit: BoxFit.scaleDown)`.
- **Hộp Thanh toán VietQR Napas247:**
  - Hiển thị mã VietQR động được tạo sắc nét với viền bo góc 16px.
  - Thông tin tài khoản nhận tiền: Ngân hàng, Số tài khoản, Chủ tài khoản, Nội dung chuyển khoản chuẩn cú pháp hóa đơn.
  - Nút 1 chạm "Sao chép Số tài khoản" & "Sao chép Nội dung" có rung nhẹ HapticFeedback và hiển thị Toast xác nhận.
- **Bảng Phân tách Chi phí:** Liệt kê các khoản phí (Điện, Nước, Phí dịch vụ quản lý, Phí gửi xe) bằng dòng phân cách mỏng, không lồng card.

#### 1.3 `InvoiceManagementScreen` (Quản lý Hóa đơn Phía BQL)
- **Web Desktop ($\ge 900$dp):** Bảng dữ liệu Enterprise Data Table (Mã HĐ, Căn hộ, Kỳ phí, Tổng tiền, Trạng thái, Thao tác nhanh Duyệt thanh toán/In hóa đơn).
- **Mobile (< 900dp):** Danh sách thẻ cuộn với bộ lọc trạng thái dạng Chip ngang (Tất cả, Chờ đối soát, Quá hạn, Đã thu).

---

### Phân Hệ 2: Vận Hành & Phản Ánh Sự Cố (Operations & SLA Hub)

#### 2.1 `ResidentIssueScreen` & `IssueDetailScreen`
- **Bộ lọc Trạng thái:** "Đang xử lý" và "Lịch sử phản ánh".
- **Thẻ Phản ánh:** Icon danh mục màu sắc tinh tế (Điện, Nước, Thang máy, An ninh), badge mức độ ưu tiên, ngày tạo và kỹ thuật viên tiếp nhận.
- **Tiến trình Xử lý Trực quan:** Stepper 4 bước (Tiếp nhận $\rightarrow$ Điều phối kỹ thuật $\rightarrow$ Đang sửa chữa $\rightarrow$ Hoàn tất & Nghiệm thu).
- **Đánh giá Dịch vụ:** Modal đánh giá 5 sao cho cư dân nghiệm thu chất lượng sửa chữa.

#### 2.2 `CreateIssueScreen` (Màn hình Tạo Phản ánh)
- **Ma trận Danh mục Sự cố:** 6 ô danh mục trực quan có icon và viền phát quang khi được chọn.
- **Khu vực Đính kèm Hình ảnh:** Preview thumbnail hình vuông bo tròn 12px, nút xóa ảnh góc trên, hỗ trợ chụp ảnh hoặc chọn từ thư viện không gây giật lag.

#### 2.3 `IssueManagementScreen` (Điều phối Sự cố Ban Quản Lý)
- **Chỉ số SLA Realtime:** Thẻ đếm số sự cố quá hạn SLA, sự cố khẩn cấp cần xử lý ngay.
- **Điều phối Kỹ thuật viên:** Nút gán kỹ thuật viên trực tiếp trên bảng điều khiển.

---

### Phân Hệ 3: Danh Mục Căn Hộ & Cư Dân (Directory & Onboarding Hub)

#### 3.1 `ResidentManagementScreen` & `ApartmentManagementScreen`
- **Giao diện Tra cứu 360 độ:** Danh sách cư dân kèm thông tin số điện thoại, căn hộ đại diện, vai trò (Chủ hộ/Người thuê), trạng thái kích hoạt tài khoản.
- **Sơ đồ Trạng thái Căn hộ (Apartment Floor Map):** Thể hiện trực quan các căn hộ theo Tầng và Block với mã màu: Xanh dương (Đã ở), Xám (Trống), Cam (Chờ bàn giao).
- **Duyệt Liên kết Căn hộ (Link Requests):** Modal duyệt yêu cầu xác minh cư dân với 1 chạm phê duyệt hoặc từ chối kèm lý do.

---

## 3. Kế Hoạch Kiểm Thử & Tiêu Chí Nghiệm Thu (Quality Gate)

1. **Bộ Test Suite Toàn Diện:**
   - `resident_invoice_responsive_test.dart`: Kiểm tra hiển thị hóa đơn trên desktop (1000dp), mobile hẹp (320dp), text scale 1.3x.
   - `resident_issue_responsive_test.dart`: Kiểm tra form tạo sự cố và chi tiết sự cố không bị tràn layout.
   - `invoice_management_responsive_test.dart`: Kiểm tra bảng Data Table trên Web và danh sách trên Mobile.
2. **Tiêu chuẩn Biên dịch:**
   - `dart analyze lib test`: 0 errors, 0 warnings, 0 lints.
   - 100% tests mới và tests hiện có trong dự án đều pass.
