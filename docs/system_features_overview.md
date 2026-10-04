# Tổng Quan Chi Tiết Tính Năng & Thiết Kế UI/UX (PKA-Home)

Tài liệu này mô tả chi tiết toàn bộ các tính năng đã được triển khai và cấu trúc giao diện người dùng (UI/UX) của dự án PKA-Home dành cho 2 nhóm đối tượng: Cư dân và Ban quản lý.

## 1. Ngôn Ngữ Thiết Kế & Nguyên Tắc UI/UX

Hệ thống tuân thủ nghiêm ngặt các quy tắc thiết kế trong `design-rules.md`:

- **Ngôn ngữ:** 100% Tiếng Việt chuẩn mực. Các thuật ngữ chuyên ngành được Việt hóa tự nhiên.
- **Typography:** Font chữ `Inter` (Google Fonts) được sử dụng xuyên suốt, mang lại cảm giác hiện đại, sắc nét trên mọi thiết bị. Cỡ chữ được scale tự động theo hệ thống (Accessibility).
- **Màu sắc (Theme):**
  - Hỗ trợ hoàn toàn 2 chế độ: Sáng (Light Mode) và Tối (Dark Mode).
  - Màu chủ đạo (`primary`): Xanh biển (`#1E88E5`).
  - Màu nền (`background`): Xám nhạt (`#F5F7FA`) (Sáng) / Đen xám (`#121212`) (Tối).
  - Màu nền thẻ (`surface`): Trắng (`#FFFFFF`) (Sáng) / Xám đậm (`#1E1E1E`) (Tối).
  - Semantic Colors: Xanh lá (Đã thanh toán/Thành công), Đỏ (Chưa thanh toán/Lỗi), Cam (Chờ xử lý/Cảnh báo).
- **Thành phần giao diện chung (Core Widgets):**
  - `AppCard`: Mọi khối thông tin đều được bọc trong thẻ (Card) bo góc 12px, không viền cứng, đổ bóng mờ (shadow alpha 0.05).
  - **Inputs:** Các trường nhập liệu (`TextField`) dùng `OutlineInputBorder` bo góc 12px, nền `surface`.
  - **Buttons:** Nút bấm phẳng (Elevation 0), bo góc 8px.
  - **Loading:** Sử dụng `ShimmerLoading` mượt mà, hạn chế dùng vòng xoay `CircularProgressIndicator` gây cảm giác chờ đợi lâu.
  - **Layout:** Cấu trúc linh hoạt (Wrap, ConstrainedBox) ngăn chặn triệt để lỗi "RenderFlex overflowed" trên màn hình nhỏ.
- **Routing & Transitions:** Sử dụng `GoRouter` với các hiệu ứng chuyển cảnh như trượt từ phải sang (`slideFromRight`), trượt lên (`slideUp`) hoặc mờ dần (`fade`).

---

## 2. Chi Tiết Tính Năng Cư Dân (Resident)

Mục tiêu của luồng Cư dân là cung cấp trải nghiệm tự phục vụ (Self-service) tiện lợi, nhanh chóng.

### 2.1. Đăng nhập & Xác thực (Auth)
- **UI:** Nền `background`, logo trung tâm. Form nhập liệu gồm Email/Mật khẩu. Nút bấm chính lớn. Có nút chuyển sang Đăng ký.
- **Tính năng:** Đăng nhập, Đăng ký tài khoản mới, Đổi mật khẩu. Tự động điều hướng dựa vào Role (Nếu là Management sẽ sang Dashboard BQL).

### 2.2. Yêu cầu liên kết căn hộ (Link Request)
- **UI:** Màn hình chào mừng đơn giản, hướng dẫn nhập mã căn hộ.
- **Tính năng:** Cư dân bắt buộc phải gửi yêu cầu liên kết với một căn hộ (nhập mã căn hộ, chọn vai trò: Chủ hộ, Người thuê, v.v.). Chặn không cho vào Trang chủ nếu chưa được duyệt hoặc chưa có căn hộ.

