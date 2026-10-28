# Tài Liệu Thiết Kế: Nâng Cấp Toàn Diện Wireframe & Chuẩn Hóa UI/UX (PKA-Home)

- **Ngày tạo:** 2026-09-30
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity Agent & Developer

---

## 1. Mục Tiêu & Bối Cảnh

Hệ thống Quản lý Chung cư PKA-Home đã phát triển hoàn chỉnh nhiều nghiệp vụ phức tạp vượt trên bản phác thảo 4 màn hình sơ khai ban đầu. Để phục vụ tối đa cho báo cáo đồ án, thuyết minh thiết kế hệ thống và trải nghiệm người dùng đạt chuẩn quốc tế:
1. **Nâng cấp `docs/wireframes.md`**: Mở rộng từ 4 màn hình lên bộ tài liệu mô phỏng wireframe trực quan gồm **10 màn hình cốt lõi**, bao quát trọn vẹn luồng Cư dân (VietQR, Tiện ích, Hotline, Phương tiện, Hồ sơ trợ năng) và luồng Ban Quản lý (Dashboard, Xử lý sự cố nghiệm thu, Ủy quyền).
2. **Chuẩn hóa UI/UX trong mã nguồn**: Áp dụng triệt để các kỹ năng thiết kế (`thiet-ke-giao-dien`, `theme_spec.md`, `design-rules.md`):
   - 100% Tiếng Việt chuẩn mực, đúng ngữ pháp.
   - Thống nhất toàn bộ thẻ nội dung sang `AppCard` (thích ứng mượt mà Dark Mode và Light Mode).
   - Responsive co giãn linh hoạt, hỗ trợ người khiếm thị / người cao tuổi phóng to cỡ chữ (`fontSizeScaleProvider`).
   - Tuyệt đối không dùng emoji, chỉ dùng icon Material Design đồng nhất.

---

## 2. Đặc Tả 10 Màn Hình Wireframe Mới

1. **Màn hình Đăng nhập (Chung) & Quên mật khẩu**: Logo, tên app, Ứng Dụng Quản Lý Chung Cư, ô Email/Mật khẩu, nút Đăng nhập, Quên mật khẩu? Vui lòng liên hệ BQL.
2. **Trang chủ Cư dân**: SliverAppBar gradient, Chip chuyển căn hộ, Chuông thông báo badge, Quick Logout, Thẻ Tổng quan hóa đơn có nút THANH TOÁN NGAY, Thẻ Quỹ bảo trì, Tiến độ phản ánh, Thao tác nhanh Hotline & Dịch vụ.
3. **Màn hình Chi tiết Hóa đơn & Thanh toán VietQR**: Danh sách chi tiết các mục phí (quản lý, nước, xe, điện...), Trạng thái hóa đơn, Modal VietQR QuickLink kèm thông tin STK BQL, cú pháp chuyển khoản không dấu `/`, nút copy STK và nút Xác nhận đã chuyển khoản.
4. **Màn hình Gửi Phản Ánh Cư Dân**: Nhãn hướng dẫn, ô nhập mô tả chi tiết kèm hint, khung tải tối đa 3 ảnh có preview và nút xóa, nút GỬI YÊU CẦU.
5. **Màn hình Cẩm nang Tòa nhà & Hotline Khẩn cấp**: Tab Danh bạ khẩn cấp (An ninh, Cứu hỏa 114, Cấp cứu 115, Ban Quản lý, Kỹ thuật kèm nút gọi trực tiếp), Tab Cẩm nang & Biểu phí FAQ động.
6. **Màn hình Đặt lịch Tiện ích Chung cư**: Lựa chọn tiện ích (Bể bơi, BBQ, Gym), chọn ngày, chọn khung giờ (slot), thông tin quy định và chi phí, nút Xác nhận đặt chỗ.
7. **Màn hình Đăng ký Phương tiện**: Danh sách thẻ xe hiện có kèm trạng thái duyệt, nút Thêm xe mới, biểu mẫu nhập biển số, loại phương tiện, hình ảnh cavet xe.
8. **Hồ sơ Cư dân & Cài đặt Trợ năng**: Thẻ căn hộ đang cư trú, danh sách đồng cư dân, đổi mật khẩu, thanh điều chỉnh cỡ chữ (Phóng to chữ cho người lớn tuổi), công tắc đổi Giao diện Tối / Sáng.
9. **Trang chủ Ban Quản Lý (Dashboard)**: Thao tác nhanh (Duyệt liên kết, Ủy quyền, Lập hóa đơn, Xử lý sự cố), Thẻ Phản ánh cần xử lý gấp, Biểu đồ doanh thu 6 tháng, Tỷ lệ thu phí nợ đọng, Lưới thẻ trạng thái.
10. **Màn hình Xử lý Sự cố & Nghiệm thu (BQL)**: Bộ lọc trạng thái (Chờ tiếp nhận, Đang xử lý, Đã xử lý), xem ảnh cư dân đính kèm, phân công kỹ thuật viên phụ trách, tải ảnh nghiệm thu hoàn tất trước khi đóng sự cố.

---

## 3. Kế Hoạch Kiểm Thử & Nghiệm Thu

1. **Kiểm tra tài liệu wireframes.md**: Đầy đủ 10 màn hình, sơ đồ khối ASCII chuẩn hóa, mô tả chi tiết luồng người dùng và liên kết màn hình.
2. **Rà soát mã nguồn UI**: Đảm bảo toàn bộ các màn hình hiển thị nhất quán trên Dark Mode/Light Mode, không còn hardcode màu.
3. **Kiểm thử tự động**: Đảm bảo `dart analyze` đạt 0 lỗi, `flutter test` toàn bộ 115+ tests tiếp tục passed.
