# Đặc Tả Yêu Cầu Phần Mềm (SRS)
**Dự án: Ứng dụng Quản lý Chung cư (PKA-Home)**

## 1. Mục tiêu và Phạm vi
Ứng dụng hướng tới việc số hóa quy trình quản lý chung cư, kết nối trực tiếp ban quản lý với cư dân để thông báo, thu phí và giải quyết sự cố một cách minh bạch, nhanh chóng.

## 2. Danh sách Actor (Tác nhân)
- **Cư dân**: Người sinh sống tại chung cư, sở hữu hoặc thuê căn hộ.
- **Ban quản lý (BQL)**: Bộ phận vận hành tòa nhà, chịu trách nhiệm quản lý cư dân, cơ sở vật chất và tài chính.

## 3. Danh sách Use Case (Trường hợp sử dụng)

### 3.1. Dành cho Cư dân (Resident)
- **UC-R01 (Đăng ký & Đăng nhập)**: Đăng ký tài khoản (họ tên, email, mật khẩu) và đăng nhập hệ thống bảo mật.
- **UC-R02 (Xin liên kết căn hộ)**: Nhập mã căn hộ chuẩn (`A0110`), chọn vai trò (chủ hộ/người thuê), theo dõi duyệt và tự hủy yêu cầu chờ.
- **UC-R03 (Xem bảng tin & Thông báo đích)**: Nhận thông báo tòa nhà được phân nhóm linh hoạt (Toàn tòa, Theo block, Theo tầng, Căn hộ cụ thể).
- **UC-R04 (Tra cứu hóa đơn & Chi tiết phí)**: Xem danh sách hóa đơn, phân rã chi tiết từng khoản phí (điện, nước, quản lý, gửi xe) tự động tính toán.
- **UC-R05 (Thanh toán mô phỏng hai bước)**: Thanh toán an toàn qua VietQR mô phỏng hoặc chuyển khoản, tự động cập nhật trạng thái `pending_confirmation`.
- **UC-R06 (Khai báo chỉ số điện nước)**: Nhập số điện/nước hàng tháng và chụp ảnh công tơ thực tế gửi Ban Quản Lý thẩm định.
- **UC-R07 (Đặt lịch tiện ích & Chọn số người)**: Đặt khung giờ tiện ích, chọn số lượng người đi cùng (`guests_count`), tự động xếp vào danh sách chờ (`waitlist`) khi kín chỗ.
- **UC-R08 (Tự hủy lịch tiện ích an toàn)**: Cư dân tự bấm hủy lịch trên giao diện co giãn không tràn viền, gọi RPC nguyên tử tự động hoàn cọc/hủy phí và đôn người tiếp theo từ danh sách chờ.
- **UC-R09 (Đăng ký & Quản lý phương tiện)**: Đăng ký biển số xe máy, ô tô theo hạn mức tòa nhà, theo dõi duyệt và báo hủy phương tiện khi không còn gửi.
- **UC-R10 (Gửi phản ánh sự cố kỹ thuật)**: Tạo phiếu hỗ trợ sự cố, tự động phân loại ưu tiên theo từ khóa, đính kèm ảnh lưu trữ vùng an toàn (Private Storage).
- **UC-R11 (Chấm điểm đánh giá chất lượng)**: Khảo sát đánh giá 1 - 5 sao theo 3 tiêu chí (tốc độ, thái độ, chất lượng) khi sự cố được hoàn thành.
- **UC-R12 (Cẩm nang & Danh bạ khẩn cấp)**: Tra cứu quy định tòa nhà, giờ mở cửa tiện ích, nội quy sinh hoạt và đường dây nóng ban quản lý.

### 3.2. Dành cho Ban Quản Lý & Vận Hành (Management)
- **UC-M01 (Quản lý danh mục căn hộ)**: Xem, thêm, sửa danh sách căn hộ theo chuẩn `A0110`, diện tích, số tầng, tình trạng trống/đã ở và cư dân liên kết.
- **UC-M02 (Duyệt liên kết căn hộ)**: Phê duyệt hoặc từ chối yêu cầu liên kết căn hộ kèm lý do phản hồi cho cư dân.
- **UC-M03 (Thẩm định chỉ số điện nước)**: So sánh ảnh chụp công tơ thực tế của cư dân, duyệt hoặc từ chối chỉ số điện nước định kỳ.
- **UC-M04 (Lập hóa đơn hàng loạt an toàn)**: Phát hành hóa đơn đơn lẻ hoặc hàng loạt có bước kiểm tra trước (Preflight validation) ngăn ngừa sai sót dữ liệu.
- **UC-M05 (Đối soát & Xác nhận thanh toán)**: Duyệt hóa đơn chuyển khoản sang `paid` và hỗ trợ thu tiền mặt/chuyển khoản trực tiếp tại quầy qua `SegmentedButton`.
- **UC-M06 (Quản lý phương tiện cư dân)**: Thẩm định hồ sơ đăng ký xe máy/ô tô, duyệt biển số và tự động đồng bộ biểu phí gửi xe vào kỳ hóa đơn.
- **UC-M07 (Quản trị Tiện ích 3 Tab)**:
  - *Tab 1 (Duyệt lịch đặt chỗ)*: Danh sách phiếu đặt toàn tòa nhà theo thẻ chuẩn A7, bộ lọc trạng thái, tìm kiếm phòng, nút duyệt/từ chối/thu cọc chuẩn A8.
  - *Tab 2 (Cấu hình tiện ích & Sức chứa động)*: Tùy chỉnh sức chứa tối đa (`max_capacity`) thực tế (Bể bơi: 30, Gym: 20, BBQ: 15), hình thức dùng chung/trọn gói, giá và tiền cọc.
  - *Tab 3 (Lịch bảo trì)*: Bộ chọn tiện ích và ngày độc lập, lên lịch vệ sinh bảo dưỡng định kỳ và tạm khóa khung giờ đặt chỗ.
