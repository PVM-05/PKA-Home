# Đặc Tả Yêu Cầu Phần Mềm (SRS)
**Dự án: Ứng dụng Quản lý Chung cư (PKA-Home)**

## 1. Mục tiêu và Phạm vi
Ứng dụng hướng tới việc số hóa quy trình quản lý chung cư, kết nối trực tiếp ban quản lý với cư dân để thông báo, thu phí và giải quyết sự cố một cách minh bạch, nhanh chóng.

## 2. Danh sách Actor (Tác nhân)
- **Cư dân**: Người sinh sống tại chung cư, sở hữu hoặc thuê căn hộ.
- **Ban quản lý (BQL)**: Bộ phận vận hành tòa nhà, chịu trách nhiệm quản lý cư dân, cơ sở vật chất và tài chính.

## 3. Danh sách Use Case (Trường hợp sử dụng)

### 3.1. Dành cho Cư dân
- **UC-R1 (Đăng nhập)**: Đăng nhập vào hệ thống bằng thư điện tử và mật khẩu do BQL cấp.
- **UC-R2 (Xem thông báo)**: Nhận và xem nội dung các thông báo, tin tức từ BQL.
- **UC-R3 (Quản lý hóa đơn)**: Xem danh sách hóa đơn, chi tiết từng khoản phí (điện, nước, phí dịch vụ) và tổng tiền.
- **UC-R4 (Báo cáo thanh toán)**: Cập nhật trạng thái "đã thanh toán" cho hóa đơn kèm minh chứng (chuyển khoản).
- **UC-R5 (Gửi phản ánh sự cố)**: Tạo phiếu yêu cầu hỗ trợ, đính kèm hình ảnh hiện trường.
- **UC-R6 (Theo dõi tiến độ)**: Xem trạng thái xử lý các phản ánh đã gửi.

### 3.2. Dành cho Ban quản lý
- **UC-M1 (Đăng nhập)**: Đăng nhập bằng tài khoản quản trị viên.
- **UC-M2 (Quản lý căn hộ)**: Xem danh sách căn hộ, tình trạng trống/đã ở. Cập nhật thông tin chủ hộ.
- **UC-M3 (Gửi thông báo)**: Soạn thảo thông báo và gửi hàng loạt tới tất cả cư dân (có đánh dấu khẩn cấp).
- **UC-M4 (Lập hóa đơn)**: Tạo hóa đơn hàng tháng cho từng căn hộ với các khoản phí chi tiết.
- **UC-M5 (Xác nhận thanh toán)**: Kiểm tra minh chứng và chuyển trạng thái hóa đơn sang "đã thanh toán".
- **UC-M6 (Thống kê)**: Xem tổng số nợ đọng, tỷ lệ thanh toán.
- **UC-M7 (Xử lý phản ánh)**: Tiếp nhận phản ánh, phân công nhân viên xử lý và cập nhật trạng thái.

## 4. Yêu cầu Phi chức năng
- **Bảo mật (RLS)**: Dữ liệu phải được phân quyền cấp dòng (Row Level Security) trên Supabase. Cư dân không thể xem hoặc sửa dữ liệu của căn hộ khác. BQL có toàn quyền truy xuất.
- **Ngôn ngữ**: Giao diện, thông báo lỗi, và tài liệu 100% sử dụng tiếng Việt. Không dùng tiếng Anh trong ngoặc đơn.
- **Hiệu năng**: Ứng dụng phải tải dữ liệu hóa đơn và thông báo dưới 2 giây. Hình ảnh tải lên phải được tự động tối ưu hóa.
- **Giao diện (UI/UX)**: Hỗ trợ tự động xuống dòng (word-wrap) ở mọi thẻ nội dung, tương thích với cả điện thoại màn hình nhỏ và máy tính bảng.
