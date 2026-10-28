# Tài Liệu Thiết Kế: Cải Tiến Tính Năng & UI Toàn Diện (PKA-Home)

- **Ngày tạo:** 2026-09-06
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity Agent & Developer

---

## 1. Mục Tiêu & Bối Cảnh

Ứng dụng PKA-Home đã hoàn thành hầu hết các chức năng cơ bản theo kiến trúc Feature-first (Flutter + Riverpod + Supabase). Nhằm nâng cao trải nghiệm người dùng, đạt tiêu chuẩn thẩm mỹ cao và chuẩn bị cho bảo vệ đồ án tốt nghiệp/liên ngành, đợt cải tiến này tập trung vào 3 trụ cột:
1. **Dọn dẹp mã nguồn & Nền tảng (Foundation Cleanup)**: Xử lý triệt để các cảnh báo `flutter analyze`, gắn badge thời gian thực cho BQL.
2. **Cải tiến luồng Cư Dân (Resident Flow)**: Tích hợp mã VietQR ngân hàng tự động theo hóa đơn thực tế, xem chi tiết thông báo chung cư, làm đẹp trang hồ sơ cá nhân.
3. **Cải tiến luồng Ban Quản Lý (Management Flow)**: Bổ sung thanh phân tích tài chính/nợ đọng trực quan, bộ lọc thông minh cho hóa đơn và phản ánh sự cố.

---

## 2. Ràng Buộc Hệ Thống (Global Constraints)

- **Ngôn ngữ**: 100% Tiếng Việt chuẩn mực, không dùng tiếng Anh giải nghĩa trong ngoặc đơn.
- **Biểu tượng**: Sử dụng Material Design Icons (`Icons.*`), tuyệt đối không dùng emoji hoặc icon thư viện ngoài.
- **Phông chữ & Giao diện**: Google Fonts Inter, màu sắc theo `AppTheme` (`lib/core/theme/app_theme.dart`), responsive tự co giãn (`Wrap`, `SingleChildScrollView`), không hardcode chiều cao cố định gây lỗi overflow.
- **Bảo mật**: Tuân thủ quy tắc RLS của Supabase; dữ liệu gọi qua Repository thay vì gọi trực tiếp trong UI.

---

## 3. Thiết Kế Chi Tiết Từng Module

### Module 1: Dọn dẹp & Nền tảng (Cleanup & Foundation)
1. **Khắc phục 3 cảnh báo linter**:
   - `lib/data/providers/resident_issue_provider.dart`: Xóa biến `userId` không sử dụng.
   - `test/data/providers/resident_issue_provider_test.dart`: Xóa import thừa `issue_model.dart`.
   - `lib/features/management/screens/management_home_screen.dart`: Sử dụng biến `linkCount` hiển thị Badge số lượng yêu cầu gắn căn hộ chờ duyệt trên tab "Cư dân" của `BottomNavigationBar`.
2. **Tiện ích VietQR Helper (`lib/core/utils/vietqr_helper.dart`)**:
   - Class `VietQrHelper`:
     - Phương thức tĩnh `generateQrUrl({required String bankId, required String accountNo, required double amount, required String memo, required String accountName})`: Trả về URL ảnh chuẩn VietQR QuickLink (`https://img.vietqr.io/image/<bankId>-<accountNo>-compact2.png?amount=...&addInfo=...&accountName=...`).
     - Cung cấp hằng số mặc định cho tài khoản Ban Quản Lý: Ngân hàng `MB` (MBBank), Số tài khoản `0987654321`, Tên chủ tài khoản `BQL CHUNG CU PKA HOME`.

