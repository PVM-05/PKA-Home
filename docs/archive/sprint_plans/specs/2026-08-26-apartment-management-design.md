# Thiết kế Ứng dụng Quản lý Chung cư

## 1. Mục tiêu Dự án
Xây dựng một ứng dụng đa nền tảng phục vụ quản lý chung cư hiện đại, đáp ứng yêu cầu của đồ án liên ngành. Ứng dụng kết nối trực tiếp giữa ban quản lý và cư dân, giúp tự động hóa quy trình quản lý, thanh toán phí và xử lý sự cố.

## 2. Kiến trúc Hệ thống
- **Giao diện người dùng**: Phát triển bằng Flutter. Ứng dụng duy nhất sử dụng cơ chế phân quyền để hiển thị giao diện tương ứng với vai trò của người đăng nhập (Ban quản lý hoặc Cư dân).
- **Máy chủ và Cơ sở dữ liệu**: Sử dụng Supabase cung cấp hệ quản trị cơ sở dữ liệu PostgreSQL, dịch vụ xác thực người dùng và lưu trữ dữ liệu thời gian thực.
- **Quản lý trạng thái**: Sử dụng thư viện Riverpod hoặc Provider.

## 3. Cấu trúc Cơ sở dữ liệu Dự kiến
Hệ thống bao gồm các bảng dữ liệu cốt lõi:
- **NguoiDung**: Lưu trữ thông tin tài khoản (mã định danh, họ tên, số điện thoại, mã căn hộ, vai trò).
- **CanHo**: Quản lý danh sách căn hộ (mã định danh, số căn hộ, diện tích, trạng thái trống).
- **HoaDon**: Lưu trữ các khoản phí (điện, nước, phí quản lý), số tiền, hạn nộp và trạng thái thanh toán.
- **PhanAnh**: Ghi nhận các sự cố do cư dân báo cáo, trạng thái xử lý (chờ tiếp nhận, đang xử lý, đã hoàn thành).
- **ThongBao**: Các bản tin và thông báo khẩn cấp từ ban quản lý gửi tới cư dân.

## 4. Phân chia Chức năng

### A. Dành cho Cư dân
- **Xác thực**: Đăng nhập bằng thư điện tử và mật khẩu.
- **Trang chủ**: Xem nhanh các thông báo mới nhất và hóa đơn đến hạn.
- **Thanh toán phí**: Xem chi tiết các loại phí và cập nhật trạng thái đã thanh toán.
- **Phản ánh sự cố**: Gửi yêu cầu hỗ trợ (kèm hình ảnh) và theo dõi tiến độ giải quyết.

### B. Dành cho Ban quản lý
- **Xác thực**: Đăng nhập bằng tài khoản quản trị.
- **Quản lý cư dân**: Xem danh sách căn hộ, thêm mới hoặc cập nhật thông tin chủ hộ.
- **Quản lý tài chính**: Lập hóa đơn hàng tháng cho từng căn hộ, theo dõi thống kê nợ đọng.
- **Xử lý phản ánh**: Tiếp nhận, phân công nhân sự và chuyển đổi trạng thái xử lý sự cố.
- **Phát thanh thông báo**: Soạn thảo và gửi thông báo đồng loạt.

## 5. Tiêu chuẩn Giao diện
- Tuân thủ nghiêm ngặt quy tắc sử dụng hoàn toàn tiếng Việt.
- Thiết kế hiện đại, phối màu hài hòa, sử dụng phông chữ Segoe UI sắc nét.
- Biểu tượng lấy từ bộ thư viện thiết kế trực quan. Không sử dụng biểu tượng cảm xúc.
- Các thẻ nội dung tự động xuống dòng và điều chỉnh chiều cao linh hoạt.
