# Đặc Tả Thiết Kế: Cải Tiến Giao Diện Phân Hệ Phương Tiện & Bãi Đỗ Xe (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Nâng cấp toàn diện giao diện và trải nghiệm người dùng (UI/UX) cho phân hệ Quản lý Phương tiện & Bãi đỗ xe (`VehicleManagementScreen`, `VehicleApprovalScreen`, và `ParkingManagementScreen`) theo tiêu chuẩn **`pbakaus/impeccable`**, loại bỏ 100% rủi ro tràn layout (RenderFlex overflow) trên màn hình mobile cực hẹp (320dp x 600dp, Text Zoom 1.3x) và tối ưu hóa trạm làm việc chuyên nghiệp (Executive Parking Workstation) trên Web Desktop ($\ge 900$dp, `maxWidth: 1400dp`).
- **Phạm vi tác động:**
  - `lib/features/resident/screens/vehicle_management_screen.dart`
  - `lib/features/management/screens/vehicle_approval_screen.dart`
  - `lib/features/management/screens/parking_management_screen.dart`
- **Quy chuẩn tuân thủ:** Clean Architecture, Feature-First, Riverpod Reactive State, 100% tiếng Việt B2B SaaS chuẩn mực, commit trực tiếp trên nhánh `main`, 0 warning/0 error trên `dart analyze lib test`.

---

## 1. Phân Tích Kỹ Thuật & Giải Pháp Triệt Tiêu Lỗi RenderFlex

### 1.1. `VehicleManagementScreen` (Cư Dân Quản Lý Phương Tiện Căn Hộ)
- **Thẻ Hạn Mức Đăng Ký Căn Hộ (Quotas Card):**
  - *Hiện trạng:* Thẻ sử dụng `Row` cố định chia 2 khối cho xe máy và ô tô. Khi text zoom 1.3x hoặc chiều rộng màn hình hẹp 320dp, văn bản và nhãn trạng thái tràn layout.
  - *Giải pháp Impeccable:* Sử dụng `LayoutBuilder`:
    - Khi chiều rộng khả dụng $< 380$dp: Tự động xếp chồng dọc 2 khối hạn mức (Xe máy và Ô tô) thay vì ép ngang.
    - Khi chiều rộng $\ge 380$dp: Duy trì hiển thị 2 cột cân đối.
    - Bọc toàn bộ các nhãn chỉ số, số lượng và quy định trong `Flexible` kết hợp `FittedBox(fit: BoxFit.scaleDown)` để văn bản không bị cắt xén thô bạo.
- **Thẻ Phương Tiện Căn Hộ (`_buildVehicleCard`):**
  - Biển số xe hiển thị dạng huy hiệu kim loại bo tròn chuẩn biển số Việt Nam, đi kèm biểu tượng loại xe (Xe máy / Ô tô).
  - Trạng thái xe (`pending`, `active`, `rejected`, `revoked`): Sử dụng `AppStatusColors` và bọc trong `Flexible` + `FittedBox`.
  - Khối thông tin Slot đỗ xe & Thẻ xe thông minh: Tự động xuống dòng khi nội dung dài, có icon nhận diện rõ ràng.
  - Nhãn nút hành động (Chỉnh sửa, Hủy đăng ký): Bọc trong `FittedBox(fit: BoxFit.scaleDown)`.
- **Hộp thoại Đăng Ký Phương Tiện (`_showAddVehicleDialog`):**
  - Dialog adaptive: Thích ứng tối đa với chiều rộng màn hình, trường chọn loại xe và tải ảnh cà vẹt rõ ràng, không hardcode chiều cao cố định.
- **Trạm Điều Hành Web Desktop ($\ge 900$dp, `maxWidth: 1200`):**
  - Bố cục **Split-Screen 2 cột**:
    - **Cột trái (38%):** Thẻ thông tin hạn mức căn hộ, quy chế gửi xe tòa nhà, hướng dẫn thủ tục thẻ thông minh NFC, và nút tạo đăng ký xe mới.
    - **Cột phải (62%):** Danh sách toàn bộ phương tiện đã đăng ký kèm bộ lọc trạng thái và thông tin slot đỗ chi tiết.

---

### 1.2. `VehicleApprovalScreen` (Ban Quản Lý Duyệt Xe & Phân Bổ Slot Đỗ)
- **Header Thẻ Phiếu Yêu Cầu Duyệt:**
  - Bọc mã căn hộ, biển số xe và badge trạng thái trong `Flexible` và `TextOverflow.ellipsis`, tránh tràn khi căn hộ có tên dài hoặc biển số dài.
- **Bộ Đôi Nút Hành Động ("Từ chối" & "Phê duyệt & Cấp slot"):**
  - Bọc nút trong `FittedBox(fit: BoxFit.scaleDown, child: Text(...))` để tránh RenderFlex overflow trên mobile hẹp.
- **Hộp thoại Duyệt & Phân Bổ Ô Đỗ (`_showApproveDialog`):**
  - Bọc danh sách chọn ô đỗ khả dụng trong `ConstrainedBox(maxHeight: ...)` với cuộn mượt mà, hiển thị rõ ràng tầng hầm và mã vị trí ô đỗ.