### Module 2: Cải tiến Luồng Cư Dân (Resident Flow)
1. **Tích hợp VietQR trong Màn hình Chi tiết Hóa đơn (`resident_invoice_detail_screen.dart`)**:
   - Khi cư dân mở hóa đơn chưa thanh toán và bấm "Thanh toán ngay":
     - Hiển thị Modal/BottomSheet thanh toán gồm: Mã QR ngân hàng tạo từ `VietQrHelper`, thông tin số tài khoản, số tiền, cú pháp chuyển khoản `[Mã căn hộ] [Kỳ phí]` (ví dụ: `A0110 Thang 09-2026`).
     - Nút "Sao chép số tài khoản" và "Sao chép nội dung" (sử dụng `Clipboard.setData`).
     - Nút bấm "Xác nhận đã thanh toán" để chuyển trạng thái hóa đơn sang `pending_confirmation` (chờ duyệt) và kích hoạt Realtime cập nhật trạng thái.
2. **Màn hình Xem Chi tiết Thông báo (`resident_announcement_detail_screen.dart`)**:
   - Tạo mới màn hình [`resident_announcement_detail_screen.dart`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/resident_announcement_detail_screen.dart).
   - Tiếp nhận `AnnouncementModel`.
   - Hiển thị: Tiêu đề lớn, huy hiệu "Khẩn cấp" (màu đỏ) nếu `is_urgent == true`, thời gian đăng (dùng `timeago`), người gửi ("Ban Quản Lý Tòa Nhà"), và nội dung chi tiết trong khung Card trang trọng.
   - Liên kết từ thẻ thông báo trên `resident_home_screen.dart`.
3. **Làm đẹp Hồ sơ Cư dân (`resident_profile_screen.dart`)**:
   - Hiển thị thẻ Căn hộ đang cư trú: Tòa nhà, số phòng, trạng thái đã liên kết.
   - Các hành động nhanh: "Yêu cầu đổi/liên kết căn hộ", "Đổi mật khẩu", "Đăng xuất" (kèm Dialog xác nhận trước khi thoát).

### Module 3: Cải tiến Luồng Ban Quản Lý (Management Flow)
1. **Biểu đồ Phân tích Tài chính/Nợ đọng (`management_home_screen.dart`)**:
   - Bổ sung Widget phân tích tài chính trong tab "Tổng quan":
     - Thanh tiến độ tỷ lệ thu phí tháng hiện tại (Phần trăm đã thu vs Còn nợ).
     - Thống kê tóm tắt: Tổng số tiền đã thu, Tổng số tiền còn nợ, Số căn hộ đã hoàn tất đóng phí.
     - Thiết kế bằng Flutter thuần (Progress Bar phân đoạn nhiều màu / Card tỷ lệ) chuẩn Material 3.
2. **Bộ Lọc & Tìm Kiếm Hóa Đơn (`invoice_management_screen.dart`)**:
   - Bổ sung thanh tìm kiếm nhanh theo mã căn hộ (ví dụ: gõ "A0110").
   - Bổ sung hàng Filter Chip trạng thái: "Tất cả", "Chờ duyệt", "Chưa đóng", "Đã thanh toán".
3. **Bộ Lọc Phản Ánh Sự Cố (`issue_management_screen.dart`)**:
   - Bổ sung Filter Chip: "Tất cả", "Chờ tiếp nhận", "Đang xử lý", "Đã xử lý".

---

## 4. Kế Hoạch Kiểm Thử (Verification Plan)

1. **Kiểm thử Tự động (Unit Test)**:
   - Thêm unit test kiểm tra logic tạo URL VietQR đúng định dạng trong `test/core/utils/vietqr_helper_test.dart`.
   - Thêm unit test kiểm tra logic lọc danh sách hóa đơn theo từ khóa mã căn hộ và trạng thái.
2. **Kiểm thử Linter (`flutter analyze`)**:
   - Phải đạt 0 errors, 0 warnings.
3. **Kiểm tra Chức năng Thực tế (Manual Verification)**:
   - Mở màn hình hóa đơn cư dân -> bấm thanh toán -> mã QR hiển thị rõ ràng, copy clipboard hoạt động.
   - Mở tab BQL -> kiểm tra badge số yêu cầu gắn căn hộ trên icon tab Cư dân -> kiểm tra thanh thống kê tỷ lệ thu phí.