### 2.3. Trang chủ (Resident Home)
- **UI:** Thanh điều hướng dưới cùng (BottomNavigationBar). Màn hình chính chia thành các khối (Cards): Thông báo mới, Tóm tắt hóa đơn, Phản ánh gần đây.
- **Tính năng:**
  - **ApartmentSwitcherChip:** Nút bấm trên AppBar cho phép chuyển đổi qua lại nếu cư dân sở hữu/thuê nhiều căn hộ. Dữ liệu (Hóa đơn, Sự cố) tự động load lại theo căn hộ đang chọn.
  - **Tóm tắt nhanh:** Xem nhanh số tiền nợ, hoặc thông báo khẩn cấp.

### 2.4. Quản lý Hóa đơn (Invoices)
- **UI:** Danh sách hóa đơn chia thành 2 tab (Chưa thanh toán & Đã thanh toán). Các thẻ hóa đơn hiển thị tháng, tổng tiền và badge trạng thái (màu đỏ/xanh).
- **Tính năng:**
  - Xem danh sách lịch sử hóa đơn.
  - Click vào để xem chi tiết (`ResidentInvoiceDetailScreen`): Liệt kê từng khoản phí (Điện, Nước, Phí quản lý, Gửi xe), mã QR thanh toán (VietQR) và nút đánh dấu đã chuyển khoản (nếu BQL yêu cầu xác nhận).

### 2.5. Phản ánh Sự cố (Issues)
- **UI:** Nút FAB (Floating Action Button) để tạo mới. Danh sách các sự cố hiển thị badge trạng thái (Chờ xử lý, Đang xử lý, Hoàn thành). Chi tiết sự cố dạng Timeline (tiến độ).
- **Tính năng:**
  - **Tạo mới:** Chọn danh mục, nhập mô tả, chụp/tải ảnh đính kèm (Upload lên Supabase Storage).
  - **Chỉnh sửa:** Chỉ cho phép sửa khi BQL chưa tiếp nhận (trạng thái "Chờ xử lý").
  - **Đánh giá (Rating):** Khi sự cố chuyển sang "Đã hoàn thành", hệ thống bật BottomSheet cho phép cư dân đánh giá sao (1-5) và viết nhận xét cho kỹ thuật viên.

### 2.6. Cẩm nang & Thông báo (Handbook & Notifications)
- **UI:** Danh sách tin tức dạng Card. Cẩm nang dạng Tab hoặc List các quy định.
- **Tính năng:**
  - Xem thông báo từ BQL (có đánh dấu Đã đọc/Chưa đọc).
  - Xem chi tiết thông báo (`ResidentAnnouncementDetailScreen`).
  - Đọc nội quy, quy định, danh bạ khẩn cấp của tòa nhà.

### 2.7. Đặt lịch tiện ích & Phương tiện (Amenity & Vehicles)
- **Tính năng:**
  - **Phương tiện:** Đăng ký biển số xe mới, xem danh sách xe đang gửi, báo mất thẻ xe.
  - **Tiện ích:** (Đã thiết kế UI) Lựa chọn tiện ích (Gym, BBQ), chọn khung giờ chưa bị người khác đặt, xác nhận đặt lịch.

---

## 3. Chi Tiết Tính Năng Ban Quản Lý (Admin / Management)

Luồng của BQL chú trọng vào tính năng kiểm soát, thao tác hàng loạt, và bảo mật (Role-Based Access Control).

### 3.1. Trang chủ & Bảng điều khiển (Management Home / Dashboard)
- **UI:** Layout rộng rãi hơn, hiển thị biểu đồ và các thẻ chỉ số (KPIs). Không dùng AppBar thông thường mà dùng `IndexedStack` để quản lý các tab màn hình con không bị chồng chéo tiêu đề.
- **Tính năng:**
  - **Thống kê:** Biểu đồ doanh thu (`RevenueTrendChart`), số lượng hóa đơn chưa thu, sự cố tồn đọng.
  - **Hiệu suất:** Đánh giá hiệu suất của đội ngũ kỹ thuật (`TechnicianPerformanceCard`).

