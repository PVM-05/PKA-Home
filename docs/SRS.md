# Đặc Tả Yêu Cầu Phần Mềm (SRS)
**Dự án: Ứng dụng Quản lý Chung cư (PKA-Home)**

## 1. Mục tiêu và Phạm vi
Ứng dụng hướng tới việc số hóa quy trình quản lý chung cư, kết nối trực tiếp ban quản lý với cư dân để thông báo, thu phí và giải quyết sự cố một cách minh bạch, nhanh chóng.

## 2. Danh sách Actor (Tác nhân)
- **Cư dân**: Người sinh sống tại chung cư, sở hữu hoặc thuê căn hộ.
- **Ban quản lý (BQL)**: Bộ phận vận hành tòa nhà, chịu trách nhiệm quản lý cư dân, cơ sở vật chất và tài chính.

## 3. Danh sách Use Case (Trường hợp sử dụng)

### 3.1. Dành cho Cư dân
- **UC-R1 (Đăng ký & Đăng nhập)**: Đăng ký tài khoản (họ tên, email, mật khẩu) và đăng nhập vào hệ thống.
- **UC-R2 (Xin liên kết căn hộ)**: Nhập mã căn hộ (`a0110`), chọn vai trò (chủ hộ/người thuê), theo dõi trạng thái phê duyệt.
- **UC-R3 (Trang chủ & Xem thông báo)**: Nhận và xem nội dung các thông báo, tin tức từ BQL (có gắn nhãn khẩn cấp).
- **UC-R4 (Quản lý hóa đơn)**: Xem danh sách hóa đơn theo kỳ, phân rã chi tiết từng khoản phí (điện, nước, dịch vụ) và tổng tiền.
- **UC-R5 (Báo đã thanh toán)**: Cập nhật trạng thái "chờ xác nhận" (`pending_confirmation`) qua RPC bảo mật kèm minh chứng.
- **UC-R6 (Gửi phản ánh sự cố)**: Tạo phiếu yêu cầu hỗ trợ kèm ảnh, tự động phân loại mức độ ưu tiên theo từ khóa.
- **UC-R7 (Theo dõi tiến độ)**: Xem trạng thái xử lý phản ánh (chờ tiếp nhận → đang xử lý → hoàn thành).

### 3.2. Dành cho Ban quản lý
- **UC-M1 (Đăng nhập)**: Đăng nhập bằng tài khoản quản trị viên do hệ thống cấp sẵn.
- **UC-M2 (Duyệt liên kết căn hộ)**: Phê duyệt hoặc từ chối các yêu cầu xin liên kết căn hộ từ cư dân.
- **UC-M3 (Quản lý căn hộ & cư dân)**: Xem, thêm, sửa danh sách căn hộ (`a0110`), trạng thái trống/đã ở và danh sách cư dân liên kết.
- **UC-M4 (Lập hóa đơn)**: Tạo hóa đơn hàng tháng cho từng căn hộ với các khoản phí chi tiết (`invoice_items`).
- **UC-M5 (Xác nhận thanh toán)**: Kiểm tra minh chứng và duyệt chuyển trạng thái hóa đơn sang `paid`.
- **UC-M6 (Thống kê tài chính & nợ)**: Xem tỷ lệ lấp đầy, doanh thu theo kỳ và tổng nợ đọng.
- **UC-M7 (Xử lý phản ánh)**: Tiếp nhận phản ánh, phân công nhân viên xử lý và cập nhật tiến độ.
- **UC-M8 (Soạn & gửi thông báo)**: Soạn thảo và phát thông báo diện rộng tới toàn bộ cư dân (có tùy chọn khẩn cấp).

> [!TIP]
> Bảng phân loại chi tiết các tính năng MVP, Nâng cao và Mở rộng được lưu trữ tại [feature-list.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/feature-list.md).

## 4. Yêu cầu Phi chức năng
- **Bảo mật (RLS)**: Dữ liệu phải được phân quyền cấp dòng (Row Level Security) trên Supabase. Cư dân không thể xem hoặc sửa dữ liệu của căn hộ khác. BQL có toàn quyền truy xuất.
- **Ngôn ngữ**: Giao diện, thông báo lỗi, và tài liệu 100% sử dụng tiếng Việt. Không dùng tiếng Anh trong ngoặc đơn.
- **Hiệu năng**: Ứng dụng phải tải dữ liệu hóa đơn và thông báo dưới 2 giây. Hình ảnh tải lên phải được tự động tối ưu hóa.
- **Giao diện (UI/UX)**: Hỗ trợ tự động xuống dòng (word-wrap) ở mọi thẻ nội dung, tương thích với cả điện thoại màn hình nhỏ và máy tính bảng.
- **Định dạng mã căn hộ (ID phòng)**: Quy chuẩn định dạng `a0110` (hoặc `A0110`) tương ứng `[Tòa][Tầng 01-99][Phòng 01-99]` thay vì dạng `a101`.
