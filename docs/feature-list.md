# Danh Sách Tính Năng Tổng Hợp
**Ứng dụng Quản lý Chung cư (PKA-Home) — Cơ bản & Nâng cao, cả 2 phía**

---

## PHẦN 1: TÍNH NĂNG CƠ BẢN (MVP — bắt buộc phải có)

### 1.1. Cư dân (Resident)

| # | Tính năng | Ghi chú |
| :-: | :--- | :--- |
| 1 | **Đăng ký tài khoản** | Chỉ họ tên, email, mật khẩu — không hỏi SĐT/CCCD ngay. |
| 2 | **Đăng nhập** | Dùng chung màn hình với admin, phân luồng theo role. |
| 3 | **Xin liên kết căn hộ** | Nhập mã căn hộ (chuẩn `a0110`), chọn vai trò (chủ hộ/thuê), có màn hình chờ duyệt/bị từ chối. |
| 4 | **Trang chủ (Dashboard)** | Thông báo mới nhất + hóa đơn sắp đến hạn. |
| 5 | **Xem chi tiết hóa đơn** | Phân rã (breakdown) từng loại phí (điện, nước, quản lý...). |
| 6 | **Báo đã thanh toán** | Qua RPC an toàn, không tự sửa được số tiền. |
| 7 | **Gửi phản ánh sự cố** | Kèm ảnh, tự động phân loại mức độ ưu tiên theo từ khóa. |
| 8 | **Theo dõi tiến độ phản ánh** | Xem trạng thái: chờ tiếp nhận → đang xử lý → hoàn thành. |
| 9 | **Xem thông báo** | Từ ban quản lý, có đánh dấu khẩn cấp. |

### 1.2. Ban quản lý (Admin / Management)

| # | Tính năng | Ghi chú |
| :-: | :--- | :--- |
| 1 | **Đăng nhập** | Tài khoản được tạo thủ công, không có form đăng ký công khai. |
| 2 | **Duyệt/từ chối yêu cầu liên kết căn hộ** | Nút thắt chặn toàn bộ luồng resident nếu thiếu. |
| 3 | **Quản lý danh sách căn hộ** | Xem, thêm, sửa — bao gồm mã căn hộ (`a0110`), tòa/tầng. |
| 4 | **Lập hóa đơn** | Tạo invoice + chi tiết từng loại phí (`invoice_items`). |
| 5 | **Xác nhận thanh toán** | Chuyển trạng thái `pending_confirmation` → `paid`. |
| 6 | **Xem & xử lý phản ánh** | Đổi trạng thái, gán nhân sự xử lý. |
| 7 | **Soạn & gửi thông báo** | Tạo mới, đánh dấu khẩn cấp. |

---

## PHẦN 2: TÍNH NĂNG NÂNG CAO — ĐÃ THIẾT KẾ / NÊN TRIỂN KHAI TIẾP

### 2.1. Cư dân

| Tính năng | Mô tả chi tiết |
| :--- | :--- |
| **Realtime 2 chiều** | Toast + highlight khi: liên kết được duyệt, hóa đơn được xác nhận, thông báo mới, phản ánh đổi trạng thái. |
| **Lịch sử hóa đơn đầy đủ** | 2 tab "Cần đóng" / "Lịch sử đã thanh toán", xem lại mọi kỳ trước. |
| **Chỉnh sửa hồ sơ cá nhân** | Cập nhật họ tên, SĐT (không lưu CCCD dạng số). |
| **Thành viên cùng căn hộ** | Xem danh sách người đang liên kết với cùng căn hộ (owner/tenant/family). |
| **Cẩm nang tòa nhà** | Danh bạ khẩn cấp (nút gọi trực tiếp), nội quy, biểu phí minh bạch, giờ hoạt động tiện ích — quản lý CRUD động, không hard-code. |

### 2.2. Ban quản lý