### 3.2. Quản lý Hóa đơn (Invoice Management)
- **Tính năng:**
  - Khởi tạo hóa đơn cho từng căn hộ (thêm các hạng mục phí, đơn giá, số lượng, tính tổng).
  - Sửa hóa đơn (khi có sai sót chỉ số điện nước).
  - Duyệt và cập nhật trạng thái "Đã thanh toán" khi nhận được tiền từ cư dân.
  - (Cần quyền Kế toán / Management / Admin).

### 3.3. Quản lý Sự cố (Issue Management)
- **Tính năng:**
  - Xem danh sách toàn bộ sự cố trong tòa nhà. Lọc theo trạng thái và độ ưu tiên.
  - Cập nhật trạng thái sự cố (Tiếp nhận -> Đang xử lý -> Hoàn thành).
  - Điều phối và theo dõi đánh giá từ cư dân.
  - (Cần quyền Kỹ thuật / Management / Admin).

### 3.4. Quản lý Cư dân & Căn hộ (Resident & Apartment)
- **Tính năng:**
  - **Cư dân:** Xem danh sách toàn bộ User trong hệ thống.
  - **Duyệt liên kết:** Khi cư dân gửi yêu cầu (`Link Request`), BQL sẽ kiểm tra và bấm "Duyệt" hoặc "Từ chối".
  - **Căn hộ:** Quản lý sơ đồ phòng, diện tích, trạng thái trống/đang ở.

### 3.5. Truyền thông nội bộ (Announcement & Handbook)
- **Tính năng:**
  - Soạn thảo và gửi thông báo mới. Có tùy chọn gửi toàn tòa nhà hoặc chọn lọc. Đánh dấu thông báo Khẩn cấp (hiển thị màu đỏ cho cư dân).
  - Cập nhật, chỉnh sửa các mục trong Cẩm nang (số điện thoại hotline, nội quy mới).

### 3.6. Công cụ Quản trị Hệ thống (System Admin Tools)
Chỉ hiển thị với Role là `admin`:
- **Role Delegation (Ủy quyền):** Cấp quyền tạm thời cho một user (VD: Cho anh A làm Kỹ thuật viên trong 30 ngày).
- **Permission Matrix (Ma trận quyền):** Màn hình lưới (Grid) hiển thị trực quan Role nào được phép làm hành động gì (dựa vào `permissions.dart`).
- **Audit Trail (Nhật ký thao tác):** Bảng log ghi lại mọi thao tác quan trọng (Ai đã sửa hóa đơn này lúc mấy giờ, Ai xóa sự cố này). Giúp truy vết lỗi và ngăn chặn gian lận.

---

## 4. Kiến trúc Dữ Liệu & Bảo Mật cốt lõi

- **Riverpod (State Management):** Tách biệt tầng logic (`Repositories`, `Providers`) khỏi giao diện. Mọi cuộc gọi API tới Supabase đều thông qua Repository.
- **Supabase RPC (Atomic Transactions):** Các thao tác phức tạp như Tạo Hóa Đơn kèm Hạng mục phí (`create_invoice_with_items`) được thực thi bằng Stored Procedures trên Postgres, đảm bảo nếu lỗi 1 hạng mục sẽ rollback (hủy) toàn bộ hóa đơn, tránh rác dữ liệu.
- **Row Level Security (RLS):**
  - Cư dân chỉ có thể SELECT/UPDATE các dòng dữ liệu có `apartment_id` nằm trong danh sách căn hộ họ đã được duyệt liên kết.
  - Thiết kế theo nguyên lý **Fail-closed**: Nếu không có điều kiện nào thỏa mãn, quyền mặc định là TỪ CHỐI (Deny).
- **RoleGuard Widget:** Widget bọc xung quanh các nút bấm nhạy cảm (VD: Nút Xóa, Nút Cập nhật Trạng thái). Nếu người dùng hiện tại không có quyền (check trong `PermissionItem`), nút đó sẽ bị ẩn đi.
