# Tài liệu Kiểm thử (Test Plan) - PKA-Home

Tài liệu này định nghĩa các kịch bản kiểm thử (Test Cases) cho ứng dụng Quản lý Chung cư PKA-Home, phục vụ cho quá trình kiểm định chất lượng ở Giai đoạn 6.

## 1. Kiểm thử Bảo mật (RLS - Row Level Security)
Kiểm tra tính an toàn của dữ liệu, đảm bảo phân quyền đúng đắn ở cấp độ database.

| ID | Kịch bản Test | Điều kiện tiên quyết | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- | :--- |
| RLS-01 | Cư dân đọc hóa đơn căn hộ mình | Đăng nhập tài khoản Cư dân A (căn hộ A0110) | Query bảng `invoices` với `apartment_id` của A0110. | Trả về danh sách hóa đơn của A0110. |
| RLS-02 | Cư dân đọc hóa đơn căn hộ khác | Đăng nhập tài khoản Cư dân A (căn hộ A0110) | Query bảng `invoices` với `apartment_id` của A0111. | Trả về mảng rỗng `[]` (bị RLS chặn). |
| RLS-03 | Cư dân sửa trạng thái hóa đơn | Đăng nhập tài khoản Cư dân A (căn hộ A0110) | Gửi request UPDATE `status` thành `paid`. | Lỗi `403 Forbidden` hoặc không có row nào bị đổi (chỉ Ban QL mới được phép). |
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

## 4. Kiểm thử Khả năng Phục hồi & Toàn vẹn Dữ liệu (Resilience & Data Integrity)
Kiểm định tính bền bỉ của hệ thống trước sự cố mạng và đảm bảo nguyên tắc toàn vẹn dữ liệu tài chính.

| ID | Tên Kịch Bản | Điều kiện tiên quyết | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- | :--- |
| **RES-01** | Upload ảnh phản ánh thất bại (Mất mạng Storage) | Đăng nhập tài khoản Cư dân | 1. Mở màn hình Tạo phản ánh sự cố.<br>2. Nhập mô tả hợp lệ và chọn 1 hoặc nhiều ảnh.<br>3. Giả lập ngắt mạng hoặc quyền bucket storage bị từ chối.<br>4. Nhấn nút "Gửi phản ánh". | 1. Bản ghi phản ánh trong bảng `issue_reports` vẫn được bảo toàn (không mất công mô tả).<br>2. Không văng exception màu đỏ ra màn hình.<br>3. Màn hình đóng lại về trang danh sách và hiển thị SnackBar cảnh báo màu cam: *"Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau"*.<br>4. Cư dân không bị thao tác bấm gửi lại làm trùng lặp bản ghi. |
| **INT-01** | Toàn vẹn tài chính cấp Server (Generated Column) | Đăng nhập tài khoản Ban Quản lý | 1. Vào màn hình Lập hóa đơn.<br>2. Nhập các mục: Tiền điện (đơn giá: 3.500, số lượng: 100), Phí quản lý (đơn giá: 150.000, số lượng: 1).<br>3. Client chỉ gửi `fee_type`, `unit_price`, `quantity` lên DB.<br>4. Kiểm tra dữ liệu lưu trên bảng `invoice_items` và `invoices`. | 1. PostgreSQL tự động tính `subtotal = unit_price * quantity` chính xác (350.000 và 150.000) qua GENERATED ALWAYS STORED.<br>2. Trigger `trg_recalc_invoice_total` tự động cộng `total_amount = 500.000` trên bảng `invoices`.<br>3. Tuyệt đối không thể giả mạo `subtotal` từ phía client. |
| **AUTH-01** | Hướng dẫn Quên mật khẩu nội bộ | Mở màn hình Đăng nhập | 1. Nhấn vào nút liên kết *"Quên mật khẩu?"* bên dưới ô nhập mật khẩu. | Hiển thị Dialog giải thích rõ ràng: Căn hộ cần bảo mật cao nên phải liên hệ Văn phòng BQL/Hotline tòa nhà để được xác minh danh tính và cấp lại mật khẩu. |
| **SCAL-01** | Sẵn sàng mở rộng và Phân trang (Scalability) | Danh sách dữ liệu > 100 bản ghi | Gọi API danh sách qua client bằng `.range(from, to)`. | Dữ liệu trả về đúng phân đoạn giới hạn, thời gian truy vấn duy trì dưới 2 giây và tiết kiệm RAM/băng thông thiết bị di động. |