- **UC-M08 (Điểm danh Check-in sử dụng)**: Nút Check-in trực tiếp trên thẻ hoặc mở hộp thoại nhập mã đặt chỗ / quét QR trên thanh tiêu đề.
- **UC-M09 (Xử lý sự cố & Phân công kỹ thuật)**: Tiếp nhận phản ánh, phân công kỹ thuật viên phụ trách theo chuyên môn và cập nhật tiến độ xử lý.
- **UC-M10 (Nghiệm thu sự cố & Minh chứng)**: Kỹ thuật viên hoàn thành sửa chữa, đính kèm ảnh minh chứng nghiệm thu và đóng phiếu.
- **UC-M11 (Phát hành thông báo phân nhóm đích)**: Soạn thảo thông báo có gắn nhãn khẩn cấp và lựa chọn đối tượng nhận: Toàn tòa, Theo block (A, B, C), Theo tầng, hoặc Căn hộ đích cụ thể.
- **UC-M12 (Quản trị thiết bị tòa nhà)**: Theo dõi danh mục máy móc (thang máy, máy phát điện, máy bơm), lịch bảo trì định kỳ và cảnh báo gián đoạn dịch vụ.
- **UC-M13 (Phân quyền RBAC & Ủy quyền vai trò)**: Quản lý người dùng, phân quyền theo 4 vai trò vận hành, ủy quyền công việc có thời hạn (`role_delegations`) và giám sát kiểm toán.

> [!TIP]
> Bảng phân loại chi tiết các tính năng MVP, Nâng cao và Mở rộng được lưu trữ tại [feature-list.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/feature-list.md). Sơ đồ quan hệ thực thể xem tại [ERD.dbml](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/ERD.dbml).

## 4. Yêu cầu Phi chức năng
- **Bảo mật (RLS)**: Dữ liệu phải được phân quyền cấp dòng (Row Level Security) trên Supabase. Cư dân không thể xem hoặc sửa dữ liệu của căn hộ khác. BQL có toàn quyền truy xuất.
- **Ngôn ngữ**: Giao diện, thông báo lỗi, và tài liệu 100% sử dụng tiếng Việt. Không dùng tiếng Anh trong ngoặc đơn.
- **Hiệu năng**: Ứng dụng phải tải dữ liệu hóa đơn và thông báo dưới 2 giây. Hình ảnh tải lên phải được tự động tối ưu hóa.
- **Giao diện (UI/UX)**: Hỗ trợ tự động xuống dòng (word-wrap) ở mọi thẻ nội dung, tương thích với cả điện thoại màn hình nhỏ và máy tính bảng.
- **Định dạng mã căn hộ (ID phòng)**: Quy chuẩn định dạng `a0110` (hoặc `A0110`) tương ứng `[Tòa][Tầng 01-99][Phòng 01-99]` thay vì dạng `a101`.
- **Cơ chế xác thực & Khôi phục mật khẩu (Security by Design)**: Nhằm đảm bảo an toàn thông tin căn hộ và ngăn ngừa rủi ro giả mạo tài khoản cư dân, quy trình cấp và đặt lại mật khẩu được quản lý nội bộ qua Ban quản lý tòa nhà (Internal Admin Verification). Ứng dụng cung cấp hộp thoại hướng dẫn liên hệ trực tiếp thay vì mở luồng tự khôi phục công khai.
- **Khả năng mở rộng & Phân trang dữ liệu (Scalability Roadmap)**: Các danh sách dữ liệu (Hóa đơn, Cư dân, Căn hộ, Phản ánh) được định hướng mở rộng cơ chế phân trang cuộn vô tận (Infinite Scroll / Cursor-based Pagination) bằng `.range(from, to)` của Supabase SDK nhằm duy trì thời gian tải dưới 2 giây khi quy mô tòa nhà mở rộng.
- **Toàn vẹn dữ liệu tài chính cấp CSDL**: Các phép tính chi tiết (`subtotal`) và tổng hóa đơn (`total_amount`) được tính toán và kiểm soát tự động tại CSDL (PostgreSQL Generated Column và Database Triggers), bảo đảm nguyên tắc không tin tưởng tính toán từ client.
- **Phạm vi nền tảng (Platform Target)**: Đồ án tập trung phát triển và tối ưu trải nghiệm trên nền tảng **Android** (thiết bị di động Android và máy ảo Android) phục vụ mục tiêu nghiên cứu và nghiệm thu đồ án. Tạm thời chưa triển khai và chưa cần phát triển cho iOS trong giai đoạn này.

