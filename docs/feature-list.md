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
| **Đăng ký & Quản lý Phương tiện** | Đăng ký thẻ xe máy, ô tô theo hạn mức từng căn hộ (tối đa 2 xe máy, 1 ô tô), kiểm tra biển số trùng lặp, xem lý do bị từ chối và nộp lại hồ sơ. |
| **Tiện ích Tòa nhà & Đặt chỗ** | Xem danh mục tiện ích (Gym, BBQ, Bể bơi, Sân Tennis...), đặt chỗ theo khung giờ với kiểm soát sức chứa thực tế (`guests_count`), tiền cọc, và danh sách chờ (`waitlist`). |
| **Cổng thanh toán mô phỏng (Unified Payment)** | Thanh toán trực tuyến mô phỏng VietQR, Chuyển khoản ngân hàng 2 bước (`PENDING`), hoặc Đăng ký thanh toán tiền mặt tại quầy BQL. |
| **Khai báo chỉ số điện nước** | Cư dân chụp ảnh công tơ điện nước gửi định kỳ hàng tháng cho BQL thẩm định. |
| **Đánh giá xử lý sự cố** | Chấm điểm 1-5 sao kèm nhận xét sau khi kỹ thuật viên hoàn thành sửa chữa. |

### 2.2. Ban quản lý

| Tính năng | Mô tả chi tiết |
| :--- | :--- |
| **Smart Dashboard** | Quick Actions có badge đếm số việc cần xử lý (liên kết chờ, hóa đơn chờ xác nhận, phản ánh mới, thẻ xe chờ duyệt). Biểu đồ tài chính trực quan. |
| **Widget "Việc khẩn cấp"** | Lọc phản ánh priority = high chưa xử lý, hiển thị nổi bật ở đầu trang. |
| **Badge "MỚI"** | Đánh dấu item phát sinh trong khoảng thời gian gần (hỗ trợ Realtime). |
| **Audit trail / Lịch sử hoạt động** | Timeline tổng hợp mọi hành động quan trọng với thời gian tương đối (ví dụ: "5 phút trước"). |
| **Thống kê tổng quan** | Tỷ lệ lấp đầy căn hộ, doanh thu theo kỳ, tổng nợ đọng, biểu đồ tròn phân bổ trạng thái hóa đơn. |
| **CRUD Cẩm nang tòa nhà** | Quản lý động: nội quy, danh bạ khẩn cấp, tiện ích — không cần sửa mã nguồn khi có thay đổi. |
| **Danh bạ cư dân & Hồ sơ 360 độ** | Tra cứu nhanh cư dân theo tên hoặc mã căn hộ (`a0110`), xem toàn cảnh lịch sử căn hộ, thành viên, thẻ xe, hóa đơn và lịch sử đặt tiện ích. |
| **Duyệt Thẻ xe cư dân** | Xem danh sách xe chờ duyệt, phê duyệt hoặc từ chối kèm lý do phản hồi cho cư dân. |
| **Lập hóa đơn hàng loạt an toàn** | RPC CSDL `generate_valid_bulk_invoices` tự động tính phí quản lý, phí gửi xe máy/ô tô theo căn hộ và xuất hóa đơn định kỳ. |
| **Duyệt chỉ số điện nước** | Kế toán thẩm định ảnh chụp công tơ và số chỉ số do cư dân gửi, duyệt để đưa vào kỳ tính phí. |
| **Quản lý Bảo trì thiết bị** | Theo dõi lịch bảo trì định kỳ của các thiết bị trọng yếu tòa nhà (Thang máy, PCCC, Máy bơm, Máy phát điện). |

### 2.3. Hạ tầng / Kỹ thuật dùng chung (Cả 2 phía)

- **Hệ thống màu trạng thái nhất quán (`AppStatusColors`)**: Phân định rõ đỏ / cam / xanh cho từng trạng thái hóa đơn, priority phản ánh, trạng thái yêu cầu liên kết, duyệt xe.
- **Widget xử lý trạng thái chung (`AppStateView`)**: Chuẩn hóa hiển thị loading, empty, error trên toàn ứng dụng.
- **Bảo mật Row Level Security (RLS)**: Bật RLS toàn diện trên mọi bảng — đảm bảo cư dân căn hộ A tuyệt đối không xem được dữ liệu của căn hộ B.
- **Bảo mật thao tác qua RPC (Remote Procedure Call)**: Sử dụng Database RPC thay vì lệnh `UPDATE` trực tiếp từ client ở các thao tác nhạy cảm (thanh toán, duyệt liên kết căn hộ, đặt tiện ích, phát hành hóa đơn).
- **Phân loại ưu tiên phản ánh bằng Rule-based**: Tự động nhận diện mức độ khẩn cấp theo từ khóa (cháy, nổ, rò rỉ nước, kẹt thang máy...) mà không cần phụ thuộc LLM ngoài.
- **Cơ chế chống mất kết nối (Resilient Fallback)**: Tự động chuyển đổi giữa WebSocket Realtime và HTTP Polling khi kết nối mạng chập chờn.

---

## PHẦN 3: TÍNH NĂNG MỞ RỘNG — Ý TƯỞNG CHO TƯƠNG LAI

> [!NOTE]
> Các ý tưởng nâng cấp hệ thống khi triển khai vận hành ở quy mô lớn hơn:

| # | Tính năng | Phía | Độ khó | Ghi chú |
| :-: | :--- | :--- | :---: | :--- |
| 1 | **QR mời khách (Visitor Pass có thời hạn)** | Resident | Thấp - Trung | Thuần phần mềm, tạo mã QR động có hạn dùng, bảo vệ quét QR tại sảnh. |
| 2 | **Đăng nhập sinh trắc học (FaceID / Vân tay)** | Resident | Trung | Sử dụng package `local_auth` để mở khóa ứng dụng nhanh. |
| 3 | **Tích hợp Open Banking Webhook tự động** | Backend | Cao | Kết nối Casso / VietQR API để tự động xác nhận chuyển khoản ngân hàng thời gian thực. |
| 4 | **Đăng ký chuyển nhà / Thi công (Gate-pass)** | Resident + Admin | Trung | Đăng ký mượn thang hàng và thời gian thi công sửa chữa nội thất. |
| 5 | **Heatmap khu vực hay hỏng hóc** | Admin | Trung | Thống kê trực quan vị trí phát sinh nhiều phản ánh sự cố theo từng Block/Tầng. |