| Tính năng | Mô tả chi tiết |
| :--- | :--- |
| **Smart Dashboard** | Quick Actions có badge đếm số việc cần xử lý (liên kết chờ, hóa đơn chờ xác nhận, phản ánh mới). |
| **Widget "Việc khẩn cấp"** | Lọc phản ánh priority = high chưa xử lý, hiển thị nổi bật ở đầu trang. |
| **Badge "MỚI"** | Đánh dấu item phát sinh trong khoảng thời gian gần (hỗ trợ Realtime). |
| **Audit trail / Lịch sử hoạt động** | Timeline tổng hợp mọi hành động quan trọng với thời gian tương đối (ví dụ: "5 phút trước"). |
| **Thống kê tổng quan** | Tỷ lệ lấp đầy căn hộ, doanh thu theo kỳ, tổng nợ đọng. |
| **CRUD Cẩm nang tòa nhà** | Quản lý động: nội quy, danh bạ khẩn cấp, tiện ích — không cần sửa mã nguồn khi có thay đổi. |
| **Danh bạ cư dân đầy đủ** | Tra cứu nhanh theo tên hoặc mã căn hộ (`a0110`), không chỉ giới hạn ở danh sách chờ duyệt. |

### 2.3. Hạ tầng / Kỹ thuật dùng chung (Cả 2 phía)

- **Hệ thống màu trạng thái nhất quán (`AppStatusColors`)**: Phân định rõ đỏ / cam / xanh cho từng trạng thái hóa đơn, priority phản ánh, trạng thái yêu cầu liên kết.
- **Widget xử lý trạng thái chung (`AppStateView`)**: Chuẩn hóa hiển thị loading, empty, error trên toàn ứng dụng.
- **Bảo mật Row Level Security (RLS)**: Bật RLS toàn diện trên mọi bảng — đảm bảo cư dân căn hộ A tuyệt đối không xem được dữ liệu của căn hộ B.
- **Bảo mật thao tác qua RPC (Remote Procedure Call)**: Sử dụng Database RPC thay vì lệnh `UPDATE` trực tiếp từ client ở các thao tác nhạy cảm (xác nhận thanh toán, duyệt liên kết căn hộ).
- **Phân loại ưu tiên phản ánh bằng Rule-based**: Tự động nhận diện mức độ khẩn cấp theo từ khóa (cháy, nổ, rò rỉ nước, kẹt thang máy...) mà không cần phụ thuộc LLM ngoài.

---

## PHẦN 3: TÍNH NĂNG MỞ RỘNG — Ý TƯỞNG CHO TƯƠNG LAI (Chưa cần làm ngay)

> [!NOTE]
> Danh sách được sắp xếp theo độ dễ triển khai giảm dần — khuyến nghị chỉ thực hiện sau khi Phần 1 (MVP) và Phần 2 đã vận hành ổn định.

| # | Tính năng | Phía | Độ khó | Ghi chú |
| :-: | :--- | :--- | :---: | :--- |
| 1 | **Đánh giá sao sau khi xử lý sự cố** | Resident | Thấp | Thêm bảng nhỏ `issue_ratings` để đánh giá chất lượng dịch vụ. |
| 2 | **QR mời khách (Visitor Pass có thời hạn)** | Resident | Thấp - Trung | Thuần phần mềm, tạo mã QR động có hạn dùng, không cần phần cứng. |
| 3 | **Đặt tiện ích nội khu (Hồ bơi, Gym, BBQ)** | Resident + Admin | Trung | Kiểm tra trùng lịch đặt chỗ, tái sử dụng mô hình quản lý hiện có. |
| 4 | **Đăng nhập sinh trắc học (FaceID / Vân tay)** | Resident | Trung | Sử dụng package `local_auth`, không cần thiết bị ngoài. |
| 5 | **QR thanh toán tĩnh (Hiển thị số tài khoản)** | Resident | Trung | Cung cấp mã VietQR kèm số tài khoản, chưa cần webhook tự động xác nhận. |
| 6 | **Webhook xác nhận thanh toán tự động** | Backend | Cao | Tích hợp cổng thanh toán (VNPay / MoMo Sandbox). |
| 7 | **Push Notification qua FCM** | Cả 2 | Trung - Cao | Triển khai sau khi luồng Realtime trong ứng dụng đã hoạt động trơn tru. |
| 8 | **Đăng ký chuyển nhà / Thi công (Gate-pass)** | Resident + Admin | Trung | Tái sử dụng luồng gửi duyệt yêu cầu tương tự liên kết căn hộ. |
| 9 | **Heatmap khu vực hay hỏng hóc** | Admin | Trung | Thống kê `GROUP BY apartment_id` / số tầng từ bảng `issue_reports`. |