- **Trạm Web Desktop Workstation ($\ge 900$dp, `maxWidth: 1400`):**
  - **Executive Vehicle KPI Bar:** 4 thẻ chỉ số nhanh ở đầu trang:
    1. *Chờ duyệt*: Tổng số xe mới đang đợi BQL xác nhận thông tin.
    2. *Đang hoạt động*: Tổng số xe đang gửi hợp lệ trong tòa nhà.
    3. *Xe máy / Ô tô*: Số lượng chi tiết theo từng phân loại phương tiện.
    4. *Tỷ lệ lấp đầy*: Tỷ lệ phương tiện so với tổng công suất ô đỗ của tòa nhà.
  - **Bố cục lưới 2 cột**: Danh sách phiếu yêu cầu được chia thành lưới 2 cột cân đối, giúp ban quản lý đối soát ảnh cà vẹt và thông tin cực kỳ nhanh chóng.

---

### 1.3. `ParkingManagementScreen` (Ban Quản Lý Sơ Đồ Ô Đỗ & Trạm Soát Vé)
- **Dải KPI Sức Chứa (Capacity Strip):**
  - *Hiện trạng:* Dùng `Row` cứng chia tỷ lệ sức chứa xe máy và ô tô, dễ vỡ tràn trên màn hình 320dp với font 1.3x.
  - *Giải pháp Impeccable:* Bọc dải KPI trong `SingleChildScrollView(scrollDirection: Axis.horizontal)` hoặc `Wrap` linh hoạt, đảm bảo hiển thị trọn vẹn số slot trống, số slot đã đỗ, và % lấp đầy.
- **Sơ Đồ Lưới Ô Đỗ (Slot Map Grid):**
  - Tự động tính toán số cột `crossAxisCount` dựa trên chiều rộng màn hình:
    - Mobile hẹp (< 500dp): 2 hoặc 3 cột với `childAspectRatio: 1.1`.
    - Tablet / Web nhỏ (500dp - 900dp): 4 hoặc 5 cột.
    - Web Workstation ($\ge 900$dp): 6 đến 8 cột.
- **Trạm Soát Vé Cổng Vãng Lai:**
  - Bảng danh sách lượt gửi xe vãng lai bọc trong `SingleChildScrollView(scrollDirection: Axis.horizontal)` trên mobile, tránh tràn khi hiển thị biển số, giờ vào, giờ ra và nút thanh toán.
- **Trạm Web Desktop Workstation ($\ge 900$dp, `maxWidth: 1400`):**
  - Bố cục giới hạn `maxWidth: 1400`, căn giữa thẩm mỹ, không bị kéo dãn biên thô kệch.

---

## 2. Bảng Cam Đoan Chống Tràn Bố Cục (Anti-RenderFlex Checklist)

| Thành phần | Cơ chế chống tràn | Kích thước kiểm thử |
| :--- | :--- | :--- |
| **`VehicleManagementScreen` Quotas** | `LayoutBuilder` chuyển sang cột đơn khi width < 380dp; text bọc `Flexible` & `FittedBox`. | Mobile 320dp x 600dp, Text zoom 1.3x $\to$ 0 overflow. |
| **`VehicleManagementScreen` Vehicle Card** | Badge trạng thái và biển số bọc `Flexible`; nút bấm bọc `FittedBox`. | Mobile 320dp x 600dp, Text zoom 1.3x $\to$ 0 overflow. |
| **Resident Vehicle Desktop** | Split-Screen 2 cột (38% Hạn mức & Hướng dẫn, 62% Danh sách xe). | Desktop 1200dp $\to$ 0 overflow. |
| **`VehicleApprovalScreen` Cards** | Header làm phẳng, nhãn nút bọc `FittedBox`, ảnh cà vẹt co giãn an toàn. | Mobile 320dp x 600dp, Text zoom 1.3x $\to$ 0 overflow. |
| **Vehicle Approval Executive Web** | KPI Bar 4 cột, bố cục lưới phiếu 2 cột, giới hạn `maxWidth: 1400`. | Desktop 1200dp - 1400dp $\to$ 0 overflow. |
| **`ParkingManagementScreen` Capacity** | Dải KPI bọc cuộn ngang hoặc `Wrap`, lưới ô đỗ thích ứng số cột động. | Mobile 320dp x 600dp $\to$ 0 overflow. |
| **Parking Web Workstation** | Căn giữa `maxWidth: 1400`, lưới ô đỗ trực quan, trạm vé cổng phân tầng. | Desktop 1200dp - 1400dp $\to$ 0 overflow. |

---

## 3. Kịch Bản Kiểm Thử & Tiêu Chuẩn Nghiệm Thu

1. **`vehicle_management_responsive_test.dart`**:
   - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Thẻ hạn mức và Danh sách xe không có lỗi RenderFlex.
   - Test 2: Desktop 1200dp render bố cục Split-Screen 2 cột hoàn chỉnh.
2. **`vehicle_approval_responsive_test.dart`**:
   - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render cả 4 tab yêu cầu duyệt xe không có lỗi RenderFlex.
   - Test 2: Desktop 1200dp render Executive KPI Bar và bố cục lưới 2 cột.
3. **`parking_management_responsive_test.dart`**:
   - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Sơ đồ ô đỗ và Trạm soát vé cổng không có lỗi RenderFlex.
   - Test 2: Desktop 1200dp render Sơ đồ ô đỗ và Trạm soát vé cân đối.
4. **Static Analysis Quality Gate:**
   - Chạy `dart analyze lib test` đạt 0 warning, 0 error.
