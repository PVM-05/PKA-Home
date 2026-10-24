# BÁO CÁO TIẾN ĐỘ THỰC HIỆN ĐỒ ÁN (TỔNG KẾT)
**Dự án:** Ứng dụng Quản lý Chung cư (PKA-Home)
**Công nghệ:** Flutter (Riverpod) + Supabase

---

## 1. Mục tiêu đã đạt được
Hệ thống đã triển khai thành công mô hình **Client-Server** với kiến trúc phân tầng rõ ràng (Feature-first). Đã hoàn thiện toàn bộ tính năng cốt lõi cho vai trò **Cư Dân** và xây dựng xong khung giao diện cho **Ban Quản Lý**, đáp ứng đúng yêu cầu của tài liệu `project-plan.md` từ Giai đoạn 0 đến Giai đoạn 5.

## 2. Kết quả công việc chi tiết

### Giai đoạn 0 & 1: Thiết kế & Kiến trúc (100%)
- **Tài liệu:** Đã hoàn thành các tài liệu Đặc tả Yêu cầu (SRS), Cấu trúc Database (ERD), và Chính sách Bảo mật (RLS-policy).
- **Kiến trúc App:** Cấu trúc thư mục theo mô hình **Feature-first** (`lib/core/`, `lib/data/`, `lib/features/`).
- **Design System:** Thiết lập bộ màu sắc (`AppTheme`) và Font chữ (Inter/Segoe UI) đồng nhất trên toàn hệ thống, 100% tiếng Việt, responsive tự wrap nội dung.

### Giai đoạn 2: Dựng nền Backend Supabase (100%)
- **Cơ sở dữ liệu:** Khởi tạo thành công các bảng dữ liệu (`users`, `apartments`, `invoices`, `invoice_items`, `issue_reports`, `announcements`).
- **Bảo mật RLS (Row Level Security):** Áp dụng RLS khắt khe. Cư dân A tuyệt đối không thể đọc/sửa dữ liệu (Hóa đơn, Phản ánh) của Căn hộ B. Đã viết mã test tự động (`rls_security_test.dart`) chứng minh tính an toàn.
- **Lưu trữ (Storage):** Đã cấu hình bucket `issue-images` để lưu ảnh khi Cư dân báo sự cố.

### Giai đoạn 3 & 4: Tính năng Cư dân (100%)
Luồng Cư dân đã được nâng cấp lên mức **Smart Dashboard** (Giao diện Thông minh, Trải nghiệm cao cấp):
1. **Đăng nhập & Phân quyền:** Đăng nhập an toàn qua Supabase Auth, tự động điều hướng Cư dân vào luồng riêng.
2. **Trang chủ Thông minh (Smart Dashboard):**
   - Header Gradient hiện tên và Mã căn hộ.
   - Bảng Tóm tắt Hóa đơn tự động tính tổng nợ (đỏ nếu chưa đóng, xanh nếu đã đóng).
   - Thanh Quick Actions để Báo sự cố/Thanh toán siêu tốc.
   - Widget nhắc việc: Hiển thị ngay trạng thái của Phản ánh sự cố gần nhất.
3. **Quản lý Hóa đơn & Thanh toán:**
   - Chi tiết hóa đơn (Invoice Detail) có hiệu ứng trượt (animations) sang trọng.
   - Tự động bắt từ khóa để gắn Icon trực quan (Điện ⚡️, Nước 💧, Gửi xe 🚗).
   - Tích hợp Cổng thanh toán mô phỏng đồng nhất (**Unified Payment Sheet**): Hỗ trợ thanh toán trực tuyến mô phỏng VietQR, Chuyển khoản ngân hàng xác nhận 2 bước (`PENDING`), và Đăng ký thanh toán tiền mặt tại quầy BQL.
4. **Phản ánh Sự cố (Realtime):**
   - Hỗ trợ nhập văn bản và đính kèm hình ảnh (ImagePicker).
   - Tích hợp **Supabase Realtime**: Nếu Ban quản lý đổi trạng thái từ "Chờ tiếp nhận" sang "Đang xử lý", giao diện Cư dân lập tức đổi màu chữ tự động mà không cần vuốt màn hình tải lại.
5. **Tiện ích Tòa nhà & Đăng ký Phương tiện:**
   - Đặt lịch tiện ích chung cư (Gym, BBQ, Bể bơi...) với quản lý khung giờ, cọc phí, sức chứa thực tế và danh sách chờ (`waitlist`).
   - Đăng ký và quản lý thẻ xe máy, ô tô theo hạn mức từng căn hộ.

