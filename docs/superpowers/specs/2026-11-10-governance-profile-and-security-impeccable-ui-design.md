# Đặc Tả Thiết Kế: Quản Trị Hệ Thống, Hồ Sơ Cư Dân & Bảo Mật Impeccable UI (Design Spec)

## 1. Bối Cảnh & Mục Tiêu
PKA-Home là giải pháp B2B SaaS Quản lý Vận hành Chung cư & Bất động sản cao cấp. Để đảm bảo trải nghiệm người dùng đạt chuẩn quốc tế theo triết lý `pbakaus/impeccable`, loại bỏ toàn bộ lỗi tràn bố cục (`RenderFlex overflowed`), hệ thống cần nâng cấp toàn diện phân hệ Quản trị hệ thống, Hồ sơ cư dân & Bảo mật:
1. **`ResidentProfileScreen`**: Màn hình trung tâm quản lý tài khoản cư dân, danh sách căn hộ liên kết, thành viên cùng phòng, phương tiện và cài đặt ứng dụng.
2. **`LinkRequestManagementScreen` & `LinkRequestScreen`**: Quy trình cư dân gửi yêu cầu liên kết căn hộ và Ban Quản Lý phê duyệt/từ chối.
3. **`PermissionMatrixScreen` & `RoleDelegationScreen`**: Bảng ma trận phân quyền RBAC và phân hệ ủy quyền vai trò tạm thời cho cán bộ BQL/kế toán/kỹ thuật.
4. **`MaintenanceMaterialsScreen`**: Trạm quản lý kho vật tư kỹ thuật, xuất nhập kho và cảnh báo tồn kho an toàn.
5. **`RegisterScreen` & `ChangePasswordScreen`**: Luồng xác thực đăng ký tài khoản mới và đổi mật khẩu bảo mật.

## 2. Tiêu Chuẩn Thiết Kế Impeccable UI & Ràng Buộc Kỹ Thuật
- **Ngôn ngữ:** 100% tiếng Việt chuẩn mực SaaS B2B, chuẩn chính tả, không dùng emoji, không dịch gượng ép.
- **Anti-RenderFlex Guarantee:**
  - Mobile cực hẹp: 320dp x 600dp kèm Text Scale factor 1.3x (A11y Text Zoom). Không được xuất hiện bất kỳ ngoại lệ `RenderFlex overflowed`.
  - Desktop Enterprise: $\ge 900$dp tới 1920dp, căn giữa nội dung với `ConstrainedBox(maxWidth: 800 - 1200)`, không để giao diện dạt biên hay kéo dài vô tận.
- **Thành phần giao diện:** Chuyển đổi 100% các thẻ `Card` thông thường sang `AppCard` với viền siêu mỏng mờ (`AppTheme.borderColor`), đổ bóng mềm, bo góc nhất quán 12-16px.
- **Màu sắc & Phân cấp:** Đồng bộ với `AppTheme`, sử dụng badge trạng thái có độ tương phản cao, định dạng tiền tệ và ngày giờ nhất quán chuẩn Việt Nam (`vi_VN`).

## 3. Kiến Trúc Chi Tiết Từng Màn Hình

### 3.1. `ResidentProfileScreen` (Hồ Sơ Cư Dân)
- **Desktop:** Căn giữa `maxWidth: 800`.
- **Thẻ căn hộ & thành viên:** Bọc danh sách thành viên cùng căn hộ (`memberName`, `memberPhone`, `memberRole`) trong `Wrap` hoặc `Expanded` + `FittedBox`, đảm bảo số điện thoại và huy hiệu không đè nén làm vỡ layout khi text zoom 1.3x.
- **Header căn hộ:** Bọc hàng tiêu đề và nút 'Xin liên kết' trong `Wrap(alignment: WrapAlignment.spaceBetween)` hoặc `LayoutBuilder`.

### 3.2. `LinkRequestManagementScreen` & `LinkRequestScreen` (Liên Kết Căn Hộ)
- **`LinkRequestManagementScreen` (BQL):**
  - Desktop: Bọc `Center(ConstrainedBox(maxWidth: 1000))`.
  - Thay `Card` bằng `AppCard`.
  - Header thẻ yêu cầu bọc `Expanded` và `ConstrainedBox` cho vai trò.
  - Hàng nút thao tác (Từ chối / Phê duyệt) bọc `Wrap(alignment: WrapAlignment.end)` an toàn.
- **`LinkRequestScreen` (Cư Dân):**
  - Chuyển `Card` sang `AppCard`.
  - Giữ vững `maxWidth: 440`.

### 3.3. `PermissionMatrixScreen` & `RoleDelegationScreen` (Phân Quyền & Ủy Quyền)
- **`PermissionMatrixScreen`:**
  - Bọc `Center(ConstrainedBox(maxWidth: 1200))`.
  - Chuyển `Card` bao bọc bảng ma trận sang `AppCard`.
  - Giữ bảng `DataTable` trong `SingleChildScrollView(scrollDirection: Axis.horizontal)` với padding chuẩn xác.
- **`RoleDelegationScreen`:**
  - Bọc `Center(ConstrainedBox(maxWidth: 1100))`.
  - Chuyển `Card` sang `AppCard`.
  - Hàng badge vai trò và trạng thái bọc trong `Wrap` thay vì nested `Row` inside `Row` để chống tràn trên 320dp.

### 3.4. `MaintenanceMaterialsScreen` (Kho Vật Tư Kỹ Thuật)
- Bọc `Center(ConstrainedBox(maxWidth: 1200))`.
- Thanh KPI Kho: Bọc `LayoutBuilder`, chuyển sang cuộn ngang mượt mà khi chiều rộng $< 420$dp.
- Thẻ vật tư: Bọc mã hàng, tên vật tư, đơn giá và số lượng tồn kho với `Flexible` và `FittedBox`.

### 3.5. `RegisterScreen` & `ChangePasswordScreen` (Bảo Mật & Đăng Ký)
- Thay `Card` bằng `AppCard`.
- Bọc `Center(ConstrainedBox(maxWidth: 440))` cho cả hai màn hình.
- Các nút bấm bọc `FittedBox` cho nhãn để không bao giờ tràn nút.

## 4. Chiến Lược Kiểm Thử (TDD & Anti-RenderFlex)
- Viết test widget responsive mô phỏng:
  1. Màn hình hẹp 320dp x 600dp kèm Text Zoom 1.3x: Xác nhận không có ngoại lệ RenderFlex overflow.
  2. Màn hình máy tính lớn 1200dp x 800dp: Xác nhận các giới hạn `maxWidth` co giãn hài hòa.
- Chạy `dart analyze lib test` đảm bảo 0 issues.