## 5. Kiểm thử Hệ thống Phân quyền Đa Vai Trò (Enterprise RBAC)
Kiểm tra tính đúng đắn của việc phân cấp vai trò (Admin, Kế toán, Kỹ thuật viên, Cư dân) trên cả Giao diện (UI) và Tầng dữ liệu (RLS).

| ID | Kịch bản Kiểm thử | Điều kiện tiên quyết | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- | :--- |
| **RBAC-01** | Điều hướng Tabs động theo vai trò | Có tài khoản Admin, Kế toán, Kỹ thuật viên | 1. Đăng nhập lần lượt 3 tài khoản.<br>2. Quan sát thanh điều hướng Bottom Navigation và AppBar. | - **Admin**: Hiện huy hiệu *"Quản trị viên"*, đủ 5 tabs (*Tổng quan, Cư dân, Hóa đơn, Phản ánh, Thông báo*).<br>- **Kế toán**: Hiện huy hiệu *"Kế toán"*, chỉ 4 tabs (*ẩn tab Phản ánh*).<br>- **Kỹ thuật viên**: Hiện huy hiệu *"Kỹ thuật viên"*, chỉ 4 tabs (*ẩn tab Hóa đơn*). |
| **RBAC-02** | Nguyên tắc đặc quyền tối thiểu trên Dashboard | Đăng nhập tài khoản Kỹ thuật viên | Quan sát màn hình Trang chủ BQL. | 1. Ẩn hoàn toàn thẻ *"Tiến độ thu phí"* và thẻ *"Tổng nợ phí"*.<br>2. Hiện thẻ kỹ thuật: *"Căn hộ trống"* và *"Sự cố đang xử lý"*.<br>3. Thanh Thao tác nhanh hiện *"Xử lý sự cố"*, ẩn nút *"Lập hóa đơn"*, *"Duyệt liên kết"*. |
| **RBAC-03** | Chuyển đổi vai trò & Chống tự hạ quyền (Self-Demotion) | Đăng nhập tài khoản Admin | 1. Vào mục Cư dân -> Bấm biểu tượng *"Phân quyền vai trò"* trên tài khoản của chính mình.<br>2. Thử chọn vai trò khác (*Kế toán / Kỹ thuật viên / Cư dân*). | 1. Giao diện hiển thị cảnh báo tài khoản của chính mình.<br>2. Các nút hạ quyền bị làm mờ, gắn nhãn *(Bị khóa)* và chặn bấm.<br>3. Nếu cố gọi API, trigger DB văng lỗi từ chối, ngăn Admin tự khóa mình ra khỏi hệ thống. |
| **RBAC-04** | Ghi nhật ký phân quyền (Audit Trail) | Đăng nhập Admin | 1. Đổi vai trò của 1 cư dân thành *"Kỹ thuật viên"*.<br>2. Kiểm tra bảng `role_change_log`. | Bảng `role_change_log` tự động lưu bản ghi: `target_user_id`, `old_role = resident`, `new_role = technician`, `changed_by = admin_id`, `changed_at = now()`. |

## 6. Kiểm thử Bền vững Liên kết Căn hộ & Chống Trùng Hóa Đơn
Kiểm thử các cơ chế bảo vệ dữ liệu tài chính và chống xung đột phiên làm việc.

