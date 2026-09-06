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
3. **Quản lý Hóa đơn:**
   - Chi tiết hóa đơn (Invoice Detail) có hiệu ứng trượt (animations) sang trọng.
   - Tự động bắt từ khóa để gắn Icon trực quan (Điện ⚡️, Nước 💧, Gửi xe 🚗).
   - Tích hợp BottomSheet mô phỏng cổng thanh toán (ATM, MoMo, ZaloPay).
4. **Phản ánh Sự cố (Realtime):**
   - Hỗ trợ nhập văn bản và đính kèm hình ảnh (ImagePicker).
   - Tích hợp **Supabase Realtime**: Nếu Ban quản lý đổi trạng thái từ "Chờ tiếp nhận" sang "Đang xử lý", giao diện Cư dân lập tức đổi màu chữ tự động mà không cần vuốt màn hình tải lại.

### Giai đoạn 5: Tính năng Ban Quản Lý (80%)
- **Khung giao diện:** Đã xây dựng hoàn tất màn hình Dashboard, Lập Hóa đơn, Quản lý Căn hộ, Quản lý Cư dân, và Xử lý phản ánh.
- Chờ ghép nối API chuyên sâu và làm mịn UI.

### Giai đoạn 6: Kiểm thử (Đang triển khai)
- **TDD (Test-Driven Development):** Code Provider (`resident_issue_provider_test.dart`) được viết Test Case trước khi triển khai logic thực tế. Áp dụng kỹ thuật Mock bằng thư viện `mocktail`.
- Vượt qua 100% Unit Test cho luồng Realtime Phản ánh sự cố.

## 3. Khó khăn gặp phải & Giải pháp
- **Vấn đề rò rỉ bộ nhớ (Memory Leak) với Stream:** Khi làm tính năng Realtime, dữ liệu Supabase Stream bị gọi dư thừa mỗi khi đổi tab.
  - **Giải pháp:** Sử dụng `ref.keepAlive()` kết hợp với việc huỷ Stream (dispose) đúng vòng đời Riverpod. Tối ưu bằng `.eq('user_id', userId)` để chỉ lắng nghe dòng dữ liệu liên quan.
- **Đồng bộ Design System:** Ban đầu dính nhiều thư viện Icon thừa (`fluentui_system_icons`).
  - **Giải pháp:** Refactor toàn hệ thống, gỡ hoàn toàn thư viện ngoài, chỉ dùng Material Design theo quy tắc `design-rules.md`.

## 4. Hướng phát triển tiếp theo (Next Steps)
1. **Tinh chỉnh UI Ban quản lý:** Áp dụng mô hình Smart Dashboard cho luồng Management (Vẽ biểu đồ hình tròn cho Nợ đọng).
2. **Push Notifications:** Bắn thông báo đẩy về máy điện thoại qua Firebase (FCM) khi có hóa đơn mới.
3. **Hoàn thiện Hồ sơ Đồ án:** Cập nhật lại sơ đồ ERD, Test Plan và làm Slide bảo vệ (Phase 7-8).
