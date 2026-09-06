# Tài liệu Kiểm thử (Test Plan) - PKA-Home

Tài liệu này định nghĩa các kịch bản kiểm thử (Test Cases) cho ứng dụng Quản lý Chung cư PKA-Home, phục vụ cho quá trình kiểm định chất lượng ở Giai đoạn 6.

## 1. Kiểm thử Bảo mật (RLS - Row Level Security)
Kiểm tra tính an toàn của dữ liệu, đảm bảo phân quyền đúng đắn ở cấp độ database.

| ID | Kịch bản Test | Điều kiện tiên quyết | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- | :--- |
| RLS-01 | Cư dân đọc hóa đơn căn hộ mình | Đăng nhập tài khoản Cư dân A (căn hộ 101) | Query bảng `invoices` với `apartment_id` của 101. | Trả về danh sách hóa đơn của 101. |
| RLS-02 | Cư dân đọc hóa đơn căn hộ khác | Đăng nhập tài khoản Cư dân A (căn hộ 101) | Query bảng `invoices` với `apartment_id` của 102. | Trả về mảng rỗng `[]` (bị RLS chặn). |
| RLS-03 | Cư dân sửa trạng thái hóa đơn | Đăng nhập tài khoản Cư dân A (căn hộ 101) | Gửi request UPDATE `status` thành `paid`. | Lỗi `403 Forbidden` hoặc không có row nào bị đổi (chỉ Ban QL mới được phép). |
| RLS-04 | BQL xem dữ liệu toàn khu | Đăng nhập tài khoản Ban Quản lý | Query bảng `apartments`, `invoices`. | Trả về toàn bộ dữ liệu. |

## 2. Kiểm thử Chức năng (E2E Workflows)
Kiểm tra các luồng nghiệp vụ chính của ứng dụng.

| ID | Chức năng | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- |
| E2E-01 | Cư dân gửi phản ánh sự cố | 1. Đăng nhập Cư dân.<br>2. Vào mục Phản ánh, điền mô tả, chọn ảnh.<br>3. Bấm Gửi. | Dữ liệu lưu thành công, hiện thông báo thành công. Màn hình danh sách cập nhật trạng thái "Chờ tiếp nhận". |
| E2E-02 | BQL xử lý phản ánh | 1. Đăng nhập BQL.<br>2. Vào mục Phản ánh, chọn phản ánh vừa tạo.<br>3. Chuyển trạng thái sang "Đang xử lý". | Dữ liệu cập nhật. Cư dân (E2E-01) reload sẽ thấy trạng thái mới. |
| E2E-03 | Thanh toán hóa đơn | 1. Cư dân chọn hóa đơn chưa đóng.<br>2. Bấm Xác nhận thanh toán (Upload hình UNC). | Hóa đơn chuyển trạng thái "Đang chờ duyệt". |
| E2E-04 | BQL duyệt hóa đơn | 1. BQL vào Danh sách hóa đơn chờ duyệt.<br>2. Bấm Chấp nhận. | Hóa đơn chuyển trạng thái "Đã thanh toán". Cư dân hết nợ. |

## 3. Kiểm thử Giao diện (Responsive UI)
Dựa theo skill `flutter-build-responsive-layout` và `flutter-fix-layout-issues`.

| ID | Thiết bị Test | Kịch bản kiểm tra | Tiêu chí đạt (Pass) |
| :--- | :--- | :--- | :--- |
| UI-01 | Mobile nhỏ (iPhone SE) | Mở màn hình danh sách Hóa đơn & Phản ánh | Không bị lỗi RenderFlex Overflow. Chữ tự động wrap xuống dòng. |
| UI-02 | Tablet (iPad) | Mở màn hình Dashboard Ban Quản Lý | Bố cục trải rộng hợp lý, hiển thị dạng lưới (Grid) thay vì Danh sách (List) nếu có thể. |
| UI-03 | Nhập liệu form dài | Nhập text dài vào ô Mô tả sự cố | Bàn phím ảo không che khuất TextField. Nút Submit không bị đẩy ra ngoài. |
