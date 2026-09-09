# Thiết Kế: Sửa & Xóa Hóa Đơn BQL & Bộ Chọn Căn Hộ Thông Minh
**Ngày:** 09/09/2026  
**Dự án:** Ứng dụng Quản lý Chung cư (PKA-Home)  
**Trạng thái:** Đã phê duyệt thiết kế  

---

## 1. Mục tiêu & Yêu cầu Nghiệp vụ
1. **Quản lý Hóa đơn Toàn diện cho Ban Quản Lý:**
   - Hỗ trợ **Xóa hóa đơn**: Áp dụng khi tạo nhầm hóa đơn, có dialog xác nhận cảnh báo an toàn. Ràng buộc `ON DELETE CASCADE` của CSDL tự động làm sạch các dòng trong `invoice_items`.
   - Hỗ trợ **Chỉnh sửa hóa đơn**: Cho phép quản trị viên điều chỉnh lại các chỉ số điện, nước, phí gửi xe, phí quản lý hoặc kỳ thanh toán/hạn nợ. Trigger CSDL `trg_recalc_invoice_total` tự động cập nhật lại tổng tiền.
2. **Bộ Chọn Căn Hộ Thông Minh (Smart Occupied Apartment Selector):**
   - **Chỉ hiển thị căn hộ có người ở** (`isEmpty == false`): Tránh lập hóa đơn nhầm cho căn hộ trống.
   - **Phân cấp theo Tòa nhà (`buildingCode`):** Người dùng chọn Tòa (Tòa A, Tòa B...) trước, sau đó danh sách phòng thuộc tòa đó sẽ hiển thị thay vì phải cuộn qua danh sách hàng trăm căn hộ rời rạc.

---

## 2. Thiết Kế Chi Tiết

### 2.1. Tầng Repository (`ManagementRepository`)
Tệp: `lib/data/repositories/management_repository.dart`
Bổ sung 2 phương thức:
1. `Future<void> deleteInvoice(String invoiceId)`:
   - Thực hiện lệnh DELETE trên bảng `invoices`.
   - Bảng `invoice_items` tự động xóa theo CASCADE.
2. `Future<void> updateInvoice({required String invoiceId, required String period, required DateTime dueDate, required List<Map<String, dynamic>> items, String? apartmentId})`:
   - Cập nhật thông tin `invoices` (`period`, `due_date`, và `apartment_id` nếu có).
   - Xóa các `invoice_items` cũ của hóa đơn.
   - Chèn lại danh sách `invoice_items` mới (với `unit_price`, `quantity`, `fee_type`).
   - Trigger `trg_recalc_invoice_total` trong PostgreSQL tự động tính lại `subtotal` bằng generated column và cập nhật lại `total_amount` trên `invoices`.

---

### 2.2. Widget Bộ Chọn Căn Hộ Thông Minh (`SmartApartmentSelector`)
Áp dụng cho cả [create_invoice_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/screens/create_invoice_screen.dart) và [edit_invoice_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/screens/edit_invoice_screen.dart):
- Lọc danh sách: `final occupiedApartments = apartments.where((a) => !a.isEmpty).toList();`
- Gom nhóm theo Tòa: `final buildings = occupiedApartments.map((a) => a.buildingCode).toSet().toList()..sort();`
- Giao diện:
  1. Hàng FilterChip chọn Tòa nhà: `Tòa A (X căn)`, `Tòa B (Y căn)`.
  2. Dropdown chọn phòng: Chỉ hiển thị các căn thuộc Tòa đang chọn (`a.buildingCode == selectedBuilding`), hiển thị mã phòng `A0110` và diện tích `(68.5 m²)`.
  3. Nếu không có căn hộ nào có người ở: Hiển thị cảnh báo màu cam "Không có căn hộ nào đang có người sinh sống".

---

### 2.3. Tầng Giao Diện Thao Tác (UI)
1. **Danh sách hóa đơn ([invoice_management_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/screens/invoice_management_screen.dart)):**
   - Thêm nút menu 3 chấm trên mỗi thẻ hóa đơn:
     - ✏️ **Chỉnh sửa** -> Mở `EditInvoiceScreen(invoice: invoice)`.
     - 🗑️ **Xóa hóa đơn** -> Hiển thị hộp thoại `AlertDialog` cảnh báo màu đỏ xác nhận xóa.
2. **Chi tiết hóa đơn ([management_invoice_detail_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/screens/management_invoice_detail_screen.dart)):**
   - Thêm Action Button trên AppBar: Icon Sửa (✏️) và Icon Xóa (🗑️).
3. **Màn hình Chỉnh sửa Hóa đơn (`edit_invoice_screen.dart`):**
   - Nạp sẵn thông tin Căn hộ, Kỳ thanh toán, Hạn nộp.
   - Nạp các mục phí hiện tại của hóa đơn vào các ô nhập Điện, Nước, Xe máy, Ô tô, Phí quản lý.
   - Tính toán và hiển thị tổng tiền dự kiến theo thời gian thực (Realtime preview).
   - Nút "Lưu thay đổi": Gọi `updateInvoice`, làm mới `invoicesProvider`, thông báo thành công và đóng màn hình.

---

## 3. Kế Hoạch Kiểm Thử
- **Unit test:** Kiểm thử `deleteInvoice` và `updateInvoice` trong test suite.
- **Phân tích cú pháp:** `dart analyze` đạt 0 lỗi, 0 cảnh báo.
- **Test hồi quy:** `flutter test` vượt qua 100% tests.