### Giai đoạn 5: Tính năng Ban Quản Lý (100%)
- **Smart Dashboard:** Bảng điều khiển quản trị thông minh, hiển thị biểu đồ tỷ lệ thanh toán, tổng quan doanh thu, nợ đọng, căn hộ và sự cố cần xử lý.
- **Hồ sơ Cư dân 360 độ (Resident 360):** Xem toàn diện lịch sử căn hộ, thành viên, phương tiện, hóa đơn và lịch sử đặt tiện ích của từng cư dân.
- **Lập Hóa đơn & Quản lý Chỉ số:** Phát hành hóa đơn hàng loạt an toàn qua RPC CSDL (`generate_valid_bulk_invoices`), nhập và duyệt chỉ số công tơ điện nước.
- **Quản lý Căn hộ & Duyệt Liên kết:** Phê duyệt yêu cầu liên kết căn hộ của cư dân, quản lý danh sách căn hộ theo Block và Tầng.
- **Xử lý Sự cố & Bảo trì:** Tiếp nhận, phân công kỹ thuật viên và cập nhật tiến độ xử lý phản ánh kèm hình ảnh.
- **Duyệt Thẻ xe & Tiện ích:** Phê duyệt / từ chối thẻ xe kèm lý do, theo dõi lịch bảo trì và đặt chỗ tiện ích.

### Giai đoạn 6: Kiểm thử & Đảm bảo Chất lượng (100%)
- **TDD & Test Suite Toàn diện:** Xây dựng hơn 143 bài kiểm thử tự động bao gồm Unit Tests, Widget Tests, Provider Tests và Integration Tests.
- **Kiểm thử Bảo mật RLS:** Bộ test bảo mật (`rls_security_test.dart`) chứng minh tính độc lập dữ liệu giữa các căn hộ và cơ chế phòng vệ 3 lớp chống leo thang đặc quyền.
- **Phân tích Tĩnh (Static Analysis):** Đạt chuẩn `flutter analyze` 0 cảnh báo, 0 lỗi.

## 3. Khó khăn gặp phải & Giải pháp
- **Vấn đề rò rỉ bộ nhớ (Memory Leak) với Stream & Controllers:** Khi làm tính năng Realtime và giao diện nhập liệu OTP, Stream và FocusNode dễ bị giữ lại trong bộ nhớ.
  - **Giải pháp:** Sử dụng `ref.keepAlive()` kết hợp huỷ Stream đúng vòng đời Riverpod; quản lý FocusNode tập trung bằng State lifecycle (`initState`/`dispose`).
- **Đồng bộ Design System:** Ban đầu dính nhiều thư viện Icon thừa (`fluentui_system_icons`).
  - **Giải pháp:** Refactor toàn hệ thống, gỡ hoàn toàn thư viện ngoài, chỉ dùng Material Design theo quy tắc `design-rules.md`, 100% tiếng Việt chuẩn mực.
- **Ràng buộc tính toàn vẹn tài chính cấp Server (Generated Column):** Trước đây `subtotal` của từng mục hóa đơn được tính toán từ Client và gửi lên DB, tiềm ẩn rủi ro sai lệch dữ liệu tài chính nếu có client khác can thiệp hoặc FE gặp lỗi tính toán.
  - **Giải pháp:** Chuyển đổi cột `subtotal` trong bảng `invoice_items` thành **PostgreSQL Generated Column** (`GENERATED ALWAYS AS (unit_price * quantity) STORED`), loại bỏ hoàn toàn tính toán từ client, đảm bảo tính nhất quán tuyệt đối và tuân thủ nguyên tắc an toàn dữ liệu tài chính.
- **Bảo toàn phản ánh sự cố khi upload ảnh gián đoạn:** Khi mạng yếu, việc tải ảnh lên Supabase Storage có thể thất bại sau khi bản ghi `issue_reports` đã được tạo, gây ra tình trạng ném ngoại lệ toàn phần và người dùng bấm gửi lại gây trùng lặp bản ghi.
  - **Giải pháp:** Phân tách khối upload ảnh bằng cơ chế bọc lỗi độc lập (`CreateIssueResult(imageUploadFailed: true)`). Nếu upload ảnh lỗi, hệ thống vẫn bảo toàn nội dung mô tả phản ánh trong DB và thông báo rõ ràng cho cư dân: *"Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau"*.
- **Xung đột RPC và dữ liệu Seeding:** Trải qua nhiều đợt phát triển, các hàm RPC thanh toán và đặt tiện ích có nhiều phiên bản nạp chồng và seed dữ liệu xe máy vượt quá hạn mức.
  - **Giải pháp:** Tạo Migration hợp nhất tập trung (`20261024_01_system_audit_consolidation.sql`) xóa bỏ mọi phiên bản cũ không an toàn, chuẩn hóa toàn bộ tài khoản sang định dạng `@gmail.com` với mật khẩu bảo mật `PkaHome@2026`, đồng thời chuẩn hóa bộ dữ liệu mẫu xe không vi phạm trigger.

## 4. Hướng phát triển tiếp theo (Next Steps)
1. **Push Notifications:** Triển khai gửi thông báo đẩy thực tế qua Firebase Cloud Messaging (Edge Function Supabase).
2. **Tối ưu hóa Phân trang (Pagination):** Mở rộng truy vấn dạng cuộn trang vô tận (`.range(from, to)`) khi hệ thống đạt quy mô hàng ngàn căn hộ.
3. **Hoàn thiện Hồ sơ Đồ án:** Hoàn tất Slide báo cáo, video demo và đóng gói tài liệu nghiệm thu bảo vệ đồ án.