| ID | Kịch bản Kiểm thử | Điều kiện tiên quyết | Các bước thực hiện | Kết quả mong đợi |
| :--- | :--- | :--- | :--- | :--- |
| **LINK-01** | Đổi tài khoản trong cùng phiên app | Đăng nhập Cư dân A (đã liên kết) | 1. Đăng xuất Cư dân A.<br>2. Đăng nhập ngay Cư dân B (chưa liên kết) trên cùng phiên app (không đóng app). | `residentLinkProvider` tự động hủy instance cũ, đọc `authProvider` mới và đưa Cư dân B vào đúng màn hình hướng dẫn liên kết căn hộ (không bị cache state của A). |
| **LINK-02** | Chống gửi nhiều yêu cầu liên kết pending song song | Cư dân B đang có 1 yêu cầu chờ duyệt | 1. Cố tình gửi thêm yêu cầu liên kết căn hộ khác.<br>2. Hoặc gọi trực tiếp INSERT `apartment_link_requests`. | 1. Ứng dụng khóa form và hiển thị trạng thái đang chờ duyệt.<br>2. Partial Unique Index `uq_apartment_link_requests_user_pending` chặn trùng cấp CSDL. |
| **INV-01** | Chống trùng hóa đơn cùng căn hộ - cùng kỳ | Đã có hóa đơn căn hộ A0110 kỳ 10/2026 | 1. BQL vào Lập hóa đơn.<br>2. Chọn tiếp căn hộ A0110 và nhập kỳ `10/2026`.<br>3. Bấm Tạo hóa đơn. | 1. Client bắt lỗi trùng và hiển thị SnackBar đỏ: *"Hóa đơn kỳ này đã tồn tại cho căn hộ đã chọn"*, không văng crash.<br>2. Ràng buộc `uq_invoice_apartment_period` trên PostgreSQL bảo vệ không bị nhân đôi nợ. |
| **INV-02** | Validate định dạng kỳ hóa đơn `MM/YYYY` | Mở màn hình Lập hóa đơn | Nhập các định dạng sai như `2026/10`, `13/2026`, `10-2026`. | Validator báo lỗi: *"Kỳ hóa đơn phải có định dạng MM/YYYY (VD: 10/2026)"*, nút Submit bị chặn cho đến khi nhập đúng. |

---

## 7. Danh Sách Tài Khoản & Dữ Liệu Mẫu Thử Nghiệm

Hệ thống đã nạp sẵn bộ dữ liệu mẫu chuẩn trực tiếp vào cơ sở dữ liệu Supabase, dùng mật khẩu chung là **`123456`**:

| Email | Họ và Tên | Vai trò | Căn hộ | Dữ liệu mẫu sẵn có & Kịch bản áp dụng |
| :--- | :--- | :--- | :--- | :--- |
| `admin@gmail.com` | Nguyễn Văn Quản Trị | **Quản trị viên** | - | Toàn quyền 5 tabs. Quản lý cư dân, phân quyền vai trò, duyệt liên kết căn hộ, xem toàn bộ số liệu thống kê. |
| `ketoan@pka.vn` | Trần Thị Thu Thảo | **Kế toán** | - | 4 tabs (ẩn Phản ánh). Duyệt xác nhận thanh toán; tạo hóa đơn; theo dõi doanh thu và nợ phí. |
| `kythuat@pka.vn` | Lê Hoàng Long | **Kỹ thuật viên** | - | 4 tabs (ẩn Hóa đơn). Tiếp nhận sự cố kỹ thuật, cập nhật tiến độ xử lý và hoàn thành sự cố. |
| `test1@gmail.com` | Phạm Văn Minh | **Cư dân (Chủ hộ)** | **A0202** | Có hóa đơn T08/2026 (đã đóng), T09/2026 (Đang chờ BQL xác nhận thanh toán); 1 sự cố rò rỉ nước khẩn cấp. |
| `cudan1@pka.vn` | Hoàng Đức Anh | **Cư dân (Chủ hộ)** | **A0101** | Có hóa đơn T09/2026 (2.465.000 đ) Chưa thanh toán — **Dùng để demo Quét mã VietQR**; 1 sự cố Aptomat đang xử lý. |
| `cudan2@pka.vn` | Nguyễn Thị Mai Hương | **Cư dân (Chủ hộ)** | **B0101** | Lịch sử 2 tháng hóa đơn đã thanh toán; 1 sự cố sửa khóa thẻ từ đã hoàn thành. |
| `cudan3@pka.vn` | Đỗ Quốc Bảo | **Cư dân (Khách thuê)** | **C0101** | Có hóa đơn T09/2026 (860.000 đ) Chưa thanh toán. |
| `pending_cudan@pka.vn`| Bùi Minh Tuấn | **Cư dân (Chờ duyệt)**| **A0103** | Đang có yêu cầu liên kết ở trạng thái **Pending** — Dùng để kiểm thử giao diện chờ duyệt của cư dân và chức năng Duyệt của BQL. |


